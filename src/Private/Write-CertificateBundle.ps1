#Requires -Version 5.1

# Message(s)
$Script:Message += @{
  'Write-CertificateBundle.BelowMinimum' = 'Certificate bundle has {0} certificate(s), below the required minimum of {1}.'
  'Write-CertificateBundle.NonAscii'     = 'Certificate bundle content must be ASCII.'
  'Write-CertificateBundle.WriteFailure' = 'Failed to write certificate bundle: {0}'
}

Function Write-CertificateBundle {
  <#
    .SYNOPSIS
        Writes a certificate bundle.

    .DESCRIPTION
        Writes an ASCII LF certificate bundle with explicit no-BOM encoding.
        The helper fails closed below the minimum certificate count, skips exact
        byte-identical writes, and uses a same-directory temp file followed by
        File.Move for first writes or File.Replace for replacements.

    .PARAMETER Path
        Destination bundle path.

    .PARAMETER PemBlock
        PEM blocks to write in bundle order.

    .PARAMETER MinimumCertificateCount
        Minimum PEM block count required before writing.

    .PARAMETER WriteManifest
        Writes a sha256sum-style `<bundle>.sha256` sidecar.

    .EXAMPLE
        Write-CertificateBundle -Path .\bundle.pem -PemBlock $PemBlocks -WriteManifest

    .OUTPUTS
        [System.Management.Automation.PSCustomObject]
    #>
  [CmdletBinding(
    ConfirmImpact = 'Medium',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#write-certificatebundle',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $True
  )]
  [OutputType([PSCustomObject])]
  Param (
    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $MinimumCertificateCount = 1,

    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [AllowEmptyCollection()]
    [System.String[]]
    $PemBlock = @(),

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $WriteManifest
  )

  Write-Debug -Message:'[Write-CertificateBundle] Entering'

  # Initialize Variable(s)
  [System.String]$Private:BundleBackupPath = [System.String]::Empty
  [System.String]$Private:BundleSha256 = [System.String]::Empty
  [System.Byte[]]$Private:BundleBytes = [System.Byte[]]@()
  [System.String]$Private:BundleTempPath = [System.String]::Empty
  [System.String]$Private:BundleText = [System.String]::Empty
  [System.Boolean]$Private:BundleUnchanged = $False
  [System.String]$Private:DirectoryPath = [System.String]::Empty
  [System.Text.UTF8Encoding]$Private:Encoding = $Null
  [System.Byte[]]$Private:ExistingBytes = [System.Byte[]]@()
  [System.String]$Private:ExistingSha256 = [System.String]::Empty
  [System.String]$Private:FullPath = [System.String]::Empty
  [System.String]$Private:ManifestPath = $Null
  [System.Byte[]]$Private:ManifestBytes = [System.Byte[]]@()
  [System.String]$Private:ManifestFullPath = [System.String]::Empty
  [System.String]$Private:ManifestBackupPath = [System.String]::Empty
  [System.String]$Private:ManifestTempPath = [System.String]::Empty
  [System.String]$Private:ManifestText = [System.String]::Empty
  [System.Boolean]$Private:ManifestUnchanged = $False
  [System.String]$Private:OperationTarget = [System.String]::Empty
  [System.String]$Private:PathLeaf = [System.String]::Empty
  [PSCustomObject]$Private:Result = $Null
  [System.Security.Cryptography.SHA256]$Private:Sha256 = $Null
  [System.String]$Private:Status = [System.String]::Empty

  If ($PemBlock.Count -lt $MinimumCertificateCount) {
    New-ErrorRecord `
      -Category:([System.Management.Automation.ErrorCategory]::InvalidData) `
      -ErrorId:([ExporterExitCode]::BelowMinimumCertificateCount) `
      -IsFatal:$True `
      -Message:($Script:Message['Write-CertificateBundle.BelowMinimum'] -f $PemBlock.Count, $MinimumCertificateCount) `
      -TargetObject:$Path
  }

  $Encoding = [System.Text.UTF8Encoding]::new($False)
  $FullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
  $DirectoryPath = [System.IO.Path]::GetDirectoryName($FullPath)
  $PathLeaf = [System.IO.Path]::GetFileName($FullPath)
  $BundleText = ([System.String[]]$PemBlock -join "`n") -replace "`r`n?", "`n"

  # PEM bundle bytes are consumed by minimal trust stores; reject non-ASCII before any write.
  ForEach ($Character In $BundleText.ToCharArray()) {
    If ([System.Int32]$Character -gt 0x7F) {
      New-ErrorRecord `
        -Category:([System.Management.Automation.ErrorCategory]::InvalidData) `
        -ErrorId:([ExporterExitCode]::WriteFailure) `
        -IsFatal:$True `
        -Message:($Script:Message['Write-CertificateBundle.NonAscii']) `
        -TargetObject:$Path
    }
  }

  $BundleBytes = $Encoding.GetBytes($BundleText)

  Try {
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    $BundleSha256 = [System.BitConverter]::ToString(
      $Sha256.ComputeHash($BundleBytes)
    ).Replace('-', '')

    # Avoid rewriting byte-identical content so callers keep stable mtimes and skip needless swaps.
    If ([System.IO.File]::Exists($FullPath) -eq $True) {
      $ExistingBytes = [System.IO.File]::ReadAllBytes($FullPath)
      $ExistingSha256 = [System.BitConverter]::ToString(
        $Sha256.ComputeHash($ExistingBytes)
      ).Replace('-', '')
      $BundleUnchanged = [System.Boolean](
        $ExistingBytes.Count -eq $BundleBytes.Count -and
        $ExistingSha256 -eq $BundleSha256
      )
    }

    If ($WriteManifest.IsPresent -eq $True) {
      $ManifestPath = '{0}.sha256' -f $Path
      $ManifestFullPath = '{0}.sha256' -f $FullPath
      # sha256sum-compatible sidecars are "<hex><two spaces><leaf><LF>" for portable verification.
      $ManifestText = '{0}  {1}{2}' -f $BundleSha256, $PathLeaf, "`n"
      $ManifestBytes = $Encoding.GetBytes($ManifestText)

      If ([System.IO.File]::Exists($ManifestFullPath) -eq $True) {
        $ExistingBytes = [System.IO.File]::ReadAllBytes($ManifestFullPath)
        $ExistingSha256 = [System.BitConverter]::ToString(
          $Sha256.ComputeHash($ExistingBytes)
        ).Replace('-', '')
        $ManifestUnchanged = [System.Boolean](
          $ExistingBytes.Count -eq $ManifestBytes.Count -and
          $ExistingSha256 -eq (
            [System.BitConverter]::ToString(
              $Sha256.ComputeHash($ManifestBytes)
            ).Replace('-', '')
          )
        )
      }
    } Else {
      $ManifestUnchanged = $True
    }

    If ($BundleUnchanged -eq $True -and $ManifestUnchanged -eq $True) {
      $Status = 'Unchanged'
    } Else {
      $OperationTarget = $FullPath
      If ($WriteManifest.IsPresent -eq $True) {
        $OperationTarget = '{0} and {1}' -f $FullPath, $ManifestFullPath
      }

      If (
        [System.Boolean]$PSCmdlet.ShouldProcess(
          $OperationTarget,
          'Write certificate bundle'
        ) -eq $False
      ) {
        $Status = 'WhatIf'
      } Else {
        Try {
          If ($BundleUnchanged -eq $False) {
            # Same-directory temps keep the final Replace/Move atomic on the target volume.
            $BundleTempPath = Join-Path `
              -Path:$DirectoryPath `
              -ChildPath:('.{0}.{1}.tmp' -f $PathLeaf, [System.Guid]::NewGuid())
            [System.IO.File]::WriteAllText($BundleTempPath, $BundleText, $Encoding)

            If ([System.IO.File]::Exists($FullPath) -eq $True) {
              $BundleBackupPath = Join-Path `
                -Path:$DirectoryPath `
                -ChildPath:('.{0}.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
              [System.IO.File]::Replace($BundleTempPath, $FullPath, $BundleBackupPath)
              [System.IO.File]::Delete($BundleBackupPath)
            } Else {
              [System.IO.File]::Move($BundleTempPath, $FullPath)
            }
          }

          If ($WriteManifest.IsPresent -eq $True -and $ManifestUnchanged -eq $False) {
            # Manifest writes use the same temp-then-swap path so bundle metadata is never half-written.
            $ManifestTempPath = Join-Path `
              -Path:$DirectoryPath `
              -ChildPath:('.{0}.sha256.{1}.tmp' -f $PathLeaf, [System.Guid]::NewGuid())
            [System.IO.File]::WriteAllText($ManifestTempPath, $ManifestText, $Encoding)

            If ([System.IO.File]::Exists($ManifestFullPath) -eq $True) {
              $ManifestBackupPath = Join-Path `
                -Path:$DirectoryPath `
                -ChildPath:('.{0}.sha256.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
              [System.IO.File]::Replace($ManifestTempPath, $ManifestFullPath, $ManifestBackupPath)
              [System.IO.File]::Delete($ManifestBackupPath)
            } Else {
              [System.IO.File]::Move($ManifestTempPath, $ManifestFullPath)
            }
          }

          $Status = 'Written'
        } Catch {
          # Failed atomic swaps can leave temp or backup artifacts; remove them so retry is clean.
          If (
            [System.String]::IsNullOrEmpty($BundleTempPath) -eq $False -and
            [System.IO.File]::Exists($BundleTempPath) -eq $True
          ) {
            [System.IO.File]::Delete($BundleTempPath)
          }

          If (
            [System.String]::IsNullOrEmpty($BundleBackupPath) -eq $False -and
            [System.IO.File]::Exists($BundleBackupPath) -eq $True
          ) {
            [System.IO.File]::Delete($BundleBackupPath)
          }

          If (
            [System.String]::IsNullOrEmpty($ManifestTempPath) -eq $False -and
            [System.IO.File]::Exists($ManifestTempPath) -eq $True
          ) {
            [System.IO.File]::Delete($ManifestTempPath)
          }

          If (
            [System.String]::IsNullOrEmpty($ManifestBackupPath) -eq $False -and
            [System.IO.File]::Exists($ManifestBackupPath) -eq $True
          ) {
            [System.IO.File]::Delete($ManifestBackupPath)
          }

          New-ErrorRecord `
            -Category:([System.Management.Automation.ErrorCategory]::WriteError) `
            -ErrorId:([ExporterExitCode]::WriteFailure) `
            -Exception:$PSItem.Exception `
            -IsFatal:$True `
            -Message:($Script:Message['Write-CertificateBundle.WriteFailure'] -f $PSItem.Exception.Message) `
            -TargetObject:$Path
        }
      }
    }
  } Finally {
    If ($Null -ne $Sha256) {
      $Sha256.Dispose()
    }
  }

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [PSCustomObject]$Result = [PSCustomObject]@{
    Path             = [System.String]$Path
    Status           = [System.String]$Status
    BundleSha256     = [System.String]$BundleSha256
    CertificateCount = [System.Int32]$PemBlock.Count
    ManifestPath     = $ManifestPath
  }

  # Do a 'soft' return by outputting the result to the pipe without using the return keyword
  #   which would immediately end the function, this enables us to have the very last
  #   executing item be Write-Debug giving us a valuable breakpoint and better debugging output.
  $Result

  Write-Debug -Message:'[Write-CertificateBundle] Exiting'
}

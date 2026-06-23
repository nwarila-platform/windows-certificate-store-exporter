#Requires -Version 5.1
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

# Message(s)
$Script:Message += @{
  'Write-CertificateBundle.BelowMinimum'      = 'Certificate bundle has {0} certificate(s), below the required minimum of {1}.'
  'Write-CertificateBundle.NonAscii'          = 'Certificate bundle content must be ASCII.'
  'Write-CertificateBundle.NonFileSystemPath' = 'Certificate bundle path must resolve to the FileSystem provider: {0}'
  'Write-CertificateBundle.StaleManifest'     = 'Refusing to write certificate bundle because -WriteManifest is absent and an existing .sha256 sidecar would become stale for {0}. Re-run with -WriteManifest to refresh the sidecar atomically alongside the bundle, or remove the .sha256 sidecar manually.'
  'Write-CertificateBundle.WriteFailure'      = 'Failed to write certificate bundle: {0}'
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
    [ValidateRange(1, [System.Int32]::MaxValue)]
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
  [System.Boolean]$Private:BundleFirstWritten = $False
  [System.String]$Private:BundleSha256 = [System.String]::Empty
  [System.Byte[]]$Private:BundleBytes = [System.Byte[]]@()
  [System.IO.FileStream]$Private:BundleTempStream = $Null
  [System.String]$Private:BundleTempPath = [System.String]::Empty
  [System.String]$Private:BundleText = [System.String]::Empty
  [System.Boolean]$Private:BundleUnchanged = $False
  [System.String]$Private:DirectoryPath = [System.String]::Empty
  [System.Management.Automation.PSDriveInfo]$Private:Drive = $Null
  [System.Text.UTF8Encoding]$Private:Encoding = $Null
  [System.Byte[]]$Private:ExistingBytes = [System.Byte[]]@()
  [System.String]$Private:ExistingSha256 = [System.String]::Empty
  [System.String]$Private:FullPath = [System.String]::Empty
  [System.String]$Private:ManifestPath = $Null
  [System.Byte[]]$Private:ManifestBytes = [System.Byte[]]@()
  [System.String]$Private:ManifestFullPath = [System.String]::Empty
  [System.String]$Private:ManifestBackupPath = [System.String]::Empty
  [System.IO.FileStream]$Private:ManifestTempStream = $Null
  [System.String]$Private:ManifestTempPath = [System.String]::Empty
  [System.String]$Private:ManifestText = [System.String]::Empty
  [System.Boolean]$Private:ManifestUnchanged = $False
  [System.String]$Private:OperationTarget = [System.String]::Empty
  [System.String]$Private:PathLeaf = [System.String]::Empty
  [System.Management.Automation.ProviderInfo]$Private:Provider = $Null
  [System.String]$Private:RestoreDiscardPath = [System.String]::Empty
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
  $FullPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $Path,
    [ref]$Provider,
    [ref]$Drive
  )

  If ($Provider.Name -ne 'FileSystem') {
    New-ErrorRecord `
      -Category:([System.Management.Automation.ErrorCategory]::InvalidArgument) `
      -ErrorId:([ExporterExitCode]::WriteFailure) `
      -IsFatal:$True `
      -Message:($Script:Message['Write-CertificateBundle.NonFileSystemPath'] -f $Path) `
      -TargetObject:$Path
  }

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

    $ManifestFullPath = '{0}.sha256' -f $FullPath

    If ($WriteManifest.IsPresent -eq $True) {
      $ManifestPath = '{0}.sha256' -f $Path
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

    If (
      $WriteManifest.IsPresent -eq $False -and
      $BundleUnchanged -eq $False -and
      [System.IO.File]::Exists($ManifestFullPath) -eq $True
    ) {
      New-ErrorRecord `
        -Category:([System.Management.Automation.ErrorCategory]::WriteError) `
        -ErrorId:([ExporterExitCode]::WriteFailure) `
        -IsFatal:$True `
        -Message:($Script:Message['Write-CertificateBundle.StaleManifest'] -f $FullPath) `
        -TargetObject:$Path
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
            $BundleTempStream = [System.IO.FileStream]::new(
              $BundleTempPath,
              [System.IO.FileMode]::CreateNew,
              [System.IO.FileAccess]::Write,
              [System.IO.FileShare]::None
            )

            Try {
              $BundleTempStream.Write($BundleBytes, 0, $BundleBytes.Count)
            } Finally {
              $BundleTempStream.Dispose()
              $BundleTempStream = $Null
            }

            If ([System.IO.File]::Exists($FullPath) -eq $True) {
              # Retain the prior bundle as a backup through BOTH swaps so a later manifest-swap
              #   failure can roll this bundle back to the prior on-disk pair.
              $BundleBackupPath = Join-Path `
                -Path:$DirectoryPath `
                -ChildPath:('.{0}.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
              [System.IO.File]::Replace($BundleTempPath, $FullPath, $BundleBackupPath)
            } Else {
              [System.IO.File]::Move($BundleTempPath, $FullPath)
              $BundleFirstWritten = $True
            }
          }

          If ($WriteManifest.IsPresent -eq $True -and $ManifestUnchanged -eq $False) {
            # Manifest writes use the same temp-then-swap path so bundle metadata is never half-written.
            $ManifestTempPath = Join-Path `
              -Path:$DirectoryPath `
              -ChildPath:('.{0}.sha256.{1}.tmp' -f $PathLeaf, [System.Guid]::NewGuid())
            $ManifestTempStream = [System.IO.FileStream]::new(
              $ManifestTempPath,
              [System.IO.FileMode]::CreateNew,
              [System.IO.FileAccess]::Write,
              [System.IO.FileShare]::None
            )

            Try {
              $ManifestTempStream.Write($ManifestBytes, 0, $ManifestBytes.Count)
            } Finally {
              $ManifestTempStream.Dispose()
              $ManifestTempStream = $Null
            }

            If ([System.IO.File]::Exists($ManifestFullPath) -eq $True) {
              # Retain the prior manifest as a backup through the commit point as well.
              $ManifestBackupPath = Join-Path `
                -Path:$DirectoryPath `
                -ChildPath:('.{0}.sha256.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
              [System.IO.File]::Replace($ManifestTempPath, $ManifestFullPath, $ManifestBackupPath)
            } Else {
              [System.IO.File]::Move($ManifestTempPath, $ManifestFullPath)
            }
          }

          $Status = 'Written'

          # Both swaps committed; the retained backups are now safe to discard. Deleting a backup
          #   here can never corrupt the committed pair, so isolate each so a delete failure can
          #   never surface as a write failure or trigger a rollback of a good pair.
          If (
            [System.String]::IsNullOrEmpty($BundleBackupPath) -eq $False -and
            [System.IO.File]::Exists($BundleBackupPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($BundleBackupPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Committed bundle backup cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
          }

          If (
            [System.String]::IsNullOrEmpty($ManifestBackupPath) -eq $False -and
            [System.IO.File]::Exists($ManifestBackupPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($ManifestBackupPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Committed manifest backup cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
          }
        } Catch {
          # Roll the on-disk pair back to its prior state, then always surface the failure. The
          #   bundle is the FIRST swap, so it is the only file needing an active rollback; the
          #   manifest is last, so a manifest-swap failure self-rolls-back (its prior version is
          #   left in place). Every file operation is isolated in its own swallowing Try so a
          #   rollback or cleanup fault can never stop the terminal WriteFailure throw that drives
          #   the exit-5 mapping.
          If ($Status -ne 'Written') {
            If (
              [System.String]::IsNullOrEmpty($BundleBackupPath) -eq $False -and
              [System.IO.File]::Exists($BundleBackupPath) -eq $True
            ) {
              # The bundle Replace committed, so $FullPath holds the NEW bytes. Put the prior
              #   bundle back with a SINGLE atomic File.Replace (old-or-new, never missing); a
              #   Delete($FullPath) + Move(backup) restore would leave $FullPath absent if the Move
              #   threw after the Delete.
              Try {
                $RestoreDiscardPath = Join-Path `
                  -Path:$DirectoryPath `
                  -ChildPath:('.{0}.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
                [System.IO.File]::Replace($BundleBackupPath, $FullPath, $RestoreDiscardPath)
              } Catch {
                Write-Debug -Message:('[Write-CertificateBundle] Bundle rollback failed; pair may be mismatched but never missing: {0}' -f $PSItem.Exception.Message)
              }

              If (
                [System.String]::IsNullOrEmpty($RestoreDiscardPath) -eq $False -and
                [System.IO.File]::Exists($RestoreDiscardPath) -eq $True
              ) {
                Try {
                  [System.IO.File]::Delete($RestoreDiscardPath)
                } Catch {
                  Write-Debug -Message:('[Write-CertificateBundle] Rollback discard cleanup failed: {0}' -f $PSItem.Exception.Message)
                }
              }
            } ElseIf (
              $BundleFirstWritten -eq $True -and
              [System.IO.File]::Exists($FullPath) -eq $True
            ) {
              # A first-write bundle orphaned by a later manifest failure: restore the prior
              #   absent state with a single Delete.
              Try {
                [System.IO.File]::Delete($FullPath)
              } Catch {
                Write-Debug -Message:('[Write-CertificateBundle] First-write bundle rollback failed: {0}' -f $PSItem.Exception.Message)
              }
            }
          }

          # Remove any temp or backup artifact a failed swap left behind so a retry starts clean.
          #   Each delete is isolated so a stranded-artifact failure cannot mask the WriteFailure.
          If (
            [System.String]::IsNullOrEmpty($BundleTempPath) -eq $False -and
            [System.IO.File]::Exists($BundleTempPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($BundleTempPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Bundle temp cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
          }

          If (
            [System.String]::IsNullOrEmpty($ManifestTempPath) -eq $False -and
            [System.IO.File]::Exists($ManifestTempPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($ManifestTempPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Manifest temp cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
          }

          If (
            [System.String]::IsNullOrEmpty($BundleBackupPath) -eq $False -and
            [System.IO.File]::Exists($BundleBackupPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($BundleBackupPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Bundle backup cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
          }

          If (
            [System.String]::IsNullOrEmpty($ManifestBackupPath) -eq $False -and
            [System.IO.File]::Exists($ManifestBackupPath) -eq $True
          ) {
            Try {
              [System.IO.File]::Delete($ManifestBackupPath)
            } Catch {
              Write-Debug -Message:('[Write-CertificateBundle] Manifest backup cleanup failed: {0}' -f $PSItem.Exception.Message)
            }
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

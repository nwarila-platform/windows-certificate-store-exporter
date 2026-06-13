#Requires -Version 5.1

function Write-CertificateBundle {
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
    [CmdletBinding(SupportsShouldProcess = $True)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        $PemBlock = @(),

        [Parameter()]
        [ValidateRange(0, [System.Int32]::MaxValue)]
        [System.Int32]
        $MinimumCertificateCount = 1,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $WriteManifest
    )

    # Initalize Variable(s)
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
    [System.String]$Private:FailureMessage = [System.String]::Empty
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
    [System.Security.Cryptography.SHA256]$Private:Sha256 = $Null
    [System.String]$Private:Status = [System.String]::Empty

    if ($PemBlock.Count -lt $MinimumCertificateCount) {
        $FailureMessage = 'Certificate bundle has {0} certificate(s), below the required minimum of {1}.' -f $PemBlock.Count, $MinimumCertificateCount

        New-ErrorRecord `
            -Message $FailureMessage `
            -ErrorId ([ExporterExitCode]::BelowMinimumCertificateCount) `
            -Category ([System.Management.Automation.ErrorCategory]::InvalidData) `
            -TargetObject $Path `
            -IsFatal
    }

    $Encoding = [System.Text.UTF8Encoding]::new($False)
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $DirectoryPath = [System.IO.Path]::GetDirectoryName($FullPath)
    $PathLeaf = [System.IO.Path]::GetFileName($FullPath)
    $BundleText = ([System.String[]]$PemBlock -join "`n") -replace "`r`n?", "`n"

    foreach ($Character in $BundleText.ToCharArray()) {
        if ([System.Int32]$Character -gt 0x7F) {
            New-ErrorRecord `
                -Message 'Certificate bundle content must be ASCII.' `
                -ErrorId ([ExporterExitCode]::WriteFailure) `
                -Category ([System.Management.Automation.ErrorCategory]::InvalidData) `
                -TargetObject $Path `
                -IsFatal
        }
    }

    $BundleBytes = $Encoding.GetBytes($BundleText)
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $BundleSha256 = [System.BitConverter]::ToString(
            $Sha256.ComputeHash($BundleBytes)
        ).Replace('-', '')

        if ([System.IO.File]::Exists($FullPath) -eq $True) {
            $ExistingBytes = [System.IO.File]::ReadAllBytes($FullPath)
            $ExistingSha256 = [System.BitConverter]::ToString(
                $Sha256.ComputeHash($ExistingBytes)
            ).Replace('-', '')
            $BundleUnchanged = [System.Boolean](
                $ExistingBytes.Count -eq $BundleBytes.Count -and
                $ExistingSha256 -eq $BundleSha256
            )
        }

        if ($WriteManifest.IsPresent -eq $True) {
            $ManifestPath = '{0}.sha256' -f $Path
            $ManifestFullPath = '{0}.sha256' -f $FullPath
            $ManifestText = '{0}  {1}{2}' -f $BundleSha256, $PathLeaf, "`n"
            $ManifestBytes = $Encoding.GetBytes($ManifestText)

            if ([System.IO.File]::Exists($ManifestFullPath) -eq $True) {
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
        } else {
            $ManifestUnchanged = $True
        }

        if ($BundleUnchanged -eq $True -and $ManifestUnchanged -eq $True) {
            $Status = 'Unchanged'
        } else {
            $OperationTarget = $FullPath
            if ($WriteManifest.IsPresent -eq $True) {
                $OperationTarget = '{0} and {1}' -f $FullPath, $ManifestFullPath
            }

            if (
                [System.Boolean]$PSCmdlet.ShouldProcess(
                    $OperationTarget,
                    'Write certificate bundle'
                ) -eq $False
            ) {
                $Status = 'WhatIf'
            } else {
                try {
                    if ($BundleUnchanged -eq $False) {
                        $BundleTempPath = Join-Path `
                            -Path $DirectoryPath `
                            -ChildPath ('.{0}.{1}.tmp' -f $PathLeaf, [System.Guid]::NewGuid())
                        [System.IO.File]::WriteAllText($BundleTempPath, $BundleText, $Encoding)

                        if ([System.IO.File]::Exists($FullPath) -eq $True) {
                            $BundleBackupPath = Join-Path `
                                -Path $DirectoryPath `
                                -ChildPath ('.{0}.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
                            [System.IO.File]::Replace($BundleTempPath, $FullPath, $BundleBackupPath)
                            [System.IO.File]::Delete($BundleBackupPath)
                        } else {
                            [System.IO.File]::Move($BundleTempPath, $FullPath)
                        }
                    }

                    if ($WriteManifest.IsPresent -eq $True -and $ManifestUnchanged -eq $False) {
                        $ManifestTempPath = Join-Path `
                            -Path $DirectoryPath `
                            -ChildPath ('.{0}.sha256.{1}.tmp' -f $PathLeaf, [System.Guid]::NewGuid())
                        [System.IO.File]::WriteAllText($ManifestTempPath, $ManifestText, $Encoding)

                        if ([System.IO.File]::Exists($ManifestFullPath) -eq $True) {
                            $ManifestBackupPath = Join-Path `
                                -Path $DirectoryPath `
                                -ChildPath ('.{0}.sha256.{1}.bak' -f $PathLeaf, [System.Guid]::NewGuid())
                            [System.IO.File]::Replace($ManifestTempPath, $ManifestFullPath, $ManifestBackupPath)
                            [System.IO.File]::Delete($ManifestBackupPath)
                        } else {
                            [System.IO.File]::Move($ManifestTempPath, $ManifestFullPath)
                        }
                    }

                    $Status = 'Written'
                } catch {
                    if (
                        [System.String]::IsNullOrEmpty($BundleTempPath) -eq $False -and
                        [System.IO.File]::Exists($BundleTempPath) -eq $True
                    ) {
                        [System.IO.File]::Delete($BundleTempPath)
                    }

                    if (
                        [System.String]::IsNullOrEmpty($BundleBackupPath) -eq $False -and
                        [System.IO.File]::Exists($BundleBackupPath) -eq $True
                    ) {
                        [System.IO.File]::Delete($BundleBackupPath)
                    }

                    if (
                        [System.String]::IsNullOrEmpty($ManifestTempPath) -eq $False -and
                        [System.IO.File]::Exists($ManifestTempPath) -eq $True
                    ) {
                        [System.IO.File]::Delete($ManifestTempPath)
                    }

                    if (
                        [System.String]::IsNullOrEmpty($ManifestBackupPath) -eq $False -and
                        [System.IO.File]::Exists($ManifestBackupPath) -eq $True
                    ) {
                        [System.IO.File]::Delete($ManifestBackupPath)
                    }

                    New-ErrorRecord `
                        -Message ('Failed to write certificate bundle: {0}' -f $PSItem.Exception.Message) `
                        -ErrorId ([ExporterExitCode]::WriteFailure) `
                        -Category ([System.Management.Automation.ErrorCategory]::WriteError) `
                        -TargetObject $Path `
                        -IsFatal
                }
            }
        }
    } finally {
        if ($Null -ne $Sha256) {
            $Sha256.Dispose()
        }
    }

    [PSCustomObject]@{
        Path             = [System.String]$Path
        Status           = [System.String]$Status
        BundleSha256     = [System.String]$BundleSha256
        CertificateCount = [System.Int32]$PemBlock.Count
        ManifestPath     = $ManifestPath
    }

}

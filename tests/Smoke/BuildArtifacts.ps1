$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$FunctionsFile = Join-Path -Path $ProjectRoot -ChildPath 'build\Export-CertificateStoreBundle.Functions.ps1'
$ReleaseFile = Join-Path -Path $ProjectRoot -ChildPath 'build\Export-CertificateStoreBundle.ps1'

if (-not (Test-Path -LiteralPath $FunctionsFile)) {
    throw ('Functions artifact missing: {0}' -f $FunctionsFile)
}

if (-not (Test-Path -LiteralPath $ReleaseFile)) {
    throw ('Release artifact missing: {0}' -f $ReleaseFile)
}

. $FunctionsFile

@(
    'ConvertTo-PemCertificate',
    'Export-CertificateStoreBundle',
    'Get-CertificateRawDataSha256',
    'Get-StoreCertificate',
    'New-CertificateStoreExporterResult',
    'New-ErrorRecord',
    'Resolve-ExitCode',
    'Select-ExportableCertificate',
    'Write-CertificateBundle'
) | ForEach-Object -Process {
    if ($Null -eq (Get-Command -Name $PSItem -CommandType Function -ErrorAction SilentlyContinue)) {
        throw ('Expected function not found: {0}' -f $PSItem)
    }
}

$PowerShellCommandName = 'powershell.exe'
if ($PSVersionTable.PSEdition -eq 'Core') {
    $PowerShellCommandName = 'pwsh'
}

$PowerShellCommand = Get-Command -Name $PowerShellCommandName -ErrorAction Stop
$BundlePath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (
    'entrypoint-smoke-{0}.pem' -f [System.Guid]::NewGuid().ToString('N')
)
$Arguments = [System.Collections.Generic.List[System.String]]::new()
$Arguments.Add('-NoLogo')
$Arguments.Add('-NoProfile')
$Arguments.Add('-NonInteractive')

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    $Arguments.Add('-ExecutionPolicy')
    $Arguments.Add('Bypass')
}

$Arguments.Add('-File')
$Arguments.Add($ReleaseFile)
$Arguments.Add('-Path')
$Arguments.Add($BundlePath)
$Arguments.Add('-StoreName')
$Arguments.Add('Root')
$Arguments.Add('-MinimumCertificateCount')
$Arguments.Add('0')
$Arguments.Add('-WhatIf')

$ReleaseOutput = & $PowerShellCommand.Source @Arguments 2>&1

if ($LASTEXITCODE -ne 0) {
    throw (
        'Release script smoke failed with exit code {0}:{1}{2}' -f
        $LASTEXITCODE,
        [System.Environment]::NewLine,
        ($ReleaseOutput -join [System.Environment]::NewLine)
    )
}

if (Test-Path -LiteralPath $BundlePath) {
    throw ('Release script smoke unexpectedly wrote: {0}' -f $BundlePath)
}

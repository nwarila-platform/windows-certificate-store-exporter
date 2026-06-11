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
    'Get-StoreCertificate',
    'New-ErrorRecord',
    'Select-ExportableCertificate',
    'Write-CertificateBundle'
) | ForEach-Object -Process {
    if ($Null -eq (Get-Command -Name $PSItem -CommandType Function -ErrorAction SilentlyContinue)) {
        throw ('Expected function not found: {0}' -f $PSItem)
    }
}

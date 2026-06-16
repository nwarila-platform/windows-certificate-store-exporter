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
  'Select-ExportableCertificate',
  'Test-CertificateStoreExporterWindows',
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
$Arguments.Add('-?')

$Null = & $PowerShellCommand.Source @Arguments 2>&1

if ($LASTEXITCODE -ne 0) {
  throw ('Release script help smoke failed with exit code {0}.' -f $LASTEXITCODE)
}

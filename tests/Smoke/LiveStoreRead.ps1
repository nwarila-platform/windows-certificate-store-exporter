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

$StoreNames = [System.String[]]@('Root', 'CA', 'Disallowed')

foreach ($StoreName in $StoreNames) {
  try {
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Certificates = @(
      Get-StoreCertificate `
        -StoreLocation LocalMachine `
        -StoreName $StoreName
    )
  } catch {
    throw ('Live store read failed for LocalMachine\{0}: {1}' -f $StoreName, $PSItem.Exception.Message)
  }

  if ($Certificates -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2[]]) {
    throw ('Live store read for LocalMachine\{0} did not return X509Certificate2[].' -f $StoreName)
  }

  foreach ($Certificate in $Certificates) {
    if ($Null -eq $Certificate) {
      throw ('Live store read for LocalMachine\{0} returned a null certificate.' -f $StoreName)
    }

    if ($Certificate -isnot [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
      throw ('Live store read for LocalMachine\{0} returned a non-certificate item.' -f $StoreName)
    }

    if ($Null -eq $Certificate.RawData) {
      throw ('Live store read for LocalMachine\{0} returned a certificate with null RawData.' -f $StoreName)
    }
  }
}

$PowerShellCommandName = 'powershell.exe'
if ($PSVersionTable.PSEdition -eq 'Core') {
  $PowerShellCommandName = 'pwsh'
}

$PowerShellCommand = Get-Command -Name $PowerShellCommandName -ErrorAction Stop
$SmokeRoot = Join-Path `
  -Path ([System.IO.Path]::GetTempPath()) `
  -ChildPath ('cert-store-live-smoke-{0}' -f [System.Guid]::NewGuid().ToString('N'))
$Null = New-Item -Path $SmokeRoot -ItemType Directory

try {
  $BundlePath = Join-Path -Path $SmokeRoot -ChildPath 'bundle.pem'
  $ReleaseErrorPath = Join-Path -Path $SmokeRoot -ChildPath 'release.stderr.txt'
  $ManifestPath = '{0}.sha256' -f $BundlePath
  $Arguments = [System.Collections.Generic.List[System.String]]::new()
  $Arguments.Add('-NoLogo')
  $Arguments.Add('-NoProfile')
  $Arguments.Add('-NonInteractive')
  $Arguments.Add('-OutputFormat')
  $Arguments.Add('XML')

  if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    $Arguments.Add('-ExecutionPolicy')
    $Arguments.Add('Bypass')
  }

  $Arguments.Add('-File')
  $Arguments.Add($ReleaseFile)
  $Arguments.Add('-Path')
  $Arguments.Add($BundlePath)
  $Arguments.Add('-WhatIf')
  $Arguments.Add('-MinimumCertificateCount')
  $Arguments.Add('0')

  $ReleaseOutput = @(& $PowerShellCommand.Source @Arguments 2> $ReleaseErrorPath)
  $ReleaseExitCode = [System.Int32]$LASTEXITCODE

  if ($ReleaseExitCode -ne 0) {
    $ReleaseError = [System.String]::Empty
    if (Test-Path -LiteralPath $ReleaseErrorPath) {
      $ReleaseError = Get-Content -LiteralPath $ReleaseErrorPath -Raw
    }

    throw (
      'Release live WhatIf smoke failed with exit code {0}.{1}{2}' -f
      $ReleaseExitCode,
      [System.Environment]::NewLine,
      $ReleaseError
    )
  }

  if (Test-Path -LiteralPath $BundlePath) {
    throw ('Release live WhatIf smoke wrote a bundle file: {0}' -f $BundlePath)
  }

  if (Test-Path -LiteralPath $ManifestPath) {
    throw ('Release live WhatIf smoke wrote a manifest file: {0}' -f $ManifestPath)
  }

  $Results = @(
    $ReleaseOutput | Where-Object -FilterScript {
      $Null -ne $PSItem -and
      $PSItem.PSTypeNames -contains 'Deserialized.CertificateStoreExporter.Result'
    }
  )

  if ($Results.Count -ne 1) {
    throw ('Release live WhatIf smoke emitted {0} result object(s), expected 1.' -f $Results.Count)
  }

  $Result = $Results[0]

  if ([System.String]$Result.Status -ne 'WhatIf') {
    throw ('Release live WhatIf smoke returned status {0}, expected WhatIf.' -f $Result.Status)
  }

  if ($Null -eq $Result.Examined -or [System.Int32]$Result.Examined -lt 0) {
    throw ('Release live WhatIf smoke returned invalid Examined value: {0}' -f $Result.Examined)
  }

  $Thumbprints = [System.String[]]@(
    $Result.Thumbprints | ForEach-Object -Process {
      [System.String]$PSItem
    }
  )

  foreach ($Thumbprint in $Thumbprints) {
    if ($Thumbprint -notmatch '^[A-Fa-f0-9]{64}$') {
      throw ('Release live WhatIf smoke returned a non-SHA-256 thumbprint: {0}' -f $Thumbprint)
    }
  }
} finally {
  if (Test-Path -LiteralPath $SmokeRoot) {
    Remove-Item -LiteralPath $SmokeRoot -Recurse -Force
  }
}

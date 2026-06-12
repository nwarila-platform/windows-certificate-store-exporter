# Getting Started

This tutorial builds the release script, exports a PEM bundle from the default
Windows certificate stores, and checks the files it produced.

## Prerequisites

- Windows with Windows PowerShell 5.1.
- Pester v5 and PSScriptAnalyzer if you want to run the full build gate.
- Read access to the Windows certificate stores you export.

## Build the Script

From the repository root:

```powershell
.\build.ps1 -Task All
```

The build creates two ignored files under `build/`:

- `Export-CertificateStoreBundle.ps1` for release and manual use.
- `Export-CertificateStoreBundle.Functions.ps1` for tests and coverage.

## Preview the Export

Pick a destination path:

```powershell
$BundlePath = Join-Path -Path $env:TEMP -ChildPath 'aws-ca-bundle.pem'
```

Preview the write:

```powershell
$Preview = .\build\Export-CertificateStoreBundle.ps1 `
    -Path $BundlePath `
    -WriteManifest `
    -WhatIf

$Preview | Format-List Path,Status,CertificateCount,BundleSha256,ManifestPath
```

`Status` is `WhatIf`, and neither the bundle nor the `.sha256` sidecar is
created.

## Write the Bundle

Run the same command without `-WhatIf`:

```powershell
$Result = .\build\Export-CertificateStoreBundle.ps1 `
    -Path $BundlePath `
    -WriteManifest

$Result | Format-List *
```

The default export reads `LocalMachine\Root` and `LocalMachine\CA`, always reads
`LocalMachine\Disallowed`, subtracts any matching certificates by SHA-256 over
their DER bytes, and writes the surviving certificates in deterministic SHA-256
order.

## Read the Result Object

The command emits one object whose first type name is
`CertificateStoreExporter.Result`:

```powershell
$Result.PSTypeNames[0]
$Result.Excluded | Format-List
$Result.Thumbprints
```

Important fields:

- `Status` is `Written`, `Unchanged`, or `WhatIf`.
- `CertificateCount` is the number of PEM certificates in the bundle.
- `Thumbprints` are SHA-256 DER hashes in bundle order, not SHA-1
  `X509Certificate2.Thumbprint` values.
- `BundleSha256` is the SHA-256 hash of the bundle bytes.
- `GeneratedAtUtc` is present on the object only; it is not written into the PEM
  body.

## Inspect the PEM

```powershell
Get-Content -Path $BundlePath -TotalCount 12
```

Each certificate block begins with comment headers:

```text
# Subject: ...
# Issuer: ...
# Serial: ...
# SHA-256: ...
# NotBefore: ...
# NotAfter: ...
# Source: Root
-----BEGIN CERTIFICATE-----
```

The PEM body uses LF line endings, no byte-order mark, ASCII bytes, and
64-character base64 lines.

## Verify the Manifest

When `-WriteManifest` is set, the sidecar is `<bundle>.sha256` and uses the same
sha256sum-style format as release artifacts:

```powershell
$Expected = ((Get-Content -Raw $Result.ManifestPath) -split '\s+')[0]
$Actual = (Get-FileHash -Algorithm SHA256 -Path $BundlePath).Hash

if ($Actual -ne $Expected) {
    throw "SHA-256 mismatch: expected $Expected but got $Actual"
}
```

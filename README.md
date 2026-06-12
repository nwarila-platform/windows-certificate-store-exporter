# windows-certificate-store-exporter

[![CI](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml/badge.svg)](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml)
[![Windows PowerShell 5.1](https://img.shields.io/badge/Windows%20PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PSScriptAnalyzer](https://img.shields.io/badge/lint-house%20PSScriptAnalyzer-blue)](PSScriptAnalyzerSettings.psd1)
[![Tested with Pester](https://img.shields.io/badge/tested%20with-Pester%20v5-green)](https://pester.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

`windows-certificate-store-exporter` builds one Windows PowerShell 5.1 script:
`Export-CertificateStoreBundle.ps1`. The script reads Windows certificate stores,
subtracts `Disallowed`, filters and de-duplicates certificates, and writes a
deterministic PEM bundle suitable for `AWS_CA_BUNDLE` or AWS CLI `ca_bundle`.

The project uses the `NWarila/powershell-template` guardrails with this repo's
house `PSScriptAnalyzerSettings.psd1`, SG-1 custom analyzer rules, Pester v5,
SHA-pinned GitHub Actions, Renovate, and Diataxis documentation. It is a
single-script project, not a PowerShell module.

## Quickstart

Build and validate the release script:

```powershell
.\build.ps1 -Task All
```

Preview an export without writing files:

```powershell
.\build\Export-CertificateStoreBundle.ps1 `
    -Path "$env:TEMP\aws-ca-bundle.pem" `
    -WriteManifest `
    -WhatIf
```

Write the bundle:

```powershell
$Result = .\build\Export-CertificateStoreBundle.ps1 `
    -Path "$env:TEMP\aws-ca-bundle.pem" `
    -WriteManifest

$Result | Format-List Path,Status,CertificateCount,BundleSha256,ManifestPath
```

The success stream returns one `CertificateStoreExporter.Result` object. Known
failures throw structured errors and map to process exit codes; they do not emit
a result object.

## Usage

```powershell
.\Export-CertificateStoreBundle.ps1 -Path C:\ProgramData\NWarila\aws-ca-bundle.pem
```

| Parameter | Values | Default | Notes |
| --- | --- | --- | --- |
| `-Path` | Non-empty string | Required | Bundle destination path. |
| `-StoreLocation` | `LocalMachine`, `CurrentUser` | `LocalMachine` | Windows logical certificate-store location. |
| `-StoreName` | `Root`, `CA` | `Root,CA` | Stores to export. `Disallowed` is always read separately and subtracted. |
| `-IncludeExpired` | Switch | Off | Retains expired and not-yet-valid certificates. |
| `-MinimumCertificateCount` | Integer `0` or greater | `1` | Fail-closed floor before any write occurs. |
| `-WriteManifest` | Switch | Off | Writes `<bundle>.sha256` next to the bundle. |
| `-LogLevel` | Seven digits | `1111111` | Accepted by the entry script for ScriptTemplate runtime context. |
| `-DebugLevel` | Three digits | `000` | Accepted by the entry script for ScriptTemplate runtime context. |
| `-Trap` | Switch | Off | Re-emits known errors before exiting with their mapped code. |

The script also honors common `SupportsShouldProcess` parameters such as
`-WhatIf` and `-Confirm`.

## AWS CLI

The exporter is produce-only. It writes the bundle and optional SHA-256 sidecar;
it does not set environment variables and does not edit `~/.aws/config`.

For the current PowerShell process:

```powershell
$env:AWS_CA_BUNDLE = 'C:\ProgramData\NWarila\aws-ca-bundle.pem'
```

For an AWS CLI profile:

```powershell
aws configure set ca_bundle C:\ProgramData\NWarila\aws-ca-bundle.pem
```

## Releases

Tags matching `v*` create a GitHub Release after `.\build.ps1 -Task All` passes
on `windows-latest` with Windows PowerShell 5.1. Each release publishes:

- `Export-CertificateStoreBundle.ps1`
- `Export-CertificateStoreBundle.ps1.sha256`

Authenticode signing is deferred; the SHA-256 sidecar is the integrity mechanism.
Verify a downloaded release before use:

```powershell
$Expected = ((Get-Content -Raw .\Export-CertificateStoreBundle.ps1.sha256) -split '\s+')[0]
$Actual = (Get-FileHash -Algorithm SHA256 .\Export-CertificateStoreBundle.ps1).Hash

if ($Actual -ne $Expected) {
    throw "SHA-256 mismatch: expected $Expected but got $Actual"
}
```

## Validate Locally

```powershell
.\build.ps1 -Task All
```

`build.ps1` emits generated artifacts under `build/`, runs PSScriptAnalyzer
against the merged script artifacts and `build.ps1`, runs smoke tests, and
enforces the Pester coverage gate.

## Documentation

Documentation follows the [Diataxis framework](https://diataxis.fr/). Start at
[docs/README.md](docs/README.md).

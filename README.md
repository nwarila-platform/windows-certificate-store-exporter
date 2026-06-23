# windows-certificate-store-exporter

[![CI](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml/badge.svg)](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/nwarila-platform/windows-certificate-store-exporter/badge)](https://scorecard.dev/viewer/?uri=github.com/nwarila-platform/windows-certificate-store-exporter)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/13314/badge)](https://www.bestpractices.dev/projects/13314)
[![Windows PowerShell 5.1](https://img.shields.io/badge/Windows%20PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PSScriptAnalyzer](https://img.shields.io/badge/lint-house%20PSScriptAnalyzer-blue)](PSScriptAnalyzerSettings.psd1)
[![Tested with Pester](https://img.shields.io/badge/tested%20with-Pester%20v5-green)](https://pester.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

`windows-certificate-store-exporter` builds one Windows PowerShell 5.1 script:
`Export-CertificateStoreBundle.ps1`. The script reads Windows certificate stores,
subtracts `Disallowed`, filters and de-duplicates certificates, and writes a
deterministic RFC 7468 PEM bundle that TLS-verifying clients can consume.

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
    -Path "$env:TEMP\ca-bundle.pem" `
    -WriteManifest `
    -WhatIf
```

Write the bundle:

```powershell
$Result = .\build\Export-CertificateStoreBundle.ps1 `
    -Path "$env:TEMP\ca-bundle.pem" `
    -WriteManifest

$Result | Format-List Path,Status,CertificateCount,BundleSha256,ManifestPath
```

The success stream returns one `CertificateStoreExporter.Result` object. Known
failures throw structured errors and map to process exit codes; they do not emit
a result object.

## Install / Uninstall

Download `Export-CertificateStoreBundle.ps1` and its sidecars from the
[latest GitHub Release](https://github.com/nwarila-platform/windows-certificate-store-exporter/releases/latest):
`Export-CertificateStoreBundle.ps1.sha256` and
`Export-CertificateStoreBundle.ps1.intoto.jsonl`. Verify the release asset
before installing it: use the SLSA steps in
[Verify build provenance](#verify-build-provenance-recommended) and the
sidecar steps in [Quick offline integrity](#quick-offline-integrity-sha-256-sidecar).

Place the script where your automation expects it, for example:

```powershell
New-Item -ItemType Directory -Path C:\ProgramData\NWarila\bin -Force
Copy-Item .\Export-CertificateStoreBundle.ps1 C:\ProgramData\NWarila\bin\
```

If Windows marks the downloaded file as remote content, unblock it after
verification:

```powershell
Unblock-File C:\ProgramData\NWarila\bin\Export-CertificateStoreBundle.ps1
```

If your host policy does not allow local scripts, set an execution policy that
fits your environment. A per-process example is:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Run the installed script with the required `-Path` parameter:

```powershell
C:\ProgramData\NWarila\bin\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\ca-bundle.pem `
    -WriteManifest
```

To update, download the newer release assets, verify them again, and replace the
installed script. To uninstall, delete the installed script and any downloaded
release sidecars (`.sha256` and `.intoto.jsonl`). The exporter does not install a
module, write registry keys, or maintain global state.

## Usage

```powershell
.\Export-CertificateStoreBundle.ps1 -Path C:\ProgramData\NWarila\ca-bundle.pem
```

| Parameter | Values | Default | Notes |
| --- | --- | --- | --- |
| `-Path` | Non-empty string | Required | Bundle destination path. |
| `-StoreLocation` | `LocalMachine`, `CurrentUser` | `LocalMachine` | Windows logical certificate-store location. |
| `-StoreName` | `Root`, `CA` | `Root` | Stores to export. `CA` also exports intermediates and emits a trust-expansion warning. `Disallowed` is always read separately and subtracted. |
| `-IncludeExpired` | Switch | Off | Retains expired and not-yet-valid certificates. |
| `-MinimumCertificateCount` | Integer `1` or greater | `1` | Fail-closed floor before any write occurs. |
| `-WriteManifest` | Switch | Off | Writes `<bundle>.sha256` next to the bundle. |

The script also honors common `SupportsShouldProcess` parameters such as
`-WhatIf` and `-Confirm`.

The default `-StoreName Root` export is intentionally root-only. Request
`-StoreName CA` or `-StoreName Root,CA` only when you intend to include
intermediate CA certificates as additional trust anchors for clients that
perform partial-chain validation.

## Using the Bundle

The exporter is produce-only. It writes the bundle and optional SHA-256 sidecar;
it does not set environment variables or edit consumer configuration.

- AWS CLI: `$env:AWS_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'` or
  `aws configure set ca_bundle C:\ProgramData\NWarila\ca-bundle.pem`
- curl: `curl.exe --cacert C:\ProgramData\NWarila\ca-bundle.pem https://example.com`
  or `$env:CURL_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'`
- OpenSSL: `openssl s_client -connect example.com:443 -CAfile C:\ProgramData\NWarila\ca-bundle.pem`
  or `$env:SSL_CERT_FILE = 'C:\ProgramData\NWarila\ca-bundle.pem'`
- Python requests: `$env:REQUESTS_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'`
- git: `git config --global http.sslCAInfo C:\ProgramData\NWarila\ca-bundle.pem`

Choose the wiring supported by the client that will verify TLS with the bundle.

## Releases

Tags matching `v*` create a GitHub Release from a sealed `.\build.ps1 -Task Build`
artifact after Analyze/Test/Smoke validates that sealed copy on `windows-latest`
with Windows PowerShell 5.1. The release is published only after all assets are
attached. Each release publishes:

- `Export-CertificateStoreBundle.ps1`
- `Export-CertificateStoreBundle.ps1.sha256`
- `Export-CertificateStoreBundle.ps1.intoto.jsonl` (SLSA build provenance)

### Verify build provenance (recommended)

Each release carries SLSA Build L3 provenance generated by
[`slsa-github-generator`](https://github.com/slsa-framework/slsa-github-generator)
and signed via Sigstore. Confirm the artifact was built by this repository's
release workflow with [`slsa-verifier`](https://github.com/slsa-framework/slsa-verifier):

```
slsa-verifier verify-artifact Export-CertificateStoreBundle.ps1 `
  --provenance-path Export-CertificateStoreBundle.ps1.intoto.jsonl `
  --source-uri github.com/nwarila-platform/windows-certificate-store-exporter `
  --source-tag v1.0.0
```

`PASSED: SLSA verification passed` confirms the artifact's SHA-256 is a signed
subject built from this source at that tag. For the strongest check, also pin the
builder with `--builder-id https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@refs/tags/v2.1.0`.

### Quick offline integrity (SHA-256 sidecar)

The `.sha256` sidecar is a fast, provenance-independent integrity check:

```powershell
$Expected = ((Get-Content -Raw .\Export-CertificateStoreBundle.ps1.sha256) -split '\s+')[0]
$Actual = (Get-FileHash -Algorithm SHA256 .\Export-CertificateStoreBundle.ps1).Hash

if ($Actual -ne $Expected) {
    throw "SHA-256 mismatch: expected $Expected but got $Actual"
}
```

Authenticode (publisher) signing is deferred (see ADR-repo/0005); SLSA build
provenance is the supply-chain integrity mechanism in the meantime.

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

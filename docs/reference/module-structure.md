# Project Structure

```text
build.ps1
src/
  EntryPoint.ps1
  Private/
    Constants.ps1
    ConvertTo-PemCertificate.ps1
    Get-CertificateRawDataSha256.ps1
    Get-StoreCertificate.ps1
    New-CertificateStoreExporterResult.ps1
    New-ErrorRecord.ps1
    Resolve-ExitCode.ps1
    Select-ExportableCertificate.ps1
    Test-CertificateStoreExporterWindows.ps1
    Write-CertificateBundle.ps1
  Public/
    Export-CertificateStoreBundle.ps1
tests/
  Helpers/
  Private/
  Public/
  Smoke/
docs/
  README.md
```

The repository authors structured source under `src/` and ships a single built
script, not a PowerShell module.

## Build Artifacts

`build.ps1 -Task Build` creates:

| Artifact | Purpose |
| --- | --- |
| `build/Export-CertificateStoreBundle.ps1` | Release script with the entrypoint, private helpers, and public orchestrator folded into one file. |
| `build/Export-CertificateStoreBundle.Functions.ps1` | Functions-only artifact dot-sourced by tests and used as the Pester coverage target. |

The `build/` directory is ignored. Do not edit generated artifacts directly.

## Build Tasks

| Task | Behavior |
| --- | --- |
| `Build` | Assemble generated artifacts and syntax-check them. |
| `Analyze` | Run PSScriptAnalyzer over the release script, functions-only artifact, and `build.ps1` using the house settings. |
| `Test` | Run smoke tests and Pester with the 90 percent coverage gate. |
| `Clean` | Remove `build/`. |
| `All` | Run `Clean`, `Build`, `Analyze`, and `Test`. |

## Release Workflow

`.github/workflows/release.yaml` runs on tags matching `v*`. It validates the
same `build.ps1 -Task All` gate on `windows-latest` with Windows PowerShell 5.1,
then publishes these GitHub Release assets:

- `Export-CertificateStoreBundle.ps1`
- `Export-CertificateStoreBundle.ps1.sha256`

The release script is unsigned for now; verify the SHA-256 sidecar before use.

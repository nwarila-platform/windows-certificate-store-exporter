# Project structure

```text
build.ps1
src/
  EntryPoint.ps1
  Private/
    ConvertTo-PemCertificate.ps1
    Get-StoreCertificate.ps1
    New-ErrorRecord.ps1
    Select-ExportableCertificate.ps1
    Write-CertificateBundle.ps1
  Public/
    Export-CertificateStoreBundle.ps1
tests/
  Private/
  Public/
  Smoke/
docs/
  README.md
```

The repository authors source in a start-uninstaller-style script layout and
ships a single built artifact, not a PowerShell module. `build.ps1 -Task Build`
concatenates `src/Private/*.ps1`, then `src/Public/*.ps1`, then the
`src/EntryPoint.ps1` invocation body into `build/Export-CertificateStoreBundle.ps1`.
It also emits `build/Export-CertificateStoreBundle.Functions.ps1`, which tests
dot-source and Pester uses as the code-coverage target.

The `build/` directory is intentionally ignored. Release automation is planned
to publish the built script and a SHA-256 sidecar from GitHub Releases.

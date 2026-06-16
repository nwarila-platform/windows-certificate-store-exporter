# REPORT - SG-6 Result Comments

Status: complete
Branch: `codex-sg6-resultcomments`

## Changes

- Added the canonical soft-return WHY comment blocks to:
  - `src/Private/ConvertTo-PemCertificate.ps1`
  - `src/Private/Get-StoreCertificate.ps1`
  - `src/Private/Select-ExportableCertificate.ps1`
  - `src/Private/Test-CertificateStoreExporterWindows.ps1`
  - `src/Private/Resolve-ExitCode.ps1`
- The wording matches the canary in
  `src/Private/Get-CertificateRawDataSha256.ps1` exactly.
- `Resolve-ExitCode.ps1` keeps the existing intent comments; the two canonical
  blocks were placed inside the mapped-code `If` branch above the existing
  `$Result` handoff and emit.

## Scope

- Comments only.
- No statement, value, or structure changed.
- Only the five requested functions were touched.
- No analyzer code changed.
- No analyzer settings changed.
- No push or merge performed.

## Verification

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All
```

Result: passed.

- Build OK.
- Analyze: 0 findings.
- Pester: 90 passed, 0 failed.
- Coverage: 95.93% (threshold 90%).
- Exit-code tests: six mappings passed.
- Smoke stage: passed (`BuildArtifacts.ps1`, `LiveStoreRead.ps1`).

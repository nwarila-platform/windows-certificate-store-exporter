# Canary-Perfect Normalization Report

## Files Changed

- `src/Private/ConvertTo-PemCertificate.ps1`
  - Converted all `Write-Debug` calls to colon-form `-Message:'...'`.
  - Converted the internal `Get-CertificateRawDataSha256` call to `-Certificate:$Certificate`.
  - Changed the final handoff to type-on-left `[System.String]$Result = ...` and emitted bare `$Result`.
  - Added one WHY comment for ASCII PEM metadata escaping.

- `src/Private/Select-ExportableCertificate.ps1`
  - Converted both `Write-Debug` calls to colon-form `-Message:'...'`.
  - Converted internal cmdlet calls to colon-form, including `Get-CertificateRawDataSha256 -Certificate:$CandidateCertificate`.
  - Changed the final handoff to type-on-left `[System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Result = ...` and emitted bare `$Result`.
  - Added WHY comments for SHA-256 identity use and the validity-window filter.

- `src/Private/Test-CertificateStoreExporterWindows.ps1`
  - Converted both `Write-Debug` calls to colon-form `-Message:'...'`.
  - Changed the final handoff to type-on-left `[System.Boolean]$Result = ...` and emitted bare `$Result`.
  - Added a WHY comment for the platform seam used by tests.

## Behavior / Tests

- Behavior unchanged by intent: PEM output, selected/sorted certificate output, and Windows-platform boolean output remain equivalent.
- Tests were not modified.
- Fresh verification command:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result:
  - Build OK.
  - Analyze passed with 0 findings.
  - Pester passed: 76 passed, 0 failed.
  - Coverage: 95.93% / 90%.
  - Exit-code coverage passed for Success=0, Unhandled=1, BelowMinimumCertificateCount=2, NotWindows=3, StoreReadFailure=4, WriteFailure=5.
  - Smokes ran successfully: `BuildArtifacts.ps1`, `LiveStoreRead.ps1`.

## False Premise / Note

- Exact `ForEach-Object -Process:{ ... }` triggered `PSUseConsistentWhitespace` ("Use space before open brace") in the required build. I kept colon-form binding with no space after the colon by using parenthesized scriptblocks: `-Process:({ ... })`, which satisfies Analyzer and preserves behavior.

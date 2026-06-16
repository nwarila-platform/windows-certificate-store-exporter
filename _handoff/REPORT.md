# REPORT - Item C Classify Once

Status: complete
Branch: `codex-cq-classify-once`

## Changes

- `Select-ExportableCertificate` now returns one `[PSCustomObject]` instead of a bare certificate array.
- The new `Select` contract contains:
  - `Selected`: retained `[X509Certificate2[]]`, still sorted ascending by SHA-256 DER identity.
  - `SelectedThumbprint`: parallel `[String[]]` SHA-256 identities in the same order.
  - `ExcludedExpired`, `ExcludedNotYetValid`, `ExcludedDisallowed`, `ExcludedDuplicate`: counted in the same single pass that filters.
- `Export-CertificateStoreBundle` now calls `Select-ExportableCertificate` once and consumes that result.
- Deleted the export-side standalone exclusion-counting loop and the duplicate disallowed hash set.
- Export still hashes each requested store certificate once for source-store attribution and each Disallowed certificate once for the disallowed thumbprint array.
- Export uses `SelectedThumbprint` for PEM source lookup and passes those same identities into the result factory.
- `New-CertificateStoreExporterResult` now accepts optional `-CertificateThumbprint [String[]]`; when supplied, it uses those values directly and does not re-hash `-Certificate`.

## Behavior Proof

- Public `Export-CertificateStoreBundle` contract tests were not changed; their existing assertions still prove:
  - `Examined` remains the candidate certificate count.
  - `Excluded.Expired`, `Excluded.NotYetValid`, `Excluded.Disallowed`, and `Excluded.Duplicate` stay unchanged.
  - `Thumbprints` and their order stay unchanged.
  - Bundle bytes and bundle SHA-256 stay unchanged.
  - The six entry point exit codes remain mapped to `0..5`.
- Internal tests changed mechanically for the new `Select` return object and for the new result-factory precomputed thumbprint path.
- The new result-factory test mocks the hash helper and verifies `-CertificateThumbprint` does not invoke it.

## Verification

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All
```

Result: passed.

- Build OK.
- Analyze: 0 findings.
- Pester: 91 passed, 0 failed.
- Coverage: 95.98% (threshold 90%).
- Exit-code tests: all six mappings passed.
- Smoke stage passed: `BuildArtifacts.ps1`, `LiveStoreRead.ps1`.

No false premise found. No external behavior shifted intentionally or observed in the unchanged contract tests.

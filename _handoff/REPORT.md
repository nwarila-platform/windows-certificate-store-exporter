# REPORT - Single-hash candidate SHA-256 threading

## Completed

- Added optional `-Sha256` to `ConvertTo-PemCertificate`.
  - Non-empty caller values are used directly for the PEM `# SHA-256:` comment.
  - Empty or omitted values fall back to `Get-CertificateRawDataSha256`, preserving standalone callers.
  - The fallback is held in a per-item `EffectiveSha256` local so pipeline use cannot reuse a computed hash from a prior item.
- Added optional `-CertificateThumbprint` to `Select-ExportableCertificate`.
  - Aligned arrays are used as certificate identities for Disallowed subtraction, deduplication, and sorted output.
  - Count mismatches, including explicit null inputs, fall back to internal hashing.
- Updated `Export-CertificateStoreBundle`.
  - The existing read-loop hash is captured in a parallel `CandidateThumbprints` list.
  - The aligned list is passed to `Select-ExportableCertificate`.
  - The selected hash is passed to `ConvertTo-PemCertificate -Sha256`.

## Hashing Proof

- New focused tests prove the no-recompute paths:
  - `ConvertTo-PemCertificate` throws if `Get-CertificateRawDataSha256` is called when `-Sha256` is supplied.
  - `Select-ExportableCertificate` throws if hashing is called when aligned `-CertificateThumbprint` values are supplied.
  - `Export-CertificateStoreBundle` mocks hashing and proves exactly 8 calls: 7 candidates plus 1 Disallowed certificate. Each candidate object and the Disallowed object were called once.
- Disallowed certificate hashing remains separate, as requested.
- The bundle ASCII scan in `Write-CertificateBundle` was not changed.

## Byte-Identity Sanity

- Compared a `main` build from a temporary detached worktree against this branch for the same live store input.
- Whole PEM bytes: identical.
- Bundle SHA-256:
  - `main`: `0C02BF3283396F172570EF929ED746B079366BCAC2BECB277A3D7785CC646C3E`
  - branch: `0C02BF3283396F172570EF929ED746B079366BCAC2BECB277A3D7785CC646C3E`
- PEM `# SHA-256:` comment lines: identical, 41 lines.
- Byte count: 81560.

## Verification

- Fresh process command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: passed.
- Build: OK.
- Analyze: 0 findings.
- Pester: 92 passed, 0 failed.
- Coverage: 96.27% / 90%.
- Six subprocess exit codes proven:
  - Success: `0`
  - Unhandled: `1`
  - BelowMinimumCertificateCount: `2`
  - NotWindows: `3`
  - StoreReadFailure: `4`
  - WriteFailure: `5`
- Smoke scripts passed:
  - `BuildArtifacts.ps1`
  - `LiveStoreRead.ps1`

## Notes / False Premises

- No behavioral false premise found.
- Alignment edge case is explicit: `Select-ExportableCertificate` only trusts supplied thumbprints when `CertificateThumbprint.Count -eq Certificate.Count`; otherwise it computes internally as before.
- `_handoff` and `build` are ignored by the repo default-deny `.gitignore`; the signed commit contains the tracked implementation and tests, while this report is a local handoff artifact.

## Git

- Branch: `codex-single-hash`.
- Signed local commit: `Thread certificate SHA-256 through export`.
- Not pushed or merged.

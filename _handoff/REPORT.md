# REPORT - CLI minimum certificate floor

## Completed

- Changed the EntryPoint CLI parameter validation for `MinimumCertificateCount` from `ValidateRange(0, [System.Int32]::MaxValue)` to `ValidateRange(1, [System.Int32]::MaxValue)`.
- The default remains `1`, matching `Export-CertificateStoreBundle` and `Write-CertificateBundle`.
- Added a subprocess-style assertion that the built EntryPoint rejects `-MinimumCertificateCount 0` at parameter binding.

## Grep

- `rg -n "MinimumCertificateCount" tests`
- No smoke or success-path EntryPoint invocation passes `0`.
- The only test-side `0` is the new negative assertion: `Argument @('-MinimumCertificateCount', '0')`.
- `tests/Smoke/LiveStoreRead.ps1` passes `-MinimumCertificateCount 1`.

## Direct CLI Check

- Command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build\Export-CertificateStoreBundle.ps1 -Path .\build\minimum-floor-check.pem -MinimumCertificateCount 0 -WhatIf`
- Result: exit code `1`.
- Error: PowerShell parameter binding rejects `0` because it is below the minimum allowed range of `1`.

## Verification

- Fresh process command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: passed.
- Build: OK.
- Analyze: 0 findings.
- Pester: 93 passed, 0 failed.
- Coverage: 96.27% / 90%.
- Six subprocess exit codes still proven:
  - Success: `0`
  - Unhandled: `1`
  - BelowMinimumCertificateCount: `2`
  - NotWindows: `3`
  - StoreReadFailure: `4`
  - WriteFailure: `5`
- Smoke scripts passed:
  - `BuildArtifacts.ps1`
  - `LiveStoreRead.ps1`

## Git

- Branch: `codex-cli-min-floor`.
- Signed local commit prepared by Codex.
- Not pushed or merged.

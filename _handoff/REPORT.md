# REPORT - CLI minimum certificate floor

## Completed

- `src/EntryPoint.ps1` now validates `MinimumCertificateCount` with `ValidateRange(1, [System.Int32]::MaxValue)`.
- Default remains `1`, matching `Export-CertificateStoreBundle` and `Write-CertificateBundle`.
- Subprocess assertion exists: the built EntryPoint rejects `-MinimumCertificateCount 0` at parameter binding.

## Grep

- Ran `rg -n "MinimumCertificateCount" src tests`.
- No smoke or success-path EntryPoint invocation passes `0`.
- The only test-side `0` is the intentional negative assertion: `Argument @('-MinimumCertificateCount', '0')`.
- `tests/Smoke/LiveStoreRead.ps1` passes `-MinimumCertificateCount 1`.

## Direct CLI Check

- Command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build\Export-CertificateStoreBundle.ps1 -Path <temp>\cert-store-cli-min-floor-*.pem -MinimumCertificateCount 0 -WhatIf`
- Result: exit code `1`.
- Error: parameter binding rejects `0` because it is below the minimum allowed range of `1`.

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
- Implementation commit: `4ce7de6 Enforce CLI minimum certificate floor`.
- Commit signatures verified as good for `33955773+NWarila@users.noreply.github.com`.
- Worktree clean after verification.
- Not pushed or merged.

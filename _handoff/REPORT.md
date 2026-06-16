# REPORT - New-X509Store seam

## Completed

- Added `src/Private/New-X509Store.ps1` as the mockable private helper around
  `[System.Security.Cryptography.X509Certificates.X509Store]::new()`.
- Removed the hidden `[ScriptBlock] $StoreFactory` parameter, comment, and help
  entry from `src/Private/Get-StoreCertificate.ps1`.
- Updated `Get-StoreCertificate` to construct the store through
  `New-X509Store -Name:$StoreName -Location:$TypedStoreLocation`.
- Replaced the private test's `-StoreFactory` injection with
  `Mock -CommandName New-X509Store`.
- Added private coverage for the new helper creating the requested `X509Store`.

## Behavior Checks

- Real store-read behavior is unchanged: `Get-StoreCertificate` still opens the
  requested store with `ReadOnly -bor OpenExistingOnly`, reads certificates,
  wraps failures as `StoreReadFailure`, and disposes the store in `Finally`.
- Constructor/open failures still flow through the same `StoreReadFailure`
  catch path.
- The platform guard still throws `NotWindows` before touching a store.
- The six process exit codes remain unchanged and were proven by the built
  entrypoint tests:
  - success `0`
  - unhandled `1`
  - below minimum `2`
  - not Windows `3`
  - store read failure `4`
  - write failure `5`

## Verification

- Fresh process command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: passed.
- Build: OK.
- Analyze: 0 findings.
- Pester: 93 passed, 0 failed.
- Coverage: 96.23% / 90%.
- Smoke scripts: `BuildArtifacts.ps1` and `LiveStoreRead.ps1` both passed.

## Notes / False Premises

- No behavioral false premise found.
- Existing docs still contain `$StoreFactory` references, but the handoff
  constrained implementation to the listed source/test/report files, so docs
  were left unchanged.

## Git

- Branch: `codex-storefactory-helper`.
- Signed local commit created for the tracked implementation changes.
- Not pushed or merged.

# STEP 18 Report - Get-StoreCertificate canary normalization

## Scope
- Updated `src/Private/Get-StoreCertificate.ps1` only, plus this report.
- Created local branch `codex-cp-getstorecert2` from the current checkout because it did not exist locally; the workspace originally opened on `main`.

## Changes
- Normalized `Get-StoreCertificate` debug anchors and `New-ErrorRecord` calls to colon-form parameter binding.
- Converted `Try` / `Catch` / `Finally` to PascalCase.
- Added R1 preservation for `StoreReadFailure` with `-Exception:$PSItem.Exception`.
- Kept the `NotWindows` guard without an inner exception.
- Converted the final output to the SG-6 soft-return shape: typed `$Result` handoff, then bare `$Result`, then the `Exiting` debug anchor.
- Added intent comments for:
  - `ReadOnly -bor OpenExistingOnly` as least-privilege read-only behavior that never creates stores.
  - Dynamic `StoreLocation` enum lookup safety through `ValidateSet`.
  - `$StoreFactory` as the test-only injection path for store-open failures, not a CLI surface.
  - Disposing the store in `Finally` to always release the native store handle.

## Behavior Confirmation
- Store open flags are unchanged: `ReadOnly -bor OpenExistingOnly`.
- Returned certificate set/order remains the store certificate collection cast to `X509Certificate2[]`.
- Error mapping remains unchanged:
  - `NotWindows` -> `[ExporterExitCode]::NotWindows` / exit code 3.
  - `StoreReadFailure` -> `[ExporterExitCode]::StoreReadFailure` / exit code 4.
- The only behavioral addition is preserving the original store-read exception as the inner exception on the structured error record.

## Verification
- Ran fresh process verification:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result:
  - Build OK.
  - Analyze passed.
  - Pester: 76 passed, 0 failed.
  - Coverage: 95.94% / 90%.
  - Smoke scripts ran: `BuildArtifacts.ps1`, `LiveStoreRead.ps1`.

## False Premises / Notes
- `codex-cp-getstorecert2` was not present locally at start; it was created before changes.
- No tests were modified.
- No push or merge was performed.

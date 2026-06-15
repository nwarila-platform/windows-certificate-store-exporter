# STEP 16 REPORT - Export-CertificateStoreBundle SG-6 retrofit

## Scope
- Implemented the locked SG-6 soft-return pattern in `src/Public/Export-CertificateStoreBundle.ps1`.
- Added the flat-function `Write-Debug -Message:'[Export-CertificateStoreBundle] Entering'` first statement and `Write-Debug -Message:'[Export-CertificateStoreBundle] Exiting'` final statement.
- Declared `[PSCustomObject]$Private:Result = $Null` in the initialization block.
- Assigned the final `New-CertificateStoreExporterResult` output to `[PSCustomObject]$Result`, emitted bare `$Result`, then exited through the debug anchor.

## Colon-form coverage
- Converted the orchestrated calls in `Export-CertificateStoreBundle` to colon-form:
  `Get-StoreCertificate`, `Get-CertificateRawDataSha256`, `Select-ExportableCertificate`,
  `ConvertTo-PemCertificate`, `Write-CertificateBundle`, and `New-CertificateStoreExporterResult`.
- Kept existing explicit switch bindings for `-IncludeExpired:$IncludeExpired.IsPresent` and
  `-WriteManifest:$WriteManifest.IsPresent`.
- Used `-StoreName:'Disallowed'` for the literal Disallowed store read and parenthesized non-simple values.

## WHY comments
- Added intent-only comments explaining:
  - why Disallowed is read separately and subtracted;
  - why `$FirstSourceStoreByHash` tracks the first source store per identity;
  - why candidate filter counts are tracked for Excluded accounting;
  - why `$DefaultSourceStore` falls back to the first requested store.

## Behavior
- No `return` was added.
- Existing `continue` loop control remains unchanged.
- No catch/swallowing error handling was added; delegated fail-closed behavior remains intact.
- Result contract, selected certificate ordering/deduplication, status handling, exit-code mapping, and ShouldProcess delegation are unchanged by design and were verified by the existing test suite.

## Verification
- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: exit code 0.
- Build: OK.
- Analyze: passed, 0 issues reported.
- Pester: 76 passed, 0 failed, 0 skipped.
- Coverage: 95.67% / 90% required.
- Exit codes: all six built EntryPoint mappings still proven by tests: Success=0, Unhandled=1,
  BelowMinimumCertificateCount=2, NotWindows=3, StoreReadFailure=4, WriteFailure=5.
- Smoke: `BuildArtifacts.ps1` and `LiveStoreRead.ps1` both ran in the Smoke task.

## False Premises / Notes
- None found.

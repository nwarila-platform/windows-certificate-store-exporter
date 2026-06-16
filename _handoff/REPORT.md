# REPORT - Security hardening

## Completed

- Fix 1: raised `MinimumCertificateCount` validation from `0..Int32.MaxValue`
  to `1..Int32.MaxValue` in:
  - `src/Public/Export-CertificateStoreBundle.ps1`
  - `src/Private/Write-CertificateBundle.ps1`
- Fix 2: hardened bundle and manifest temp writes in
  `src/Private/Write-CertificateBundle.ps1` to use
  `[System.IO.FileStream]` with `FileMode.CreateNew`, writing the already
  computed `$BundleBytes` and `$ManifestBytes`.
- Fix 3: resolved `-Path` with provider information and fail closed when the
  provider is not `FileSystem`, using a new SG-8 message-table entry:
  `Write-CertificateBundle.NonFileSystemPath`.
- Added a private Pester test that verifies non-FileSystem provider paths throw
  `WriteFailure,New-ErrorRecord` before writing.
- Updated the live smoke WhatIf run to pass `-MinimumCertificateCount 1`
  instead of `0`.

## Behavior Checks

- Atomic write flow is unchanged apart from the temp-file creation mode and
  byte source:
  - same-directory temp paths remain
  - first writes still use `File.Move`
  - replacements still use `File.Replace`
  - backup deletion remains
  - catch cleanup still removes leftover temp and backup files
- Bundle and manifest temp bytes are now byte-identical to the bytes used for
  hashing.
- Status values and behavior remain unchanged: `Unchanged`, `WhatIf`, and
  `Written`.
- Result contract remains unchanged.
- The six exit codes remain unchanged and were proven by the entrypoint tests:
  success `0`, unhandled `1`, below minimum `2`, not Windows `3`, store read
  failure `4`, write failure `5`.

## Verification

- Fresh process command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: passed.
- Build: OK.
- Analyze: 0 findings.
- Pester: 92 passed, 0 failed.
- Coverage: 96.19% / 90%.
- Smoke scripts: `BuildArtifacts.ps1` and `LiveStoreRead.ps1` both passed.

## Notes / False Premises

- No false premise found for `FileMode.CreateNew`; it does not change the
  subsequent `Replace`/`Move` semantics.
- `src/EntryPoint.ps1` still has its previous script-parameter
  `ValidateRange(0, ...)` because the handoff constrained the validation edit
  to the public exporter and private writer. Passing `0` through the release
  script still fails closed at `Export-CertificateStoreBundle` before any write.

## Git

- Branch: `codex-sec-hardening`.
- This report is included with the signed local commit for the implementation.
- Not pushed or merged.

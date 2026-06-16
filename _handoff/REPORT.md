# REPORT - Message Table

## Implemented

- Added the build-generated message table initializer before `#region Private Functions` in `build.ps1`:
  `[System.Collections.Hashtable]$Script:Message = @{}`
- Confirmed the initializer appears in both generated artifacts:
  `build/Export-CertificateStoreBundle.Functions.ps1` and `build/Export-CertificateStoreBundle.ps1`.
- Added file-scope `# Message(s)` fragments after `#Requires` and before `Function` in:
  - `src/Private/Get-CertificateRawDataSha256.ps1`
    - `Get-CertificateRawDataSha256.NoRawData`
    - `Get-CertificateRawDataSha256.HashFailure`
  - `src/Private/Get-StoreCertificate.ps1`
    - `Get-StoreCertificate.NotWindows`
    - `Get-StoreCertificate.ReadFailure`
  - `src/Private/Write-CertificateBundle.ps1`
    - `Write-CertificateBundle.BelowMinimum`
    - `Write-CertificateBundle.NonAscii`
    - `Write-CertificateBundle.WriteFailure`
- Retrofitted the user-facing `New-ErrorRecord -Message` call sites to use `$Script:Message[...]`.
- Removed `$FailureMessage` declarations and assignments from:
  - `Get-StoreCertificate`
  - `Write-CertificateBundle`
- Left `Write-Debug` strings unchanged.

## Message Fidelity

- Messages remain byte-identical to the previous literals.
- The store read message uses a plain single-quoted hashtable value:
  `Failed to read Windows certificate store {0}\{1}: {2}`
- Runtime backslash check passed:
  `Failed to read Windows certificate store LocalMachine\Root: Synthetic store-open failure.`

## Verification

- Ran fresh process:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result:
  - Clean OK
  - Build OK
  - Analyze passed with 0 findings
  - Pester passed: 91 passed, 0 failed
  - Coverage: 96.06% / 90%
  - Six exit codes proven by tests:
    - Success -> 0
    - Unhandled -> 1
    - BelowMinimumCertificateCount -> 2
    - NotWindows -> 3
    - StoreReadFailure -> 4
    - WriteFailure -> 5
  - Smoke: `BuildArtifacts.ps1` passed
  - Smoke: `LiveStoreRead.ps1` passed

## False Premises

- None found.

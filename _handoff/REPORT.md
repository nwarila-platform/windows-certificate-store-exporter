# Report - STEP 21 Canonical Keyword Casing

## Implemented

- Added `Measure-CanonicalKeywordCasing` to `analyzers/HouseRules.psm1`.
- Enabled the rule in `PSScriptAnalyzerSettings.psd1`.
- Added Pester coverage in `tests/HouseRules.Tests.ps1`.
- Retrofitted analyzed PowerShell files to canonical keyword token casing.
- Included the pre-existing canary change in `src/Private/Get-CertificateRawDataSha256.ps1`.

## Canonical Set

The rule tokenizes the root script text with:

`[System.Management.Automation.Language.Parser]::ParseInput($ScriptBlockAst.Extent.Text, [ref]$Tokens, [ref]$ParseErrors)`

It only evaluates tokens whose `TokenKind` has `TokenFlags.Keyword`, then checks exact casing against:

`Assembly Base Begin Break Catch Class Command Configuration Continue Data Define Do DynamicKeyword DynamicParam Else ElseIf End Enum Exit Filter Finally For ForEach From Function Hidden If In InlineScript Interface Module Namespace Param Parallel Private Process Public Return Sequence Static Switch Throw Trap Try Type Until Using Var While Workflow`

This leaves operators such as `-in` and `-and`, strings, comments, identifiers, cmdlets, variables, type names, and member names untouched.

## Retrofit Counts

Parser-token replacements by file:

- `build.ps1`: 51
- `analyzers/HouseRules.psm1`: 337
- `src/EntryPoint.ps1`: 12
- `src/Private/ConvertTo-PemCertificate.ps1`: 19
- `src/Private/ExporterExitCode.ps1`: 1
- `src/Private/Get-CertificateRawDataSha256.ps1`: 0 new parser replacements; staged the owner canary `function` to `Function` change already present in the worktree
- `src/Private/Get-StoreCertificate.ps1`: 5
- `src/Private/New-CertificateStoreExporterResult.ps1`: 2
- `src/Private/New-ErrorRecord.ps1`: 5
- `src/Private/Resolve-ExitCode.ps1`: 2
- `src/Private/Select-ExportableCertificate.ps1`: 13
- `src/Private/Test-CertificateStoreExporterWindows.ps1`: 2
- `src/Private/Write-CertificateBundle.ps1`: 26
- `src/Public/Export-CertificateStoreBundle.ps1`: 28

## Proof

Sanity probe, not committed:

`powershell -NoProfile -ExecutionPolicy Bypass -Command "<lowercase if probe>"`

Result:

`Measure-CanonicalKeywordCasing Line 1 Column 1 Keyword 'if' must be canonical casing 'If'.`

`UniqueCanonicalDiagnostics=1`

Codebase analysis:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Build OK.
- Analyze passed with 0 findings across the release artifact, functions artifact, `analyzers/HouseRules.psm1`, and `build.ps1`.
- Pester passed: 87 passed, 0 failed.
- Coverage passed: 95.93% / 90%.
- Six entrypoint exit-code tests passed: Success, Unhandled, BelowMinimumCertificateCount, NotWindows, StoreReadFailure, WriteFailure.
- Smoke passed: `BuildArtifacts.ps1` and `LiveStoreRead.ps1`.

## Notes

- The worktree started on `main`, not `codex-kw-casing`; I created and switched to `codex-kw-casing` before implementation.
- No keyword/operator false positives were observed. The new test suite includes lower-case `-in` and `-and` operator coverage.

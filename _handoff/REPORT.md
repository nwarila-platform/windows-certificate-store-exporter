# SG-7 Implementation Report

Branch: `codex-sg7-param`

## Implemented

- Added `Measure-ExplicitParameterAttribute` in `analyzers/HouseRules.psm1`.
- Enabled it in `PSScriptAnalyzerSettings.psd1`.
- Added SG-7 tests in `tests/HouseRules.Tests.ps1`:
  - bare `[Parameter()]` is flagged for missing explicit options;
  - `Position` is flagged and the diagnostic says it re-enables positional binding under `CmdletBinding(PositionalBinding = $False)`;
  - the complete five-option form passes.

## Rule Surface

Required options:

- `DontShow`
- `Mandatory`
- `ParameterSetName`
- `ValueFromPipeline`
- `ValueFromPipelineByPropertyName`

Forbidden options:

- `HelpMessage`
- `Position`
- `ValueFromRemainingArguments`

The rule checks the root script `Param()` block and each function's own top-level `Param()` block. It does not walk arbitrary nested scriptblock params.

## Retrofit Counts

- `src/**` including `src/EntryPoint.ps1`: 50 `[Parameter(...)]` attributes are now SG-7 explicit.
- 49 source attributes were expanded from compact form; `Get-CertificateRawDataSha256` already had the five-option form and was preserved.
- `build.ps1` plus `analyzers/HouseRules.psm1`: 58 existing support-file attributes were also expanded because the build self-analyzes those files.
- 3 new analyzer helper/rule parameters were added with the explicit form.

Behavior-preserving values:

- `ValueFromPipeline = $True` remains only on `ConvertTo-PemCertificate` and `Get-CertificateRawDataSha256` certificate parameters.
- `DontShow = $True` remains only on the `Get-StoreCertificate` `$StoreFactory` test seam.
- `ValueFromPipelineByPropertyName = $False` everywhere in `src`.
- `ParameterSetName = 'default'` everywhere.

StoreFactory handling: the nested default scriptblock params were retrofitted too, even though the rule is scoped not to require nested scriptblock traversal.

## Verification

- Probe: bare `[Parameter()]` fires for all five missing SG-7 options.
- Probe: `Position` fires with the positional-binding diagnostic.
- Probe: complete five-option form returns 0 diagnostics.
- Focused codebase check: `Measure-ExplicitParameterAttribute` returned `0` diagnostics across the built script, functions bundle, analyzer module, and `build.ps1`.
- Fresh gate: `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
  - Build OK.
  - Analyze passed.
  - Pester: 90 passed, 0 failed.
  - Coverage: 95.93% (target 90%).
  - Exit-code tests proved all six codes: 0, 1, 2, 3, 4, 5.
  - Smokes ran: `BuildArtifacts.ps1`, `LiveStoreRead.ps1`.

## Notes

- False premise/tooling wrinkle: PowerShell binding treats explicit default `Parameter` values as no-ops, but the built-in `PSUseProcessBlockForPipelineCommand` rule treats the presence of `ValueFromPipeline = $False` as pipeline input. SG-7 requires that explicit false value, so `PSUseProcessBlockForPipelineCommand` is now excluded and the house pipeline-shape rules remain authoritative.

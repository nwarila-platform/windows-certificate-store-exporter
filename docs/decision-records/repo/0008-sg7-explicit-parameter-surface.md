# ADR-repo/0008: Adopt SG-7 Explicit Parameter Surface

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-16                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | Microsoft Learn advanced-function parameter docs; Microsoft Learn CmdletBinding docs; Microsoft Learn ParameterAttribute API docs; deep-research notes on positional binding and pipeline property binding. |
| Informed       | Maintainers and reviewers of the script.                     |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Adopt SG-7: every `[Parameter(...)]` attribute declares the same explicit five-option
surface, ordered alphabetically: `DontShow`, `Mandatory`, `ParameterSetName`,
`ValueFromPipeline`, and `ValueFromPipelineByPropertyName`. The explicit defaults are
an auditability preference, not a PowerShell idiom. The forbid-list is stricter:
`Position`, `HelpMessage`, and `ValueFromRemainingArguments` stay out of house
parameters because they either re-open binding hazards or add unused/redundant
surface.

## Context and Problem Statement

SG-4 made the advanced-function `[CmdletBinding(...)]` surface explicit. SG-5 then
made attribute and parameter ordering deterministic. Parameters still had an
incomplete documentation story: the analyzer now requires a complete `[Parameter]`
surface, but the style guide and ADR set did not yet explain why the house prefers
those otherwise default-looking options or why some documented `Parameter` arguments
are forbidden.

## Decision Drivers

1. **Auditability** — reviewers should see every binding-relevant parameter choice
   without remembering PowerShell defaults.
2. **Behavior preservation** — explicitly stated defaults must not change the
   current public CLI contract.
3. **Named-only correctness** — SG-4's `PositionalBinding = $False` must not be
   weakened by per-parameter `Position` declarations.
4. **Pipeline-binding precision** — property-name binding is useful only when a
   specific parameter intentionally consumes a matching property or alias.
5. **Help-source discipline** — comment-based `.PARAMETER` help remains the user
   help source; parameter attributes do not carry parallel help text.

## Considered Options

1. **SG-7 explicit five-option parameter surface plus forbid-list** (chosen).
2. **Minimal idiomatic `[Parameter()]` declarations, setting only non-default
   options**.
3. **Allow all Microsoft-documented `Parameter` arguments when explicitly valued**.

## Decision Outcome

Chosen: option 1.

Every parameter declares one `[Parameter(...)]` attribute with these five named
arguments, in alphabetical order:

- `DontShow`
- `Mandatory`
- `ParameterSetName`
- `ValueFromPipeline`
- `ValueFromPipelineByPropertyName`

Values remain per-parameter. `Mandatory`, `ValueFromPipeline`, and
`ValueFromPipelineByPropertyName` are `$True` only where the parameter really has
that binding behavior. `DontShow` is `$False` except for the hidden `$StoreFactory`
test seam in `Get-StoreCertificate`, where `DontShow = $True` keeps the test-only
factory out of normal completion/IntelliSense surface. `ParameterSetName` is
`'default'` for this repository's current single-set functions and scripts.

`Position`, `HelpMessage`, and `ValueFromRemainingArguments` are forbidden.

### Deep-research findings

- Microsoft documents that Boolean `Parameter` arguments default to false when
  omitted, and the `ParameterAttribute` API documents false/default behavior for
  `Mandatory`, `ValueFromPipeline`, `ValueFromPipelineByPropertyName`, and
  `ValueFromRemainingArguments`. Therefore, explicitly writing `$False` for the
  house five-option surface is binding-equivalent to omitting those false values.
- `ParameterSetName` omitted means all parameter sets. In the current single-set
  house model, explicitly declaring `ParameterSetName = 'default'` on every
  parameter makes the implicit set visible without introducing an alternate route.
- `Position` is objectively dangerous here. Microsoft documents that
  `PositionalBinding = $False` disables positional binding by default, but a
  parameter-level `Position` takes precedence. Declaring `Position` would re-enable
  positional binding for that parameter, violating SG-4's named-only contract.
- `ValueFromPipelineByPropertyName` binds from an incoming object's property with the
  same name or alias as the parameter. That makes it a precise per-parameter
  decision. Blanket `$True` can silently bind coincidental properties and create
  hard-to-see pipeline bugs.
- `HelpMessage` is aimed at the mandatory-parameter prompt: users type `!?` to see
  it. This repo already owns help through comment-based `.PARAMETER` blocks, so
  `HelpMessage` would be duplicate help text with a narrow prompt-only benefit.
- `ValueFromRemainingArguments` captures command-line values not assigned to other
  parameters. This exporter has no catch-all argument contract, so the option is
  unused surface.

### Honest framing

The explicit five-option surface is a house auditability preference. It is not the
PowerShell community idiom; idiomatic PowerShell usually omits default-valued
attribute arguments. The forbid-list is stronger than preference: `Position` is a
correctness constraint under SG-4, `ValueFromPipelineByPropertyName` must stay
per-parameter to avoid silent property binding, and the remaining forbidden options
avoid redundant or unused surface.

### Consequences

- **Positive:** every parameter's binding surface is reviewable in the diff.
- **Positive:** SG-4 named-only binding stays intact because parameter-level
  `Position` cannot override it.
- **Positive:** property-name pipeline binding must be justified parameter by
  parameter.
- **Negative:** declarations are more verbose than idiomatic PowerShell.
- **Negative:** default-valued false options add visual noise; the project accepts
  that cost for auditability.

## Enforcement

The decision is enforced by two custom house rules:

- `Measure-ExplicitParameterAttribute` flags parameters without `[Parameter(...)]`,
  missing SG-7 options, and forbidden `Position`, `HelpMessage`, or
  `ValueFromRemainingArguments` declarations.
- `Measure-CanonicalAttributeOrder` keeps the five SG-7 options in SG-5 alphabetical
  order.

No code, analyzer, or settings change is part of this ADR; the analyzer already
exists in `PSScriptAnalyzerSettings.psd1`.

## More Information

- Style guide: [docs/STYLE-GUIDE.md](../../STYLE-GUIDE.md#sg-7--explicit-parameter-surface-mechanical--analyzer-enforced)
- Microsoft Learn: [`about_Functions_Advanced_Parameters`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.5)
- Microsoft Learn: [`about_Functions_CmdletBindingAttribute` `PositionalBinding`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-7.5#positionalbinding)
- Microsoft Learn API: [`System.Management.Automation.ParameterAttribute`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.parameterattribute?view=powershellsdk-7.4.0)

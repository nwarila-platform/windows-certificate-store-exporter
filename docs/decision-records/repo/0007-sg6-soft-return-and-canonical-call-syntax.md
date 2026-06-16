# ADR-repo/0007: Adopt SG-6 Soft Return and Canonical Call Syntax

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-15                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | TargetState soft-return idiom; deep-research notes on PowerShell type constraints and colon-form binding; PSScriptAnalyzer behavior. |
| Informed       | Maintainers and reviewers of the script.                     |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Adopt SG-6: output-producing functions compute into domain-named variables, assign
the final value into a typed `$Private:Result`, emit bare `$Result`, never use
`Return`, and leave `Write-Debug '... Exiting ...'` as the last executed success-path
statement. Also adopt colon-form command parameters and PascalCase PowerShell
keywords as house conventions. The syntax choices are non-idiomatic on purpose:
they match TargetState style and make audit review more explicit, not because they
are the community default.

## Context and Problem Statement

The exporter has converged on the TargetState soft-return idiom. That idiom keeps
the output value in a meaningful domain variable until the end of the function, then
hands it to a typed `$Result` immediately before emitting it. The trailing
`Write-Debug '... Exiting ...'` line becomes a reliable breakpoint where every local,
including the result, is still in scope.

The style guide did not yet record the now-enforced convention, and it also still
left two syntax choices under-described: command calls using colon-form named
parameters, and PascalCase PowerShell keywords.

## Decision Drivers

1. **Debuggability** — every function has a stable Exiting breakpoint on the
   success path.
2. **Explicit output shape** — `[T]$Result = ...` near the soft return constrains
   the emitted type where a reviewer expects to see it.
3. **Single-exit control flow** — no early `Return` bypasses the breakpoint anchor.
4. **TargetState fidelity** — portfolio code should read consistently across
   projects that inherit the same baseline.
5. **Auditability over idiom** — reviewers see named binding and canonical tokens
   instead of relying on implicit community conventions.

## Considered Options

1. **SG-6 soft return + colon-form parameters + PascalCase keywords** (chosen).
2. **Keep only the soft-return rule and leave call/keyword casing idiomatic**.
3. **Use conventional lowercase keywords and space-form parameters everywhere**.

## Decision Outcome

Chosen: option 1.

- **Soft return:** every output-producing function computes into domain-named
  variables, assigns the final value to a typed `$Result`, emits bare `$Result`, and
  reaches the trailing `Write-Debug '... Exiting ...'` anchor on every
  non-terminating path.
- **No hard returns:** `Return` is prohibited inside functions, including guard
  returns. Guard flow is written as `If`/`Else` so the Exiting anchor remains
  meaningful. Loop-local `Continue`/`Break` are still allowed.
- **Flat and pipeline shapes:** flat functions have Entering and Exiting anchors in
  the body. Pipeline functions put block-specific Entering/Exiting anchors in
  `Begin`/`Process`/`End`; `Process` resets Begin-declared locals immediately after
  its Entering anchor.
- **Conditional output:** functions that intentionally emit nothing on some paths
  emit `$Result` only on producing branches, while still flowing to the Exiting
  anchor on all non-terminating paths.
- **Exemptions:** throw-only helpers and type definitions do not soft-return.
  Terminating-error paths are outside the success-path anchor requirement.
- **Colon-form parameters:** command calls use `-Name:Value` with no space after the
  colon. Expression values are parenthesized, e.g.
  `-ErrorId:([ExporterExitCode]::Unhandled)`, to avoid greedy binding. Simple
  variables, literals, and scriptblocks are self-delimiting and need no parentheses.
- **PascalCase keywords:** tokenized PowerShell keywords use the house canonical
  spelling: `Function`, `Param`, `Begin`, `Process`, `End`, `If`, `ElseIf`,
  `Else`, `ForEach`, `Try`, `Catch`, `Finally`, and peers.

### Honest framing

PascalCase keywords and colon-form command parameters are **non-idiomatic** house
preferences. Community examples and PSScriptAnalyzer's built-in
`PSUseCorrectCasing` default to lowercase keywords. Colon-form parameters also have
a real greedy-binding hazard; the house dropped them previously for that reason and
now re-adopts them only with the parenthesize-expression guard.

The deep-research findings are part of the rationale:

- Type-on-left assignment (`[T]$x = ...`) constrains the assigned value and makes the
  final output contract visible at the soft-return handoff.
- Colon-form named parameters can greedily bind expression text unless expression
  values are parenthesized.

These conventions are chosen for auditability and TargetState fidelity. They should
not be described as the PowerShell community default.

### Consequences

- **Positive:** the end-of-function breakpoint is reliable, and the result remains
  inspectable in a domain-named variable until the typed handoff.
- **Positive:** output contracts become easier to audit because the final typed
  assignment sits directly above the pipeline emission.
- **Positive:** keyword and named-block spelling are deterministic across the
  portfolio.
- **Negative:** code is less idiomatic for PowerShell authors accustomed to
  lowercase keywords and space-form parameters.
- **Negative:** colon-form remains a review concern because the safe subset is not
  fully machine-enforced.

## Enforcement

The decision is enforced by three custom house rules:

- `Measure-SoftReturn` flags `Return` inside functions and missing trailing
  `Write-Debug '... Exiting ...'` anchors where mechanically decidable.
- `Measure-CanonicalNamedBlock` flags non-canonical named block spelling and
  non-cuddled `} Process {` / `} End {` transitions.
- `Measure-CanonicalKeywordCasing` flags PowerShell keywords that do not use the
  house PascalCase spelling.

`PSUseCorrectCasing` is disabled because it conflicts with the house PascalCase
keyword convention. Colon-form parameter use is review-backed.

## More Information

- Style guide: [docs/STYLE-GUIDE.md](../../STYLE-GUIDE.md#sg-6--soft-return-and-canonical-token-surface-mechanical-where-decidable--analyzer-enforced)
- Builds on the source/build shape in
  [repo/0006](0006-script-structure-and-test-seam.md).

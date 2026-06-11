# ADR-repo/0001: Consume the powershell-template Guardrails as a Single-Script Project

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | `NWarila/powershell-template`; PSGallery PSScriptAnalyzer ruleset; Pester v5 runner. |
| Informed       | Consumers and operators of the certificate-store exporter.   |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

This repository consumes the `NWarila/powershell-template` repo guardrails —
Pester v5, the PSGallery-aligned PSScriptAnalyzer ruleset, SHA-pinned GitHub
Actions, Renovate, and the Diataxis documentation structure — while remaining a
single PowerShell **script** (`windows-certificate-store-exporter.ps1`), not a
module. Module layout (`src/Public` + `Private`, manifest exports) is
intentionally not adopted.

## Context and Problem Statement

The project needs a maintainable PowerShell deliverable with CI, tests, and
linting, but it has exactly one job — produce a CA bundle — and does not export a
reusable command surface. Adopting full module structure (a manifest, a root
module, `Public/`+`Private/` folders, export contracts) would add ceremony with
no consumer benefit, while skipping the template guardrails entirely would leave
the repo without the portfolio's CI, lint, dependency, and documentation
baseline.

## Decision Drivers

1. **Green CI out of the box.** A new clone must pass lint and tests with no
   edits.
2. **Portfolio consistency.** Use the same test runner, analyzer ruleset, pinned
   actions, Renovate config, and documentation framework as sibling repos.
3. **Right-sized structure.** A single-purpose script should not carry module
   overhead until a reusable surface actually exists.

## Considered Options

1. **Consume the template guardrails as a single script** (chosen).
2. **Full module layout** — `src/<ModuleName>/` with `Public/`+`Private/` and
   manifest exports, per the inherited
   [template/0001](../template/0001-module-layout.md).
3. **Bare script** — no template guardrails, no shared CI/lint/docs baseline.

## Decision Outcome

Chosen: option 1.

- Runtime code stays in `windows-certificate-store-exporter.ps1`.
- CI runs Pester v5 and PSScriptAnalyzer (PSGallery settings); GitHub Actions are
  SHA-pinned; Renovate manages workflow dependencies; documentation follows
  Diataxis.
- No module manifest, root module, or `Public/`+`Private/` split is introduced.

### Consequences

- **Positive:** template-aligned checks and documentation without module
  ceremony; the public surface is the script's parameters, reviewed directly.
- **Negative:** if the tool later grows a reusable command surface, a migration
  to module layout (and a superseding ADR) will be required.

## More Information

- **Divergence:** this repo deliberately departs from the inherited
  [template/0001](../template/0001-module-layout.md) (module `Public/`+`Private/`
  layout) by staying a single script. That template ADR governs module consumers
  of `NWarila/powershell-template`; this consumer takes only the CI, lint,
  Renovate, and documentation guardrails.
- Reference: [docs/reference/module-structure.md](../../reference/module-structure.md)
- Org baseline: [org/0001](../org/0001-use-architecture-decision-records.md)

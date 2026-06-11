# ADR-repo/0001: Assemble a Single Release Script from Structured Source

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                      |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | `NWarila/powershell-template`; `nwarila-platform/start-uninstaller`; Pester v5; PSScriptAnalyzer. |
| Informed       | Consumers and operators of the certificate-store exporter.   |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

This repository consumes the `NWarila/powershell-template` guardrails while
authoring exporter source under `src/` and assembling one release script with
`build.ps1`. The shipped artifact is `Export-CertificateStoreBundle.ps1`; the
project is still not a PowerShell module.

## Context and Problem Statement

The exporter needs a maintainable PowerShell deliverable with CI, tests, linting,
and documentation. A flat hand-written script kept the initial scaffold small,
but it would make helper testing, coverage, and future release assembly
needlessly brittle as the certificate-store behavior grows.

At the same time, consumers need one portable `.ps1` artifact rather than a
module manifest and import workflow.

## Decision Drivers

1. **Single-file distribution.** Release consumers download and run one script.
2. **Maintainable source.** Helpers live in focused `Private/` and `Public/`
   files instead of one long hand-edited script body.
3. **Coverage on executed code.** Tests dot-source the same merged functions file
   that Pester instruments for coverage.
4. **Portfolio consistency.** Keep the same pinned CI, analyzer, Renovate, and
   Diataxis guardrails as sibling repos.

## Considered Options

1. **Structured source assembled into one release script** (chosen).
2. **Flat hand-written single script**.
3. **Full PowerShell module layout** with manifest exports.

## Decision Outcome

Chosen: option 1.

- Source lives under `src/EntryPoint.ps1`, `src/Private/*.ps1`, and
  `src/Public/*.ps1`.
- `build.ps1 -Task Build` emits `build/Export-CertificateStoreBundle.ps1` for
  release and `build/Export-CertificateStoreBundle.Functions.ps1` for tests.
- Pester tests dot-source the functions-only artifact and enforce coverage
  against that same merged file.
- The project does not publish a module manifest or require `Import-Module`.

### Consequences

- **Positive:** source stays reviewable while releases remain a single script;
  helper tests cover the same merged code that will ship.
- **Negative:** build output must be regenerated before tests and releases; the
  `build/` directory is intentionally ignored and not edited by hand.

## More Information

- Build/test structure: [docs/reference/module-structure.md](../../reference/module-structure.md)
- Script structure and seam: [repo/0006](0006-script-structure-and-test-seam.md)
- Org baseline: [org/0001](../org/0001-use-architecture-decision-records.md)

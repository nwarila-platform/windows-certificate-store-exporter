# ADR-repo/0006: Use the Build Model and Mocked Read Seam

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Proposed                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                      |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | `nwarila-platform/targetstate` style; `nwarila-platform/start-uninstaller`; Pester v5; PSScriptAnalyzer. |
| Informed       | Maintainers and reviewers of the script.                     |
| Reversibility  | Medium                                                       |
| Review-by      | 2026-07-11                                                   |

## TL;DR

Adopt the start-uninstaller build model: author `EntryPoint`, `Public`, and
`Private` source files under `src/`, then assemble a single release script and a
functions-only test artifact with `build.ps1`. Keep the Windows certificate read
behind a mocked `Get-StoreCertificate` seam so Linux CI can exercise downstream
logic.

## Context and Problem Statement

The exporter must align with the targetstate PowerShell style and still ship as a
single script. CI runs on Linux PowerShell 7 and Windows PowerShell 5.1 with a
90% coverage gate, while the live `LocalMachine` certificate stores are Windows
runtime resources.

A single inline `Functions` region would make helper ownership and code coverage
harder to maintain. A module layout would add consumer ceremony that the project
does not need.

## Decision Drivers

1. **Strict style alignment** with the portfolio PowerShell baseline.
2. **Single-script release** without a module manifest.
3. **Mockable certificate-store I/O** so Linux CI can cover pure logic.
4. **Coverage target matches executed code** by instrumenting the merged
   functions-only artifact.
5. **PowerShell 5.1 baseline** with a Windows runtime guard before live store I/O.

## Considered Options

1. **Build-model source split + mocked read seam** (chosen).
2. **One hand-written script with inline helpers**.
3. **Full PowerShell module** with manifest exports.

## Decision Outcome

Chosen: option 1.

- **Entry point:** `src/EntryPoint.ps1` contains the script param block,
  ScriptTemplate-style initialization, error trap, execution region, and final
  exit.
- **Private helpers:** `src/Private/*.ps1` contains the internal helper functions.
- **Public function:** `src/Public/Export-CertificateStoreBundle.ps1` contains the
  orchestrator function.
- **Build artifacts:** `build.ps1` emits:
  - `build/Export-CertificateStoreBundle.ps1` for release.
  - `build/Export-CertificateStoreBundle.Functions.ps1` for dot-sourced tests and
    Pester coverage instrumentation.
- **Analyzer:** `build.ps1 -Task Analyze` lints the merged artifacts and
  `build.ps1` with `PSScriptAnalyzerSettings.psd1`.
- **Tests:** `build.ps1 -Task Test` runs smoke scripts, Pester tests, and a 90%
  coverage gate against the functions-only artifact.

### Proposed internal decomposition

`Get-StoreCertificate` (seam) -> `Select-ExportableCertificate` (validity,
`Disallowed` subtraction, de-dup) -> `ConvertTo-PemCertificate` (PEM block and
header) -> `Write-CertificateBundle` (sort, atomic, idempotent,
`ShouldProcess`) -> `New-ErrorRecord` (house error-record helper).

### Consequences

- **Positive:** reviewers can inspect small source files while CI verifies the
  exact merged code path tests execute.
- **Negative:** build/test tasks become mandatory before release because generated
  artifacts are not tracked.

## More Information

- Realizes the selection, format, write, and summary decisions in
  [repo/0002](0002-certificate-source-and-selection.md) through
  [repo/0005](0005-summary-and-manifest-output.md).
- Source/build overview: [docs/reference/module-structure.md](../../reference/module-structure.md)

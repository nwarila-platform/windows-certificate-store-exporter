# ADR-repo/0006: Structure the Script with the House Scaffold and a Mocked Read Seam

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Proposed                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | `nwarila-platform/targetstate` style; `start-uninstaller/ref/ScriptTemplate.ps1`; Pester v5 on `ubuntu-latest`. |
| Informed       | Maintainers and reviewers of the script.                     |
| Reversibility  | Medium                                                       |
| Review-by      | 2026-07-11                                                   |

## TL;DR

Adopt the full house `ScriptTemplate.ps1` scaffold (7-digit `LogLevel` / 3-digit
`DebugLevel`, script-level `Trap`, `#region Initialization/Functions/Execution/
Cleanup`, `$ENV` context, `ExitCode`, `ReadOnly` constants) and the `targetstate`
function idiom for helpers. Isolate the Windows-only certificate read behind one
internal `Get-StoreCertificate` seam so Pester can mock it and exercise all
downstream logic on the Linux CI runner.

## Context and Problem Statement

The directive is to align strictly with the `targetstate` PowerShell style and to
keep the existing CI guarantees. CI runs Pester v5 on `ubuntu-latest` with an
80% line-coverage gate, while the tool runs only on Windows and reads
`LocalMachine` stores that do not exist on Linux. The structure must reconcile a
Windows-only runtime with a Linux test environment and match the house scaffold
and function idiom.

## Decision Drivers

1. **Strict style alignment** with the portfolio's PowerShell baseline.
2. **Unattended-run operability** (stream control, exit codes, last-resort trap).
3. **Reachable 80% coverage** on a Linux runner without weakening the gate.
4. **PowerShell 5.1 baseline** with a Windows runtime guard.

## Considered Options

1. **Full ScriptTemplate scaffold + targetstate function idiom + mocked read
   seam** (chosen).
2. **Function idiom only** — lighter, drops `LogLevel`/`DebugLevel`/`Trap`/region
   machinery.
3. **`Cert:` PSDrive or `certutil`** read — harder to mock / not unit-testable on
   Linux, threatening the coverage gate.

## Decision Outcome

Chosen: option 1.

- **Full ScriptTemplate scaffold:** `LogLevel`/`DebugLevel` stream-preference
  params, script-level `Trap`, region structure, `$ENV` context, `ExitCode`
  convention, `New-Variable … -Option ReadOnly` constants.
- **targetstate function idiom for helpers:** `Begin/Process/End` with
  `Write-Debug` markers, `New/Set/Clear/Remove-Variable` discipline, colon-named
  params, explicit `[System.Type]` casts, soft-returns, the `ThrowError` helper.
- **Injectable read seam:** `Get-StoreCertificate` enumerates via the .NET
  `X509Store` API and returns `X509Certificate2` objects; all selection, encoding,
  ordering, writing, and summary/manifest logic is pure and platform-agnostic.
- **Coverage strategy:** Pester mocks `Get-StoreCertificate` with synthetic
  `X509Certificate2` fixtures so the filter/format/write/idempotency/fail-closed/
  manifest paths run on Linux CI.
- **Runtime:** `#Requires -Version 5.1`; assert a Windows host before the read
  seam touches `LocalMachine`; no PS 7+ features unless version-guarded.

### Proposed internal decomposition

`Get-StoreCertificate` (seam) -> `Select-ExportableCertificate` (validity,
`Disallowed` subtraction, de-dup) -> `ConvertTo-PemCertificate` (block + header)
-> `Write-CertificateBundle` (sort, atomic, idempotent, ShouldProcess) ->
`ThrowError` (house helper). The deliverable remains a single `.ps1`; helpers
live inline in the `Functions` region.

### Consequences

- **Positive:** the script reads as a native portfolio member; one mockable seam
  makes Windows-only behavior testable on Linux CI; the 80% gate is met by real
  logic, not a lowered bar.
- **Negative:** the full template adds scaffolding around a simple exporter — the
  accepted cost of platform consistency and a strong unattended-run story.

## More Information

- Realizes the selection, format, write, and summary decisions in
  [repo/0002](0002-certificate-source-and-selection.md)–[repo/0005](0005-summary-and-manifest-output.md).
- Diataxis documentation: [org/0002](../org/0002-adopt-diataxis-documentation-framework.md).

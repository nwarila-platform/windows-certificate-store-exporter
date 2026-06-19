# PSGallery Benchmark

The raw PSGallery PSScriptAnalyzer run is an external reference point, not the
house gate. It scans the built functions artifact,
`build/Export-CertificateStoreBundle.Functions.ps1`, with the default ruleset:
no `-Settings`, no custom rules, and no local exclusions.

That artifact scope is intentional. [ADR-repo/0006](../decision-records/repo/0006-script-structure-and-test-seam.md)
records the build model: source lives in small files, while the merged artifacts
are the code paths tests and releases exercise. Benchmarking the artifact gives
reviewers the objective PSGallery view of what the project actually ships.

The house analyzer remains the enforcement gate. It uses
[`PSScriptAnalyzerSettings.psd1`](../../PSScriptAnalyzerSettings.psd1), including
the recorded `ExcludeRules` entry for `PSUseShouldProcessForStateChangingFunctions`.
The broader function-surface policy is recorded in
[ADR-template/0002](../decision-records/template/0002-explicit-attribute-surface-and-design-advisor.md):
state-changing functions carry real `ShouldProcess`; pure readers and pure
constructors do not.

## Residual Findings

| Rule | Artifact finding | Justification |
| --- | --- | --- |
| `PSUseShouldProcessForStateChangingFunctions` | `New-CertificateStoreExporterResult` | Factory function. It constructs an in-memory result object and changes no system state. The `New` verb trips the default PSScriptAnalyzer state-change heuristic, but adding `ShouldProcess` would misrepresent the function. |
| `PSUseShouldProcessForStateChangingFunctions` | `New-ErrorRecord` | Factory function. It constructs an in-memory `ErrorRecord` and changes no system state. The `New` verb trips the same heuristic, but there is no state-changing action to confirm or skip. |

The divergence is narrow and auditable: the raw benchmark continues to show these
two PSGallery findings, while the house gate excludes the heuristic rule for this
project's factory-function pattern.

## Artifact Scope and `PSShouldProcess`

Scanning standalone `src/` files can surface a spurious `PSShouldProcess`
finding on `Export-CertificateStoreBundle`. That function declares
`SupportsShouldProcess` and delegates the single state-changing call site to
`Write-CertificateBundle`, where `ShouldProcess` is actually invoked. The
single-file scan cannot see that delegate in scope, so the benchmark scans the
merged artifact instead. In the shipped artifact, the false positive disappears.

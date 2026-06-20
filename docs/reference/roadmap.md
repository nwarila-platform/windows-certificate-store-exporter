# Roadmap

This project is intentionally small: it ships one Windows PowerShell 5.1 script,
`Export-CertificateStoreBundle.ps1`, that reads Windows certificate stores and
writes a deterministic PEM bundle. The current public release is `1.0.0`, and
the repository decisions describe a single-script distribution model rather than
a module package.

## Maintenance Scope

For the next 12 months, maintenance focuses on keeping the released script
usable, reproducible, and aligned with its documented command-line contract:

- Keep Windows PowerShell 5.1 compatibility for the build, tests, and released
  artifact. CI runs the build on `windows-latest` with Windows PowerShell 5.1,
  and the ADRs record that this is a Windows certificate-store tool.
- Review dependency and GitHub Actions updates surfaced by Renovate. The local
  `renovate.json5` enables weekly, age-gated GitHub Actions updates and keeps
  action references pinned to commit SHAs.
- Fix correctness, security, and documentation defects that affect the CLI
  contract, release assets, or trust-bundle behavior.
- Preserve the release asset shape documented in the README: the `.ps1`
  script, `.sha256` sidecar, and SLSA provenance (`.intoto.jsonl`).

Behavior changes should first update the public contract or a repository ADR,
then the implementation and tests. The build model in ADR-repo/0001 and
ADR-repo/0006 remains the expected shape: structured source under `src/`,
assembled into one release script by `build.ps1`.

## Under Consideration

The following items are discretionary. They are not commitments for a scheduled
release:

- Authenticode publisher signing. ADR-repo/0005 defers signing until a
  code-signing certificate exists; SLSA provenance and SHA-256 sidecars are the
  current release integrity mechanisms.
- PSGallery publishing. The project currently describes itself as a single
  script, not a PowerShell module. Publishing through PSGallery would need a
  packaging decision that keeps the single-script consumer experience clear.
- Message-table localization. ADR-repo/0009 records the current English-only
  script-scope message table and says localized `.psd1` files would need a new
  decision if localization becomes a real requirement.

## Non-Goals

The roadmap does not include a cross-platform or .NET Core port. The exporter
depends on Windows certificate-store access and validates on Windows PowerShell
5.1.

The roadmap also does not include replacing the single-script release with a
multi-script module package, rewriting the tool in another language, or adding
runtime monitoring. The exporter is produce-only: it writes the bundle and
optional manifest, but deployment tooling or the operator owns consumer
configuration and monitoring.

## Sources

- [README](../../README.md)
- [CHANGELOG](../../CHANGELOG.md)
- [CLI contract](cli-contract.md)
- [Renovate configuration](../../renovate.json5)
- [CI workflow](../../.github/workflows/ci.yaml)
- [Release workflow](../../.github/workflows/release.yaml)
- [ADR-repo/0001](../decision-records/repo/0001-single-script-project.md)
- [ADR-repo/0002](../decision-records/repo/0002-certificate-source-and-selection.md)
- [ADR-repo/0005](../decision-records/repo/0005-summary-and-manifest-output.md)
- [ADR-repo/0006](../decision-records/repo/0006-script-structure-and-test-seam.md)
- [ADR-repo/0009](../decision-records/repo/0009-sg8-centralized-message-table.md)

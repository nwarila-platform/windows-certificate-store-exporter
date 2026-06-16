# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) governing this
repository, split into three scopes per [org/0001](org/0001-use-architecture-decision-records.md):

- [`org/`](org/) - byte-identical mirrors of the org-baseline ADRs whose master
  copies live in
  [`nwarila-platform/.github`](https://github.com/nwarila-platform/.github/tree/main/docs/decision-records).
- [`template/`](template/) - byte-identical mirrors of type-template ADRs
  inherited from
  [`NWarila/powershell-template`](https://github.com/NWarila/powershell-template/tree/main/docs/decision-records/template).
- [`repo/`](repo/) - repository-specific ADRs that apply only to this repo.

The three scopes use independent four-digit numbering namespaces and the same
MADR 4.0-aligned format.

## Index

### Org-Mirrored

| # | Title | Status | Date | Summary |
| --- | --- | --- | --- | --- |
| [org/0001](org/0001-use-architecture-decision-records.md) | Use Architecture Decision Records to Document Design Rationale | Accepted | 2026-04-22 | Adopt ADRs as the documentation format for architecturally significant decisions. |
| [org/0002](org/0002-adopt-diataxis-documentation-framework.md) | Adopt Diataxis as the Documentation Framework | Accepted | 2026-04-24 | Adopt the Diataxis four-quadrant framework for non-ADR documentation. |
| [org/0003](org/0003-use-deny-all-gitignore-strategy.md) | Use a Deny-All `.gitignore` Strategy | Accepted | 2026-04-25 | Adopt deny-all `.gitignore` with explicit allowlist as the default tracking strategy. |
| [org/0004](org/0004-use-renovate-for-dependency-updates.md) | Use Renovate for Dependency Updates with Per-Template Baselines | Accepted | 2026-05-05 | Adopt Renovate org-wide; each type-template owns a self-contained Renovate baseline. |

### Template-Mirrored

| # | Title | Status | Date | Summary |
| --- | --- | --- | --- | --- |
| [template/0001](template/0001-module-layout.md) | Use Public and Private Function Folders with Explicit Manifest Exports | Accepted | 2026-06-02 | Module consumers use `src/<ModuleName>/` with `Public/`+`Private/` and explicit manifest exports. This repo diverges per [repo/0001](repo/0001-single-script-project.md). |

### Repository-Specific

| # | Title | Status | Date | Summary |
| --- | --- | --- | --- | --- |
| [repo/0001](repo/0001-single-script-project.md) | Assemble a Single Release Script from Structured Source | Accepted | 2026-06-11 | Author under `src/`; use `build.ps1` to emit one release script and one functions-only test artifact. |
| [repo/0002](repo/0002-certificate-source-and-selection.md) | Source CA Certificates from the Logical LocalMachine Stores | Accepted | 2026-06-12 | Read `Root` + `CA` logical stores; subtract `Disallowed`; drop expired by default. |
| [repo/0003](repo/0003-pem-bundle-format.md) | Emit a Deterministic certifi-Style PEM Bundle | Accepted | 2026-06-12 | PEM, ASCII/no-BOM/LF, certifi-style headers, thumbprint-sorted, no timestamp. |
| [repo/0004](repo/0004-write-semantics-and-safety.md) | Write the Bundle Atomically and Fail Closed | Accepted | 2026-06-12 | Mandatory `-Path`, atomic + ShouldProcess write, skip-if-unchanged, minimum-count floor. |
| [repo/0005](repo/0005-summary-and-manifest-output.md) | Return a Typed Summary and an Opt-In SHA-256 Manifest | Accepted | 2026-06-12 | Soft-return summary object with hashes; opt-in `-WriteManifest` sidecar. |
| [repo/0006](repo/0006-script-structure-and-test-seam.md) | Use the Build Model and Mocked Read Seam | Accepted | 2026-06-12 | Build-model source split with a functions-only coverage artifact; mock the read seam for deterministic tests. |
| [repo/0007](repo/0007-sg6-soft-return-and-canonical-call-syntax.md) | Adopt SG-6 Soft Return and Canonical Call Syntax | Accepted | 2026-06-15 | Soft-return output functions; colon-form command parameters; PascalCase PowerShell keywords. |

## Authoring Rules

- Org-baseline ADRs are mirrors only. Do not edit files under `org/` in this
  repository directly; update the master copy in `nwarila-platform/.github` and
  sync it down.
- Type-template ADRs are mirrors only and belong under `template/`; update the
  master in `NWarila/powershell-template` and sync it down.
- Repo-specific ADRs go under `repo/`. The `repo/` namespace is independent of
  `org/` and `template/`, so `org/0001`, `template/0001`, and `repo/0001` can
  coexist.
- Updating this index belongs in the same PR as adding or changing an ADR.

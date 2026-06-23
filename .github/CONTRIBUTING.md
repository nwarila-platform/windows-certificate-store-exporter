# Contributing

Thank you for taking the time to improve `windows-certificate-store-exporter`.
This repository is small by design, so contributions should stay focused,
well-tested, and aligned with the published command-line contract.

## Before You Start

- Use Windows PowerShell 5.1 for local validation.
- Install the pinned tooling before building:

  ```powershell
  Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
  Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
  ```

  `build.ps1` does not install them. `-Task Analyze` and `-Task Test` fail
  closed if PSScriptAnalyzer or Pester is absent.
- Read the project documentation at [docs/README.md](../docs/README.md).
- Behaviour changes must stay consistent with the
  [CLI contract](../docs/reference/cli-contract.md).
- Style changes must follow the [house PowerShell style guide](../docs/STYLE-GUIDE.md).

## Build And Test

Run the full build before opening a pull request:

```powershell
.\build.ps1 -Task All
```

The `All` task runs Build, Analyze, Test, and Smoke. Analyze requires
PSScriptAnalyzer (it fails closed when the module is absent) and must report 0
findings, and Pester enforces the configured coverage gate of at least 90%.

## Commits

- Use Conventional Commits, for example `docs: add support policy`.
- Sign every commit. The branch ruleset requires verified signatures.
- Keep commits reviewable and scoped to the change being proposed.

## Pull Requests

- Open pull requests against `main`.
- The repository uses squash merge only.
- The required checks must pass:
  - `build (windows-powershell51)`
  - `actionlint`
  - `secret scan (gitleaks)`
  - `repo hygiene`
  - `zizmor`
- Pull requests require at least 1 approving review, code-owner review, and all
  review threads resolved before merge.

## Security

Do not open a public issue for security vulnerabilities. Follow
[SECURITY.md](../SECURITY.md) for private reporting.

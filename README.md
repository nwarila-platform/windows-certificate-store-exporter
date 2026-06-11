# windows-certificate-store-exporter

[![CI](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml/badge.svg)](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml)
[![PowerShell 5.1+ / 7+](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PSScriptAnalyzer](https://img.shields.io/badge/lint-PSScriptAnalyzer-blue)](https://github.com/PowerShell/PSScriptAnalyzer)
[![Tested with Pester](https://img.shields.io/badge/tested%20with-Pester%20v5-green)](https://pester.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

PowerShell script project for exporting certificates from the Windows
LocalMachine certificate store to `.crt` files for backup, inspection, and trust
distribution.

This repository consumes
[NWarila/powershell-template](https://github.com/NWarila/powershell-template):
it uses the template's repo guardrails: Pester v5 test runner,
PSGallery-aligned PSScriptAnalyzer settings, SHA-pinned GitHub Actions
workflow, Renovate configuration, and Diataxis documentation structure.

This is intentionally a single-script project, not a PowerShell module.

## Quickstart

```powershell
./windows-certificate-store-exporter.ps1
```

Exporter behavior is not implemented yet; the current script is a scaffold that
keeps CI and repo structure aligned with the template.

## Structure

```text
windows-certificate-store-exporter.ps1
tests/
  windows-certificate-store-exporter.Tests.ps1
  Invoke-Tests.ps1
docs/
  README.md
```

See [docs/reference/module-structure.md](docs/reference/module-structure.md)
for the full reference.

## Validate locally

```powershell
Invoke-ScriptAnalyzer -Path . -Settings PSGallery -Recurse
pwsh -File tests/Invoke-Tests.ps1
```

## Documentation

Documentation follows the [Diataxis framework](https://diataxis.fr/). Start at
[docs/README.md](docs/README.md).

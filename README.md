# windows-certificate-store-exporter

[![CI](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml/badge.svg)](https://github.com/nwarila-platform/windows-certificate-store-exporter/actions/workflows/ci.yaml)
[![PowerShell 5.1+ / 7+](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PSScriptAnalyzer](https://img.shields.io/badge/lint-PSScriptAnalyzer-blue)](https://github.com/PowerShell/PSScriptAnalyzer)
[![Tested with Pester](https://img.shields.io/badge/tested%20with-Pester%20v5-green)](https://pester.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

PowerShell script project for exporting Windows LocalMachine CA certificates
(`Root` and `CA`) to a deterministic PEM bundle for backup, inspection, and trust
distribution.

This repository consumes
[NWarila/powershell-template](https://github.com/NWarila/powershell-template):
it uses the template's repo guardrails: Pester v5 test runner,
PSGallery-aligned PSScriptAnalyzer settings, SHA-pinned GitHub Actions
workflow, Renovate configuration, and Diataxis documentation structure.

The source is split under `src/` and assembled into a single release script by
`build.ps1`. It is not a PowerShell module.

## Quickstart

```powershell
./build.ps1 -Task All
./build/Export-CertificateStoreBundle.ps1 -Path ./bundle.pem -WhatIf
```

Exporter behavior is still scaffolded. Release automation is planned but not yet
implemented; when it lands, GitHub Releases will publish
`Export-CertificateStoreBundle.ps1` plus a SHA-256 sidecar.

## Structure

```text
build.ps1
src/
  EntryPoint.ps1
  Private/
  Public/
tests/
  Private/
  Public/
  Smoke/
docs/
  README.md
```

See [docs/reference/module-structure.md](docs/reference/module-structure.md)
for the full reference.

## Validate locally

```powershell
./build.ps1 -Task All
```

## Documentation

Documentation follows the [Diataxis framework](https://diataxis.fr/). Start at
[docs/README.md](docs/README.md).

# Getting started

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Pester v5 for tests
- PSScriptAnalyzer for linting

## Run the scaffold

```powershell
./build.ps1 -Task All
./build/Export-CertificateStoreBundle.ps1 -Path ./bundle.pem -WhatIf
```

The built script is currently a P0 scaffold. It accepts the planned entry-point
parameters and performs no certificate-store I/O or file writes yet.

## Validate the repo

```powershell
./build.ps1 -Task All
```

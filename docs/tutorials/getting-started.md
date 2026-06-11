# Getting started

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Pester v5 for tests
- PSScriptAnalyzer for linting

## Run the scaffold

```powershell
./windows-certificate-store-exporter.ps1
```

The script currently throws a clear "not implemented yet" message. The project
is aligned with the template guardrails before exporter behavior is added.

## Validate the repo

```powershell
Invoke-ScriptAnalyzer -Path . -Settings PSGallery -Recurse
pwsh -File tests/Invoke-Tests.ps1
```

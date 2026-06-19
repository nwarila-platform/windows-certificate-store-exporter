# Add Script Behavior

## Add source under `src/`

Put private helpers under `src/Private/` and public entry functions under
`src/Public/`. `build.ps1` assembles those files into the release script, so do
not edit files under `build/` directly.

## Tests

Add or update companion tests under `tests/Private/` or `tests/Public/`. Tests
dot-source `build/Export-CertificateStoreBundle.Functions.ps1`, which is also
the Pester coverage target.

## Validate

Run the full local gate before publishing a change:

```powershell
.\build.ps1 -Task All
```

The gate rebuilds generated artifacts, runs PSScriptAnalyzer with the house
settings, runs smoke tests, and enforces Pester coverage.

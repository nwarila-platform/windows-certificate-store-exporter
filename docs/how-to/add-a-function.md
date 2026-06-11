# Add script behavior

## Keep the single-script shape

Implement exporter behavior in `windows-certificate-store-exporter.ps1` unless
the project intentionally grows into a module later.

## Tests

Add or update tests in `tests/windows-certificate-store-exporter.Tests.ps1`.
Keep tests focused on script behavior and PowerShell parser/analyzer hygiene.

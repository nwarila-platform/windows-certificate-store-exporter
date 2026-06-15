# Function Reference

This index gives every source function a stable HelpUri anchor. Public CLI behavior is
specified in [cli-contract.md](cli-contract.md).

## ConvertTo-PemCertificate

Converts one certificate into an ASCII PEM block with deterministic certifi-style
metadata.

```powershell
ConvertTo-PemCertificate -Certificate <X509Certificate2> [-StoreName <Root|CA|Disallowed>]
```

## Export-CertificateStoreBundle

Reads the requested Windows certificate stores, subtracts Disallowed, writes the
bundle, and returns the success result object.

```powershell
Export-CertificateStoreBundle -Path <string> [-StoreLocation <LocalMachine|CurrentUser>] [-StoreName <Root|CA[]>] [-IncludeExpired] [-MinimumCertificateCount <int>] [-WriteManifest]
```

## Get-CertificateRawDataSha256

Computes an uppercase SHA-256 hash over a certificate's DER `RawData` bytes.

```powershell
Get-CertificateRawDataSha256 -Certificate <X509Certificate2>
```

## Get-StoreCertificate

Reads certificates from one Windows X509Store. This is the only live certificate-store
I/O seam.

```powershell
Get-StoreCertificate [-StoreLocation <LocalMachine|CurrentUser>] [-StoreName <Root|CA|Disallowed>]
```

## New-CertificateStoreExporterResult

Builds the `CertificateStoreExporter.Result` success object emitted by the public
orchestrator.

```powershell
New-CertificateStoreExporterResult -Path <string> -Status <Written|Unchanged|WhatIf> -BundleSha256 <string> [-Certificate <X509Certificate2[]>] [-Examined <int>] [-ExcludedExpired <int>] [-ExcludedNotYetValid <int>] [-ExcludedDisallowed <int>] [-ExcludedDuplicate <int>] [-StoreLocation <LocalMachine|CurrentUser>] [-StoreName <Root|CA[]>] [-ManifestPath <string>] [-GeneratedAtUtc <datetime>]
```

## New-ErrorRecord

Creates or throws a structured `ErrorRecord` with an exporter `ExporterExitCode`
ErrorId.

```powershell
New-ErrorRecord -Message <string> -ErrorId <ExporterExitCode> [-Exception <Exception>] [-Category <ErrorCategory>] [-TargetObject <object>] [-IsFatal]
```

## Resolve-ExitCode

Maps known exporter error records to process exit codes and emits no output for
unknown errors.

```powershell
Resolve-ExitCode -ErrorRecord <ErrorRecord>
```

## Select-ExportableCertificate

Filters certificates by validity, subtracts Disallowed hashes, de-duplicates by
SHA-256 DER identity, and returns deterministic hash order.

```powershell
Select-ExportableCertificate [-Certificate <X509Certificate2[]>] [-DisallowedThumbprint <string[]>] [-IncludeExpired]
```

## Test-CertificateStoreExporterWindows

Reports whether the current runtime can access Windows certificate stores.

```powershell
Test-CertificateStoreExporterWindows
```

## Write-CertificateBundle

Writes the ASCII LF PEM bundle and optional SHA-256 manifest with idempotent,
atomic file operations.

```powershell
Write-CertificateBundle -Path <string> [-PemBlock <string[]>] [-MinimumCertificateCount <int>] [-WriteManifest]
```

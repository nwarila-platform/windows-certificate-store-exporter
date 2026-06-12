# Why This Layout

This project ships one `.ps1` file but does not author that file by hand.

## One Release Script

Consumers download and run `Export-CertificateStoreBundle.ps1`. They do not need
a module manifest, `Import-Module`, or a folder of helper files. That keeps the
release artifact simple for GPO, scheduled task, or configuration-management
deployment.

## Structured Source

Maintainers work in focused files under `src/`:

- `EntryPoint.ps1` owns script parameters, initialization, traps, and process
  exit behavior.
- `Public/Export-CertificateStoreBundle.ps1` owns orchestration.
- `Private/*.ps1` owns helper behavior.

`build.ps1` assembles those files into the release script and a functions-only
artifact. Tests dot-source the functions-only artifact so coverage applies to
the same merged helper code that ships.

## Mocked Store Read Seam

The only live Windows certificate-store I/O is `Get-StoreCertificate`. Tests
mock that seam and feed deterministic certificate fixtures into the pure helper
and orchestration paths. The live seam remains thin: it checks for Windows,
opens one `X509Store` read-only with `OpenExistingOnly`, returns certificates,
and maps store failures to `StoreReadFailure`.

This build and test shape is recorded in
[ADR-repo/0006](../decision-records/repo/0006-script-structure-and-test-seam.md).

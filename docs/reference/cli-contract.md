# CLI Contract

`Export-CertificateStoreBundle.ps1` is a Windows PowerShell 5.1 script assembled
by `build.ps1`. It is not a module command you import.

## Parameters

| Parameter | Type | Default | Valid values | Behavior |
| --- | --- | --- | --- | --- |
| `-Path` | `System.String` | Required | Non-empty string | Destination bundle path. |
| `-StoreLocation` | `System.String` | `LocalMachine` | `LocalMachine`, `CurrentUser` | Windows logical certificate-store location. |
| `-StoreName` | `System.String[]` | `Root,CA` | `Root`, `CA` | One or more stores to export. `Disallowed` is always read separately and subtracted. |
| `-IncludeExpired` | Switch | Off | Present or absent | Includes expired and not-yet-valid certificates instead of filtering them out. |
| `-MinimumCertificateCount` | `System.Int32` | `1` | `0` through `Int32::MaxValue` | Minimum surviving certificate count. If the bundle would contain fewer certificates, the script throws before writing. |
| `-WriteManifest` | Switch | Off | Present or absent | Writes `<bundle>.sha256` beside the bundle. |
| `-LogLevel` | `System.String` | `1111111` | Seven digits | Accepted by the entry script for ScriptTemplate runtime context. |
| `-DebugLevel` | `System.String` | `000` | Three digits | Accepted by the entry script for ScriptTemplate runtime context. |
| `-Trap` | Switch | Off | Present or absent | Re-emits known errors before exiting with their mapped code. |

The script has `SupportsShouldProcess`, so PowerShell common parameters such as
`-WhatIf` and `-Confirm` are honored by the write step.

## Certificate Selection

1. Read each requested store from `-StoreLocation`.
2. Always read the `Disallowed` store from the same location.
3. Unless `-IncludeExpired` is set, exclude certificates outside their
   `NotBefore`/`NotAfter` validity window.
4. Exclude certificates whose SHA-256 DER hash appears in `Disallowed`.
5. De-duplicate by SHA-256 DER hash.
6. Sort retained certificates by SHA-256 DER hash for bundle order.

Certificate identity is SHA-256 over `X509Certificate2.RawData`. It is not the
SHA-1 `X509Certificate2.Thumbprint` property.

## Result Object

On success, the script writes exactly one object whose first type name is
`CertificateStoreExporter.Result`.

| Field | Type | Meaning |
| --- | --- | --- |
| `Path` | `System.String` | Path value supplied to the command. |
| `Status` | `System.String` | `Written`, `Unchanged`, or `WhatIf`. |
| `CertificateCount` | `System.Int32` | Number of certificates in the generated bundle. |
| `Thumbprints` | `System.String[]` | Uppercase SHA-256 DER hashes in bundle order. |
| `BundleSha256` | `System.String` | Uppercase SHA-256 hash of the generated bundle bytes. |
| `Examined` | `System.Int32` | Number of candidate certificates read from requested stores before filtering. |
| `Excluded` | `PSCustomObject` | Counts for `Expired`, `NotYetValid`, `Disallowed`, and `Duplicate`. |
| `StoreLocation` | `System.String` | Store location used for the export. |
| `StoreNames` | `System.String[]` | Requested store names used for the export. |
| `ManifestPath` | `System.String` or `$null` | `<bundle>.sha256` path when `-WriteManifest` is set; otherwise `$null`. |
| `GeneratedAtUtc` | `System.DateTime` | UTC timestamp on the result object only. |

Known failures do not emit a result object.

## Exit Codes

| Code | Meaning | ErrorId |
| --- | --- | --- |
| `0` | Success: `Written`, `Unchanged`, or `WhatIf`. | N/A |
| `1` | Unhandled failure. | Unmapped error |
| `2` | Surviving certificate count is below `-MinimumCertificateCount`. | `BelowMinimumCertificateCount` |
| `3` | Windows certificate stores are unavailable because the script is not running on Windows. | `NotWindows` |
| `4` | A certificate store could not be opened or read. | `StoreReadFailure` |
| `5` | Bundle or manifest writing failed. | `WriteFailure` |

The entry script maps the leading segment of `FullyQualifiedErrorId`.

## Bundle Format

The bundle is a concatenated PEM file:

- RFC 7468 `-----BEGIN CERTIFICATE-----` / `-----END CERTIFICATE-----` blocks.
- Base64 DER body wrapped at 64 characters.
- ASCII bytes, no byte-order mark, and LF line endings.
- One certifi-style comment header per certificate:
  - `Subject`
  - `Issuer`
  - `Serial`
  - `SHA-256`
  - `NotBefore`
  - `NotAfter`
  - `Source`
- No per-run timestamp in the bundle body.
- Certificates sorted by uppercase SHA-256 DER hash.

Non-ASCII distinguished-name characters in `Subject` and `Issuer` are escaped as
UTF-8 byte escapes such as `\xC3\xA9`; backslashes are doubled.

## Manifest Format

When `-WriteManifest` is present, the sidecar path is `<bundle>.sha256`. The
content is UTF-8 without a byte-order mark and uses LF:

```text
<64-character bundle SHA-256>  <bundle file name>
```

The bundle and manifest are written under the same `ShouldProcess`,
skip-if-unchanged, and atomic-write rules.

# Trust and Determinism Model

The exporter creates a trust artifact. A bad write can break AWS CLI TLS
verification, and an over-broad bundle can trust more certificate authorities
than intended. The design therefore favors deterministic, fail-closed behavior.

## Logical Store Sourcing

By default, the script reads `LocalMachine\Root` and `LocalMachine\CA`. Operators
can choose `CurrentUser` and can narrow `-StoreName` to `Root` or `CA`.

The logical Windows store view is intentionally simple and matches normal
PowerShell/.NET certificate-store access. It may include Microsoft-shipped public
roots as well as enterprise or GPO-provided certificates. The decision and its
trade-offs are recorded in
[ADR-repo/0002](../decision-records/repo/0002-certificate-source-and-selection.md).

## Disallowed Is Always Subtracted

The requested stores are not the whole trust decision. The exporter also reads
the `Disallowed` store from the same store location and removes any candidate
certificate whose SHA-256 DER hash appears there.

This keeps a denied certificate from re-entering the bundle merely because it is
also present in `Root` or `CA`.

## SHA-256 Identity

Windows exposes `X509Certificate2.Thumbprint`, but that value is SHA-1. This
project uses SHA-256 over `X509Certificate2.RawData` for:

- `Disallowed` subtraction.
- Duplicate detection.
- Bundle ordering.
- `Result.Thumbprints`.

The SHA-256 identity choice makes the output auditable without relying on SHA-1
for trust decisions.

## Deterministic Bundle Bytes

The PEM bundle uses ASCII bytes, LF line endings, no byte-order mark, 64-column
base64, and stable certificate ordering. The bundle body contains no generation
timestamp. Re-running against the same trust set produces identical bytes, which
lets the writer return `Unchanged` instead of rewriting a file.

The format details are recorded in
[ADR-repo/0003](../decision-records/repo/0003-pem-bundle-format.md).

## Fail Closed and Write Atomically

`-MinimumCertificateCount` defaults to `1`. If fewer certificates survive
filtering, the script throws before writing. This protects an existing bundle
from being replaced by an empty or under-populated bundle after a read or
selection problem.

When a write is needed, the writer creates a same-directory temp file and then
moves or replaces the destination. This prevents consumers from observing a
half-written bundle.

The safety behavior is recorded in
[ADR-repo/0004](../decision-records/repo/0004-write-semantics-and-safety.md).

## Produce-Only AWS Wiring

The exporter generates the bundle. It does not set `AWS_CA_BUNDLE`, and it does
not edit AWS CLI configuration. Deployment tooling or the operator owns that
wiring step so the script has a small blast radius.

The result object and optional manifest are recorded in
[ADR-repo/0005](../decision-records/repo/0005-summary-and-manifest-output.md).

# ADR-repo/0003: Emit a Deterministic certifi-Style PEM Bundle

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Proposed                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | RFC 7468; Mozilla/certifi `cacert.pem`; OpenSSL PEM parsing. |
| Informed       | Operators and reviewers consuming the bundle.                |
| Reversibility  | Medium                                                       |
| Review-by      | 2026-07-11                                                   |

## TL;DR

Write a concatenated PEM bundle (`.crt`): base64 DER in
`-----BEGIN/END CERTIFICATE-----`, 64-column wrap per RFC 7468, **ASCII / no BOM
/ LF**. Precede each certificate with a certifi-style comment header (Subject,
Issuer, Serial, SHA-256 thumbprint, validity, source store). Order certificates
deterministically by SHA-256 thumbprint and embed **no per-run timestamp** in
the file body.

## Context and Problem Statement

The AWS CLI (Python `ssl`/`urllib3` over OpenSSL) reads a CA bundle as
concatenated PEM blocks and ignores text outside the delimiters. The bundle is
version controlled, diffed run to run, and reviewed in pull requests, so the
encoding must be conservative and the output reproducible. A UTF-8 BOM or
non-deterministic ordering would break parsers or make diffs meaningless.

## Decision Drivers

1. **Toolchain safety** — parse cleanly under OpenSSL/Python on every platform.
2. **Auditability** — a reviewer should see exactly what is trusted without
   running `openssl x509` on each block.
3. **Reproducibility** — identical trust sets must produce identical bytes, to
   enable meaningful diffs and idempotent writes (ADR-repo/0004).

## Considered Options

1. **certifi-style headers + deterministic thumbprint ordering** (chosen).
2. **Pure PEM, no headers** — smallest file, but opaque without external
   tooling.
3. **Single label line per cert** — lightweight middle ground, less audit
   detail.

## Decision Outcome

Chosen: option 1.

- PEM with 64-column body wrap (RFC 7468); **ASCII**, **no byte-order mark**
  (a BOM breaks some PEM parsers), **LF** line endings.
- A certifi-style comment header per certificate: Subject, Issuer, Serial,
  SHA-256 thumbprint, `NotBefore`/`NotAfter`, source store — derived from
  certificate content and ignored by the AWS CLI at parse time.
- Certificates ordered by SHA-256 thumbprint for byte-stable output.
- No per-run timestamp in the file body; any "generated at" value lives in the
  summary object / verbose log (ADR-repo/0005).

### Consequences

- **Positive:** self-documenting, diffable bundle; deterministic output enables
  skip-if-unchanged writes.
- **Negative:** header text is informational, not cryptographically binding — the
  certificate content remains authoritative, mitigated by the SHA-256 thumbprint
  in each header.

## More Information

- Consumes the selection from [repo/0002](0002-certificate-source-and-selection.md);
  enables idempotency in [repo/0004](0004-write-semantics-and-safety.md).

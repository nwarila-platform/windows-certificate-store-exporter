# ADR-repo/0010: Default to Root-Only Trust Anchors

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-22                                                   |
| Authors        | Nick Warila (@NWarila)                                       |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | partial-chain TLS verification semantics; trust-store-replacing CA-bundle consumers |
| Informed       | operators deploying the bundle                               |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Default `-StoreName` to `Root` only. Keep `CA` as an explicit, warned opt-in for
operators who intentionally want intermediates in the flat bundle. This amends
ADR-repo/0002 only for the default store set; logical-store sourcing,
`Disallowed` subtraction, validity filtering, SHA-256 identity, and the bundle
format remain unchanged.

## Context and Problem Statement

The exporter produces a trust-store-replacing PEM bundle for consumers such as
`AWS_CA_BUNDLE`, curl `--cacert`, OpenSSL `-CAfile`, Python requests, and git
`http.sslCAInfo`. In a flat trust bundle, each certificate is presented to the
consumer as a possible trust anchor. That is straightforward for self-signed
roots from `Root`, but more subtle for intermediate CAs from `CA`.

Several important consumers accept partial chains. With partial-chain validation,
a chain may stop at a certificate that is present in the trust store even when
that certificate is an intermediate and the issuing root is absent. Including
`CA` by default therefore widens the trust surface: an intermediate-only bundle
entry can validate a leaf whose real root was not exported.

ADR-repo/0002 originally chose `Root, CA` as the default so chains could build
when a server omitted intermediates. That mixes two different roles. Roots belong
in the client trust store; intermediates normally belong in the server-presented
chain or in an explicitly operator-managed exception.

## Decision Drivers

1. **Least-surprise trust surface** - the default bundle should contain trust
   anchors, not intermediates promoted into anchors by client behavior.
2. **Primary documented consumer safety** - Python 3.13+ default contexts are a
   likely AWS CLI runtime path and include partial-chain verification by default.
3. **Operator escape hatch** - some deployments may deliberately need `CA`, so the
   option stays available.
4. **No bundle-format churn** - the existing per-certificate `# Source:` metadata
   already labels the source store without changing deterministic bytes for a
   given selected set.

## Considered Options

1. **Default `Root` only; keep `CA` as a warned opt-in** (chosen).
2. **Remove `CA` entirely** - safest by construction, but removes a legitimate
   operator escape hatch for special environments.
3. **Keep default `Root, CA`** - preserves the old output, but silently exposes
   partial-chain consumers to intermediate-as-anchor trust expansion.

## Decision Outcome

Chosen: option 1.

- `-StoreName` defaults to `Root` in both the entry script and public function.
- `[ValidateSet('Root', 'CA')]` remains unchanged; `CA` is still a valid explicit
  request.
- Requesting `CA` emits a warning on the warning stream explaining the trust
  expansion.
- The warning fires on request, independent of whether the store contains any
  certificates and independent of `-WhatIf`.
- The result object, exit codes, bundle format, sorting, identity rules, and
  deterministic bytes for a given selected certificate set are unchanged.

### Consequences

- **Positive:** default output is narrower and better aligned with client trust
  store semantics.
- **Positive:** operators can still opt into `CA`, but the warning makes the trust
  expansion visible.
- **Positive:** `Disallowed` subtraction and all selection rules from
  ADR-repo/0002 still apply.
- **Negative:** environments that depended on default intermediate export must now
  pass `-StoreName Root, CA` (or `-StoreName CA`) intentionally.

## More Information

- Amends the source-selection default from [repo/0002](0002-certificate-source-and-selection.md).
- Preserves the deterministic PEM format from [repo/0003](0003-pem-bundle-format.md).
- Preserves the fail-closed write behavior from [repo/0004](0004-write-semantics-and-safety.md).
- Python 3.13 notes: `ssl.create_default_context()` includes `VERIFY_X509_PARTIAL_CHAIN` in its default flags: https://docs.python.org/3/whatsnew/3.13.html
- Python `ssl` docs: default contexts use `VERIFY_X509_PARTIAL_CHAIN` and `VERIFY_X509_STRICT`: https://docs.python.org/3/library/ssl.html#ssl.VERIFY_X509_PARTIAL_CHAIN
- OpenSSL verification docs: `-partial_chain` allows a chain to end at a trust-store certificate that may be an intermediate CA: https://docs.openssl.org/3.1/man1/openssl-verification-options/
- curl PR #4655: OpenSSL backend sets `X509_V_FLAG_PARTIAL_CHAIN`: https://github.com/curl/curl/pull/4655
- libcurl `CURLSSLOPT_NO_PARTIALCHAIN`: disables accepting partial chains that libcurl otherwise accepts by default: https://curl.se/libcurl/c/CURLOPT_SSL_OPTIONS.html
- Git `http.sslCAInfo` / `http.sslBackend`: git over HTTPS uses libcurl certificate configuration and backend behavior: https://git-scm.com/docs/git-config

# ADR-repo/0002: Source CA Certificates from the Logical LocalMachine Stores

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-12                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | Windows certificate-store architecture; trust-store-replacing CA-bundle consumer semantics. |
| Informed       | Operators deploying the bundle via GPO/Ansible.              |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

> **Amended by [ADR-repo/0010](0010-root-only-default-trust-anchors.md) (2026-06-22):** the default store set is now `Root` only; `CA` is a warned opt-in.

## TL;DR

Read CA certificates from the **logical `LocalMachine` stores** (the
`Cert:\LocalMachine\*` view), defaulting to `Root` + `CA`, via enum-validated
`-StoreLocation` / `-StoreName` parameters. Always subtract `Disallowed` by
SHA-256 thumbprint, exclude expired/not-yet-valid certs by default (with an
`-IncludeExpired` escape hatch), de-duplicate by thumbprint, and apply no
`BasicConstraints` filtering.

## Context and Problem Statement

The exporter produces a CA bundle from certificates on a Windows workstation,
typically deployed by Group Policy. Trust-store-replacing consumers, e.g. the
AWS CLI through `AWS_CA_BUNDLE` / `ca_bundle`, consume that bundle as a
replacement for their built-in trust store rather than appending to it — so
every included certificate becomes a trust anchor for that client's TLS
verification, and selection scope is a security decision.

Windows exposes two relevant mechanisms: the Group Policy **physical** store
(`CERT_SYSTEM_STORE_LOCAL_MACHINE_GROUP_POLICY`), which isolates exactly the
GPO-pushed certificates, and the **logical** `LocalMachine` stores, which
aggregate GPO certificates with the machine registry store, the enterprise/AD
store, and the Microsoft-shipped public roots. The logical view cannot
distinguish a GPO-pushed certificate from a built-in root.

## Decision Drivers

1. **Implementation simplicity and robustness** on a Windows-only tool.
2. **Bounded trust surface** — every anchor in the bundle is security-relevant.
3. **Operator flexibility** for user-targeted GPO (which deploys to
   `CurrentUser\Root`) without code changes.
4. **Testability** — explicit store parameters give the test seam concrete
   inputs.

## Considered Options

1. **Logical `LocalMachine` stores, default `Root` + `CA`** (chosen).
2. **Group Policy physical store only** — matches "installed via GPO" literally
   and yields the smallest, most auditable bundle, but requires `CertOpenStore`
   P/Invoke and cannot reuse the simpler logical read path.
3. **All stores including `AuthRoot`** — maximally inclusive but bloats the
   bundle with public roots already covered by certifi.

## Decision Outcome

Chosen: option 1.

- `-StoreLocation` (default `LocalMachine`) and `-StoreName` (default
  `Root, CA`) are enum-validated parameters
  (`X509Certificates.StoreLocation` / `StoreName`).
- `Root` supplies trust anchors; `CA` supplies intermediates so chains build
  when a server omits them.
- Certificates in `Disallowed` are always subtracted by SHA-256 thumbprint.
- Certificates outside their `NotBefore`/`NotAfter` window are excluded by
  default; `-IncludeExpired` retains them for CA-migration cross-signs.
- Results are de-duplicated by SHA-256 thumbprint.
- No `BasicConstraints` (`CA=true`) filtering — many legitimate older roots omit
  the extension; store membership is the better signal of intent.

### Consequences

- **Positive:** simple read path; safe operator override for user-targeted GPO;
  bounded by store restriction, `Disallowed` subtraction, validity filtering, and
  the fail-closed minimum count (ADR-repo/0004).
- **Negative:** the bundle may include Microsoft-shipped public roots present in
  the logical `Root` store, and the tool cannot certify that every included cert
  was GPO-deployed. A future provenance requirement would reopen this ADR to add
  the Group Policy physical store as a source.

## More Information

- Selection feeds the format in [repo/0003](0003-pem-bundle-format.md) and the
  safety floor in [repo/0004](0004-write-semantics-and-safety.md).
- Deny-by-default tracking: [org/0003](../org/0003-use-deny-all-gitignore-strategy.md).

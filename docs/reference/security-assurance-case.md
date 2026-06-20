# Security Assurance Case

This assurance case summarizes why the exporter is designed to produce a safe,
auditable TLS trust artifact. It is a repo-local argument, not a certification
claim. The supporting details live in the security policy, trust model, CLI
contract, ADRs, build policy, and release verification guidance.

## Threat Model

The exporter produces a CA bundle for TLS-verifying clients. The primary risks
are a bad or incomplete bundle that breaks TLS verification, and an over-broad
bundle that causes a client to trust certificate authorities the operator did
not intend to trust.

Because CA bundles are trust artifacts, the dangerous write failure is replacing
a previously good bundle with an empty, truncated, or over-filtered file. The
dangerous selection failure is letting a denied or duplicate certificate
identity re-enter the output through another store path.

## Trust Boundaries

The input boundary is the Windows certificate store view requested by the
operator. By default, the tool reads `LocalMachine\Root` and `LocalMachine\CA`;
the CLI can instead read `CurrentUser` and can narrow the store names to `Root`
or `CA`. Those logical stores may include Microsoft-shipped public roots,
enterprise or Active Directory certificates, and Group Policy certificates.

The output boundary is the generated PEM bundle and optional `<bundle>.sha256`
manifest. TLS clients consume that output only after the operator wires it into
the client.

The exporter does not make the client's TLS decision, edit client
configuration, or monitor downstream CA usage. Those are outside this tool's
boundary. The script is produce-only by design.

## Design Principles Applied

Fail closed. `-MinimumCertificateCount` defaults to `1`; if fewer certificates
survive filtering, the writer throws before any write occurs. Operators can
raise the floor when they know the expected minimum trust set.

Be deterministic. Certificate identity, duplicate detection, `Disallowed`
subtraction, result thumbprints, and bundle order use SHA-256 over DER
`RawData`, not the SHA-1 `X509Certificate2.Thumbprint` property. The bundle uses
ASCII bytes, LF line endings, no byte-order mark, 64-column base64, and no
per-run timestamp in the body. The same trust set therefore produces the same
bytes and can return `Unchanged`.

Write atomically. The writer creates same-directory temporary files, then uses a
move or replace operation for the final bundle and manifest. This prevents
consumers from observing half-written output.

Keep the blast radius small. The exporter has an explicit `-Path`, honors
`-WhatIf` and `-Confirm`, and does not set environment variables or edit
consumer configuration.

Apply defense in depth. The repository requires the Windows PowerShell 5.1 build
to pass PSScriptAnalyzer under the house settings, smoke tests, Pester tests,
and a 90% coverage gate before release. CI also runs workflow linting, secret
scanning, repository hygiene checks, and PSScriptAnalyzer SARIF upload. Releases
publish a SHA-256 sidecar and SLSA provenance so operators can verify the
downloaded artifact came from this repository's release workflow.

## Common-Weakness Countermeasures

Improper certificate selection is mitigated by constrained store selection,
validity filtering by default, `Disallowed` subtraction, SHA-256-DER identity,
and de-duplication before the PEM blocks are written. ADR-repo/0002 records the
trade-off: the logical Windows store view is simple and operator-friendly, but
it can include Microsoft-shipped public roots and cannot prove that each
certificate came from Group Policy.

Untrusted parameter input is constrained by the command surface. `-StoreLocation`
accepts only `LocalMachine` or `CurrentUser`; `-StoreName` accepts only `Root`
and `CA` on the public command; `-MinimumCertificateCount` must be at least `1`;
and `-Path` must be non-empty. The CLI contract documents the same public
surface.

Uncontrolled artifact modification is reduced by deterministic bytes, atomic
writes, skip-if-unchanged behavior, SHA-256 sidecars, and SLSA provenance. The
sidecar gives a fast offline integrity check; provenance verifies the release
artifact against the repository and tag.

Resource exhaustion and silent-empty output are addressed by scope and failure
behavior. The exporter reads only the requested logical stores plus
`Disallowed`; it does not crawl arbitrary locations. If filtering leaves too few
certificates, the write is aborted instead of producing an empty or
under-populated bundle.

Security reporting is handled through private vulnerability reporting when
available, with a documented fallback contact and response targets in
`SECURITY.md`.

## Evidence

- [SECURITY.md](../../SECURITY.md)
- [Trust and determinism model](../explanation/trust-and-determinism.md)
- [CLI contract](cli-contract.md)
- [Verify build provenance](../../README.md#verify-build-provenance-recommended)
- [ADR-repo/0002](../decision-records/repo/0002-certificate-source-and-selection.md)
- [ADR-repo/0003](../decision-records/repo/0003-pem-bundle-format.md)
- [ADR-repo/0004](../decision-records/repo/0004-write-semantics-and-safety.md)
- [ADR-repo/0005](../decision-records/repo/0005-summary-and-manifest-output.md)
- [ADR-repo/0006](../decision-records/repo/0006-script-structure-and-test-seam.md)
- [Contributing guide](../../.github/CONTRIBUTING.md)
- [PSScriptAnalyzer settings](../../PSScriptAnalyzerSettings.psd1)
- [CI workflow](../../.github/workflows/ci.yaml)
- [Release workflow](../../.github/workflows/release.yaml)
- [Public command source](../../src/Public/Export-CertificateStoreBundle.ps1)
- [Bundle writer source](../../src/Private/Write-CertificateBundle.ps1)

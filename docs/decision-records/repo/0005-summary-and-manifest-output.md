# ADR-repo/0005: Return a Typed Summary and an Opt-In SHA-256 Manifest

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Proposed                                                     |
| Date           | 2026-06-11                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | Portfolio SHA-256 manifest convention; PowerShell soft-return idiom. |
| Informed       | Verification pipelines and automation consumers.             |
| Reversibility  | High                                                         |
| Review-by      | 2026-07-11                                                   |

## TL;DR

Soft-return a single typed summary `PSCustomObject` (not the raw PEM) carrying
the resolved path, certificate counts, included per-cert SHA-256 thumbprints, the
bundle SHA-256, and the write status. The bundle hash and thumbprints are always
in the object; an on-disk sidecar manifest (`<bundle>.sha256` / JSON) is written
only when `-WriteManifest` is set.

## Context and Problem Statement

The portfolio leans on SHA-256 manifests for produced artifacts, and a CA bundle
is exactly where downstream verification matters: config-management can confirm
the deployed file matches what was generated, and an auditor can pin a fleet to a
known trust set. The house style soft-returns typed objects so callers and tests
have structured data — but the success stream must not carry the PEM text, which
would be noisy and could corrupt redirected output.

## Decision Drivers

1. **Verifiability** — expose a stable hash and the trusted-thumbprint set.
2. **Testability** — give cross-platform tests concrete values to assert on.
3. **Minimal footprint** — do not impose a second file on every run.
4. **Clean streams** — never emit PEM on the success stream.

## Considered Options

1. **Always-on summary hash + opt-in `-WriteManifest` sidecar** (chosen).
2. **Summary object only** — leanest; verification must capture the hash from the
   object/log.
3. **Sidecar manifest by default** — strongest for pipelines, but always writes a
   second file.

## Decision Outcome

Chosen: option 1.

- The script soft-returns one typed summary `PSCustomObject`: resolved `-Path`;
  counts examined / included / excluded-expired / excluded-by-`Disallowed`; the
  list of included per-certificate SHA-256 thumbprints; the bundle SHA-256; and
  write status (`Written` / `Unchanged` / `WhatIf`).
- Bundle SHA-256 and thumbprints are always present in the object.
- `-WriteManifest` writes `<bundle>.sha256` (and/or a small JSON manifest)
  alongside the bundle, under the same atomic + ShouldProcess rules as the bundle
  (ADR-repo/0004).

### Consequences

- **Positive:** verification tooling reads the hash and trusted set directly from
  the returned object; pipelines get an on-disk manifest with one switch; default
  footprint stays one file.
- **Negative:** the sidecar is a second artifact to keep in sync when enabled —
  acceptable because it is opt-in.

## More Information

- Builds on the write semantics in
  [repo/0004](0004-write-semantics-and-safety.md).

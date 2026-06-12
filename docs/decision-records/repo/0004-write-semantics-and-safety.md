# ADR-repo/0004: Write the Bundle Atomically and Fail Closed

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-12                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | AWS CLI CA-bundle resolution order; portfolio ShouldProcess convention. |
| Informed       | Operators and config-management tooling deploying the bundle. |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Require an explicit `-Path`; write the bundle atomically (temp file in the same
directory, then replace) under `SupportsShouldProcess`; skip the write when the
new bundle is byte-identical to the existing file (report `Unchanged`); and fail
closed by raising a structured error record and write nothing when the
surviving certificate count is below `-MinimumCertificateCount` (default 1). The
script is produce-only: it does not mutate the environment or `~/.aws/config`.

## Context and Problem Statement

A CA bundle is a trust artifact, possibly read by a running AWS CLI and deployed
across a fleet by GPO, scheduled task, or Ansible. The dangerous failure mode is
a run that over-filters or hits a read error, yields few or no certificates, and
overwrites a previously good bundle with an empty one — breaking every dependent
AWS CLI call. Write behavior must fail closed and must never expose a
half-written file. This aligns with the portfolio's deny-by-default posture.

## Decision Drivers

1. **No silent system mutation** — every write is intentional and auditable.
2. **No half-written artifact** under a live consumer.
3. **No clobbering a good bundle** with an empty/under-populated one.
4. **Idempotency** for config-management tooling.
5. **Single responsibility** — generation is separate from wiring.

## Considered Options

1. **Mandatory `-Path`, atomic + ShouldProcess write, skip-if-unchanged,
   fail-closed minimum count, produce-only** (chosen).
2. **Warn and write anyway** — permits clobbering a good bundle with an empty
   one.
3. **Default `ProgramData` destination** — a no-argument run mutates a system
   path.
4. **Opt-in `-ConfigureAwsCli`** that persists `AWS_CA_BUNDLE` or writes
   `ca_bundle` — larger blast radius; deferred.

## Decision Outcome

Chosen: option 1.

- **Mandatory `-Path`** — no silent default destination.
- **Atomic write** — temp file in the same directory, then move/replace.
- **`SupportsShouldProcess`** — honors `-WhatIf` / `-Confirm`.
- **Skip-if-unchanged** — when the generated bundle equals the file at `-Path`,
  skip the write and report `Unchanged` (relies on ADR-repo/0003 determinism).
- **Fail closed** — when surviving certs `< -MinimumCertificateCount`
  (default 1), throw a structured error record and write nothing, preserving any existing
  bundle. Operators may raise the floor to assert a known invariant.
- **Produce-only** — print the `AWS_CA_BUNDLE` / `ca_bundle` wiring snippet to
  verbose output only; do not mutate the environment or `~/.aws/config`.

### Consequences

- **Positive:** a broken or empty run cannot damage a deployed bundle; the tool
  stays composable with deployment tooling owning the wiring step.
- **Negative:** operators must supply `-Path` and own wiring — the intended
  trade-off for safety and a small blast radius.

## More Information

- Idempotency requires the deterministic, timestamp-free output of
  [repo/0003](0003-pem-bundle-format.md); structure/seam in
  [repo/0006](0006-script-structure-and-test-seam.md).

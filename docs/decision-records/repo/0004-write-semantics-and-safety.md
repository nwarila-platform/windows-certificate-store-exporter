# ADR-repo/0004: Write the Bundle Atomically and Fail Closed

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-12                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | CA-bundle consumer resolution patterns; portfolio ShouldProcess convention. |
| Informed       | Operators and config-management tooling deploying the bundle. |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Require an explicit `-Path`; write the bundle atomically (temp file in the same
directory, then replace) under `SupportsShouldProcess`; skip the write when the
new bundle is byte-identical to the existing file (report `Unchanged`); and fail
closed by raising a structured error record and write nothing when the
surviving certificate count is below `-MinimumCertificateCount` (default 1). The
script is produce-only: it does not mutate the environment or consumer
configuration.

## Context and Problem Statement

A CA bundle is a trust artifact, possibly read by a running TLS client and
deployed across a fleet by GPO, scheduled task, or Ansible. The dangerous
failure mode is a run that over-filters or hits a read error, yields few or no
certificates, and overwrites a previously good bundle with an empty one —
breaking dependent TLS verification. Write behavior must fail closed and must
never expose a half-written file. This aligns with the portfolio's
deny-by-default posture.

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
4. **Opt-in consumer configuration** that persists environment variables or
   edits client configuration — larger blast radius; deferred.

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
- **Reparse paths** - the writer does not special-case symlinks, junctions,
  or other reparse points; it follows the operator-specified `-Path` and keeps
  same-directory temp/swap behavior atomic on the resolved target.
- **Transactional bundle + manifest pair** — within a single invocation the
  bundle and its `.sha256` manifest are written transactionally: both are swapped
  via same-directory temp files, both prior versions are retained as backups until
  BOTH swaps succeed, and a manifest-swap failure rolls the bundle back with an
  atomic `File.Replace` (old-or-new, never missing) so the on-disk pair is never a
  new-bundle/stale-manifest mismatch. Deliberately un-mitigated residuals (lean —
  no mutex or journal; the GPO/scheduled-task/Ansible deployment model serializes
  writers):
  - **Not cross-process** — two concurrent writers against the same `-Path` with
    `-WriteManifest` can still interleave into a mismatched pair.
  - **Not crash-atomic** — abrupt termination between the two swaps can leave a
    stale manifest or a leftover temp/backup artifact.
  - **Restore-failure** — if the in-process atomic restore itself fails, the pair
    may be left mismatched but is NEVER missing.
  All three self-correct on the next successful run (idempotent skip-if-unchanged).
- **Produce-only** — emit no consumer-specific wiring; do not mutate the
  environment or client configuration.

### Consequences

- **Positive:** a broken or empty run cannot damage a deployed bundle; the tool
  stays composable with deployment tooling owning the wiring step.
- **Negative:** operators must supply `-Path` and own wiring — the intended
  trade-off for safety and a small blast radius.

## More Information

- Idempotency requires the deterministic, timestamp-free output of
  [repo/0003](0003-pem-bundle-format.md); structure/seam in
  [repo/0006](0006-script-structure-and-test-seam.md).

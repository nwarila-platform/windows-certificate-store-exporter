# REPORT - SG-7 Docs

Status: complete
Branch: `codex-sg7-docs`

## Changes

- Added `SG-7 - Explicit parameter surface` to `docs/STYLE-GUIDE.md`.
  - Documents the required five `[Parameter(...)]` options:
    `DontShow`, `Mandatory`, `ParameterSetName`, `ValueFromPipeline`,
    `ValueFromPipelineByPropertyName`.
  - Records the forbid-list: `Position`, `HelpMessage`, and
    `ValueFromRemainingArguments`.
  - Calls out the `$StoreFactory` hidden test-seam exemption with
    `DontShow = $True`.
  - Names `Measure-ExplicitParameterAttribute` and
    `Measure-CanonicalAttributeOrder` as the enforcing analyzer rules.
- Added `ADR-repo/0008: Adopt SG-7 Explicit Parameter Surface` at
  `docs/decision-records/repo/0008-sg7-explicit-parameter-surface.md`.
  - Records the honest framing: explicit five-option surface is an
    auditability preference; the forbid-list is correctness.
  - Cites Microsoft primary sources for `[Parameter()]`, `PositionalBinding`,
    and `ParameterAttribute` defaults/semantics.
- Updated `docs/decision-records/README.md` with the repo/0008 index entry.
- Tightened the SG-5 parameter-order example so it points at the SG-7 option list.

## Scope

- Docs/handoff only.
- No source code changed.
- No analyzer code changed.
- No analyzer settings changed.
- No push or merge performed.

## Verification

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All
```

Result: passed.

- Build OK.
- Analyze: 0 findings.
- Pester: 90 passed, 0 failed.
- Coverage: 95.93% (threshold 90%).
- Exit-code tests: six mappings passed.
- Smoke stage: passed (`BuildArtifacts.ps1`, `LiveStoreRead.ps1`).

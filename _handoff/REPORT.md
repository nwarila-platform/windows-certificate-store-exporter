# Report - STEP 22 SG-6 Docs

## Implemented

- Added SG-6 to `docs/STYLE-GUIDE.md`:
  - soft return for all output-producing functions;
  - domain-named computation with final typed `$Private:Result` handoff;
  - no `Return` / single-exit success flow;
  - flat and pipeline debug anchor shapes;
  - conditional-output and throw-only/enum exemptions;
  - colon-form command parameters with expression-value parentheses;
  - PascalCase PowerShell keywords;
  - analyzer notes for `Measure-SoftReturn`, `Measure-CanonicalNamedBlock`,
    `Measure-CanonicalKeywordCasing`, and disabled `PSUseCorrectCasing`.
- Refreshed the STYLE-GUIDE examples/prose touched by the new rule so they use
  canonical named blocks, keyword casing, soft-return anchors, and colon-form
  `Write-Debug` calls.
- Added ADR `docs/decision-records/repo/0007-sg6-soft-return-and-canonical-call-syntax.md`.
- Updated `docs/decision-records/README.md` with the new repo ADR index row.

## Verification

Command:

`powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`

Result:

- Build completed.
- Analyze passed with 0 findings.
- Pester passed: 87 passed, 0 failed.
- Coverage passed: 95.93% / 90%.
- Six entrypoint exit-code tests passed: Success, Unhandled,
  BelowMinimumCertificateCount, NotWindows, StoreReadFailure, WriteFailure.
- Smoke phase completed successfully (`BuildArtifacts.ps1`, `LiveStoreRead.ps1`).
- `git diff --check` passed.

## Scope Check

- No `src/**`, analyzer, or settings files were changed.
- Tracked docs changed: `docs/STYLE-GUIDE.md`,
  `docs/decision-records/README.md`.
- New docs file: `docs/decision-records/repo/0007-sg6-soft-return-and-canonical-call-syntax.md`.
- Handoff report overwritten: `_handoff/REPORT.md`.
- No push or merge performed.

## Notes / False Premise

- The worktree started on `main`, and no local or remote `codex-sg6-docs` branch
  existed. I created and switched to local branch `codex-sg6-docs` before the final
  report and commit.

# REPORT — SG-8 docs

## Completed

- Added SG-8 to `docs/STYLE-GUIDE.md`: centralized `$Script:Message` table,
  per-function co-located fragments, direct table lookup/formatting at call sites,
  single-quoted hashtable values, namespaced keys, duplicate-key collision
  detection, no inline user-facing `-Message` literals, no message-only
  intermediates, and `Write-Debug` excluded.
- Added ADR `docs/decision-records/repo/0009-sg8-centralized-message-table.md`.
  It records the plain-hashtable mechanism, rejection of `data {}` /
  `ConvertFrom-StringData` for Windows-path backslash safety, rejection of
  localization machinery for this English-only single-file tool, and the DSC
  Community per-resource string-table influence.

## Verification

- No code, analyzer, or settings files changed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
  passed:
  - Build OK.
  - Analyze passed with 0 findings.
  - Pester: 91 passed, 0 failed.
  - Coverage: 96.06% / 90%.
  - Exit-code tests covered six codes.
  - Smoke phase completed successfully.

## Git

- Branch: `codex-sg8-docs`.
- Signed commit created locally.
- Not pushed or merged.

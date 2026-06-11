# Why this layout

This repository consumes `NWarila/powershell-template` for repo guardrails while
staying a single-script project:

- CI runs actionlint, PSScriptAnalyzer, and Pester with coverage.
- Renovate keeps SHA-pinned GitHub Actions current.
- Documentation follows the same Diataxis shape.
- The script remains the only runtime artifact until real exporter behavior is
  added.

# REPORT - Inline EntryPoint exit-code mapping

## Completed

- Inlined the known exporter ErrorId to process exit-code mapping in
  `src/EntryPoint.ps1` inside the existing `Catch` block.
- Deleted the private resolver implementation:
  `src/Private/Resolve-ExitCode.ps1`.
- Deleted the private resolver unit test:
  `tests/Private/Resolve-ExitCode.Tests.ps1`.
- Removed stale source/test/doc references from:
  - `tests/Smoke/BuildArtifacts.ps1`
  - `docs/reference/functions.md`
  - `docs/reference/module-structure.md`
  - `docs/decision-records/template/0002-explicit-attribute-surface-and-design-advisor.md`

## EntryPoint Diff

```diff
 } Catch {
-  $ResolvedExitCode = Resolve-ExitCode -ErrorRecord $PSItem
+  # Map a known exporter ErrorId to its process exit code. The short id is the leading segment
+  #   before the first comma (ThrowTerminatingError appends ",<FunctionName>"). Success/Unhandled and
+  #   unknown ids resolve to $Null, so the Throw below routes them to the trap as unhandled (exit 1).
+  $ShortErrorId = ([System.String]$PSItem.FullyQualifiedErrorId -split ',', 2)[0]
+  $ResolvedExitCode = $Null
+
+  If ([System.Enum]::IsDefined([ExporterExitCode], $ShortErrorId) -eq $True) {
+    $CandidateExitCode = [ExporterExitCode]$ShortErrorId
+
+    If ($CandidateExitCode -notin @([ExporterExitCode]::Success, [ExporterExitCode]::Unhandled)) {
+      $ResolvedExitCode = [System.Int32]$CandidateExitCode
+    }
+  }

   If ($Null -ne $ResolvedExitCode) {
```

## Behavior Checks

- The six subprocess exit-code tests still prove the mapping through the built
  EntryPoint:
  - Success: `0`
  - Unhandled: `1`
  - BelowMinimumCertificateCount: `2`
  - NotWindows: `3`
  - StoreReadFailure: `4`
  - WriteFailure: `5`
- Fail-closed behavior is unchanged: `Success`, `Unhandled`, and unknown ErrorIds
  leave `$ResolvedExitCode` as `$Null`, so the existing `Throw` path routes them
  to the trap as unhandled failures.
- Reference scrub verified for source, tests, docs, and README targets. The only
  retained references are in `_handoff/TASK.md` and this report, which are handoff
  artifacts rather than runtime/source references.

## Verification

- Fresh process command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Task All`
- Result: passed.
- Build: OK.
- Analyze: 0 findings.
- Pester: 89 passed, 0 failed.
- Coverage: 96.1% / 90%.
- Smoke scripts: `BuildArtifacts.ps1` and `LiveStoreRead.ps1` both passed.

## Notes / False Premises

- No behavioral false premise found.

## Git

- Branch: `codex-inline-exitcode`.
- Signed local commit created for the tracked implementation changes.
- Not pushed or merged.

# ADR-template/0002: Maximal-Explicit Function Attribute Surface, Decided by an LLM Design Advisor

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Proposed                                                     |
| Date           | 2026-06-12                                                   |
| Authors        | Nick Warila (@NWarila)                                        |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | Microsoft cmdlet design guidelines (SC02); PoshCode/PowerShellPracticeAndStyle; PSScriptAnalyzer rule docs. |
| Informed       | Consumers that create repositories from this template; the windows-certificate-store-exporter proof-of-concept. |
| Reversibility  | Medium                                                       |
| Review-by      | 2026-09-12                                                   |
| Last reviewed  | 2026-06-12                                                   |

## TL;DR

Every advanced function in house code declares the **full `[CmdletBinding()]`
option surface** — all options present and set with real, owned values, nothing
left implicit — so a reviewer reads each decision on the page instead of inferring
it from a default. Because several of those values, and the prior questions of
**whether a unit should even be an advanced function** (versus a class, enum, or
static method) and **whether a function should accept pipeline input**, are *design
judgments static analysis cannot make*, the house ships a **read-only "PowerShell
function design advisor" skill** that emits an adversarial advisory report per unit.
Its recommendations are consumed adversarially through the existing review loop
(implement/challenge → audit → ratify); the skill never edits code. Mechanically
decidable subsets are enforced by custom PSScriptAnalyzer rules; the rest are
enforced by review. This **deliberately diverges from the minimalist convention**
("omit `CmdletBinding` defaults", PoshCode "do not include empty named blocks"),
trading idiomatic brevity for explicit **auditability**.

## Context and Problem Statement

The first house style rule (SG-1, "variable discipline") quietly conflated two
unrelated concerns: variable hygiene (`$Private:` typing, declare/reset, no
`New-Variable`/`Remove-Variable`) **and** function *shape* (pipeline support and
`begin/process/end` structure). Splitting them exposed a deeper question the style
guide never answered: what is the *correct* attribute and structural surface for a
function, and who decides it?

Two forces collide:

1. **Auditability.** A reviewer of trust-sensitive automation should see every
   binding decision explicitly — is this state-changing (`SupportsShouldProcess`)?
   how risky (`ConfirmImpact`)? does it page, remote, bind positionally? — not have
   to reconstruct it from PowerShell's implicit defaults. The real outlier in the
   proof-of-concept (`New-ErrorRecord`, which spelled out all eight options) read as
   *more* honest than the bare `[CmdletBinding()]` everywhere else, not less.
2. **Decidability.** Many of these are genuine judgments. Whether a unit should be a
   function at all (`Resolve-ExitCode` is really an `enum`; `New-ErrorRecord` is
   really a class factory), whether it should stream the pipeline, and what
   `ConfirmImpact` a state change warrants are not derivable from the AST. Microsoft
   guidance (SC02: "design every cmdlet as if it sits in the middle of a pipeline")
   is *strongly encouraged*, not mechanical; "this should be pipelined" has **no AST
   signal**. Only the consequences are statically checkable (a declared pipeline
   parameter requires a `process` block — the built-in
   `PSUseProcessBlockForPipelineCommand`; a `process` block on a function with no
   pipeline parameter has *no* built-in rule and is open request #1571).

A static linter alone cannot carry this. A human alone does not scale across a
portfolio. The decision is *how* to make these judgments repeatable, evidence-based,
and reviewable.

## Decision Drivers

1. **Auditability over brevity** — every binding decision visible and owned on the page.
2. **Eliminate ambiguity** — no implicit defaults a reader must know to reconstruct intent.
3. **Right construct first** — internal machinery (mappings, value shapes, lookups)
   should be `enum`/`class`/static methods, not advanced functions wearing cmdlet ceremony.
4. **Judgment needs an advisor, not a linter** — capture the reasoning in a skill that
   argues a position well enough to be attacked, then ratify through review.
5. **Evidence, not assertion** — construct/perf determinations can be settled empirically.
6. **Incremental** — land one rule at a time (research → guide → enforce → prove), never a big-bang rewrite.

## Considered Options

1. **Maximal-explicit attribute surface + a read-only LLM design-advisor skill +
   custom PSScriptAnalyzer rules for the mechanical subset** (chosen).
2. **Minimalist idiom** — follow MS/PoshCode: omit `CmdletBinding` defaults, prefer
   the implicit `end` block, no empty named blocks. Rejected: optimizes for brevity
   over the auditability this portfolio values.
3. **Maximal-explicit, enforced purely by static rules.** Rejected: the
   construct/pipelining/impact decisions are not statically decidable, so a
   pure-linter approach would either under-enforce or hard-code wrong guesses.

## Decision Outcome

Chosen option: **Option 1.**

- **The standard.** Every advanced function sets the **six documented advanced-function
  `[CmdletBinding()]` options** explicitly with real values, plus `[OutputType]`:
  `SupportsShouldProcess`, `ConfirmImpact`, `PositionalBinding`,
  `DefaultParameterSetName`, `HelpUri`, `SupportsPaging` — values per SG-4. (Amended
  2026-06-12: the original "all eight" was wrong. `SupportsTransactions` is "not
  supported in advanced functions" per Microsoft, and `RemotingCapability` is absent
  from the advanced-function `CmdletBinding` syntax block — both are compiled-cmdlet-only
  attributes. The house does **not** set them on functions: doing so is undocumented dead
  metadata, the same placeholder bloat we removed from `New-ErrorRecord`.) Settled values:
  `PositionalBinding = $false` (named-only — most auditable); `SupportsShouldProcess`
  maximized to every state-changing function (with a real `ShouldProcess` call) and
  `$false` on pure readers; `ConfirmImpact` risk-based on state-changers / `None` on
  readers; `SupportsPaging = $false` unless the function genuinely pages;
  `DefaultParameterSetName = 'default'` (verified benign on single-set functions);
  `HelpUri` a per-function deep-link to that function's reference anchor; `[OutputType]`
  the real output type.
- **The advisor.** A read-only **PowerShell function design advisor** skill (in
  `…/GitHub/skills/`) produces, per unit, an adversarial advisory report answering in
  order: (1) **construct** — advanced function / class / enum / static method
  (a hard signal: code that must call `$PSCmdlet.ThrowTerminatingError` keeps a
  function context; pure construction does not); (2) **pipelining** — should it
  stream input, which drives `ValueFromPipeline` + `begin/process/end`; (3) the
  correct value of each `CmdletBinding` option, each with a one-line reason.
- **Consumption is adversarial.** Recommendations flow through the existing loop
  (Codex implements/challenges → Claude audits → owner ratifies). **The skill never
  edits files or opens PRs.**
- **Enforcement split.** Mechanically decidable rules become custom PSScriptAnalyzer
  rules (Severity Warning, gating CI; the house settings gate on Error + Warning);
  judgment-only rules are enforced by review and recorded in the style guide.
- **Evidence.** `uditgoenka/autoresearch` (an autonomous iterate-on-a-metric loop) is
  the harness to settle construct/perf determinations empirically — metric = dispatch
  time / behavior, verify = the existing Pester suite stays green.
- **Cadence.** Rules accrete **one at a time** into the single growing
  `docs/STYLE-GUIDE.md` (not one ADR per rule). The first rule under this ADR is
  **construct + pipelining**; the seven remaining `CmdletBinding` options each land as
  their own researched rule afterward.
- **Proof-of-concept.** `windows-certificate-store-exporter` is the living
  conformance test: every rule must reach **0 findings** there, or it is not ready.

## Relationship to External Guidance (honest divergence)

- **Aligns** with Microsoft SC02 on pipelining: prefer functions that can sit in the
  middle of a pipeline; expose pipeline input where the unit has a primary input object.
- **Diverges**, deliberately and *narrowly*, from the minimalist *"omit defaults"*
  convention: the common idiom drops `CmdletBinding` options equal to their default;
  the house sets all of them explicitly anyway, for auditability.
- Note the house does **not** violate PoshCode's "do not include empty named blocks":
  under the construct + pipelining rule, pipeline functions carry real content in
  every block (typed variable initialization in `begin` per the variable-discipline
  rule, work in `process`) and non-pipeline units are flat (no named blocks at all),
  so no block is ever empty. The single, eyes-open divergence is **explicit defaults
  over brevity** — a values choice (auditability > terseness), not an oversight.

## Confirmation

1. Each landed rule has a custom PSScriptAnalyzer rule **where the rule is
   mechanically decidable**, plus a rule self-test (fires on a violation fixture,
   passes clean idiom).
2. The proof-of-concept repo passes that rule at **0 findings**.
3. The advisor skill's output is **reviewed, never auto-applied**; no recommendation
   lands without an audited PR.
4. The shared `STYLE-GUIDE.md`, settings, and analyzer module stay **byte-identical**
   across the template and consuming repos.

## Pros and Cons of the Options

### Option 1 — explicit surface + advisor + PSSA (chosen)

- **Good, because** every binding decision is visible, owned, and diffable.
- **Good, because** judgment lives in a skill that is *designed to be attacked*, then ratified.
- **Good, because** the mechanical subset still gates CI; nothing rests on vigilance alone.
- **Good, because** construct/perf claims can be backed by autoresearch evidence.
- **Bad, because** functions are more verbose than the idiomatic minimum.
- **Bad, because** the advisor is judgment, so it requires human ratification and can be wrong.

### Option 2 — minimalist idiom

- **Good, because** it matches community guidance and is terse.
- **Bad, because** intent is implicit; a reviewer must know the defaults to audit a function.

### Option 3 — maximal-explicit, static-only

- **Good, because** fully automated, no skill.
- **Bad, because** the core decisions (construct, pipelining, impact) are not statically
  decidable; the linter would hard-code wrong guesses or stay silent on what matters most.

## Consequences

### Positive

- Function intent is auditable on the page; no implicit defaults to reconstruct.
- Wrong constructs (functions that should be enums/classes) are caught by design, not chance.
- Determinations are repeatable and, where it matters, evidence-backed.

### Negative

- More ceremony per function than the idiomatic minimum.
- The advisor is an LLM judgment surface that must be reviewed, not trusted.
- Class/enum refactors carry Windows PowerShell 5.1 / .NET Framework caveats
  (definition-order in the concatenated build, `$PSCmdlet`/`ThrowTerminatingError`
  coupling, Pester mockability and code-coverage of class methods) that each
  conversion must re-verify.

### Neutral

- This splits SG-1: variable discipline remains its own rule; function *shape*
  (construct + pipelining) moves under this ADR's first rule.

## Assumptions

1. The portfolio values explicit auditability over idiomatic brevity for trust-sensitive automation.
2. An LLM advisor plus adversarial human review is more scalable and consistent than ad hoc per-function judgment.
3. Windows PowerShell 5.1 remains the runtime floor; class/enum behavior is verified there, not assumed.

## Supersedes

None. (Refines and splits the SG-1 rule; does not retire it.)

## Superseded by

None (current).

## Implementing PRs

- Pending: the construct + pipelining rule (style guide + custom PSScriptAnalyzer
  rule + proof-of-concept retrofit) and the design-advisor skill stub.

## Related ADRs

- Builds on: [docs/decision-records/template/0001-module-layout.md](0001-module-layout.md)
- Style guide: [docs/STYLE-GUIDE.md](../../STYLE-GUIDE.md)

## Compliance Notes

The divergence from PoshCode "no empty named blocks" / "omit defaults" is intentional
and is recorded above under *Relationship to External Guidance*. Reviewers should not
"correct" house code toward the minimalist idiom on the basis of that external guidance.

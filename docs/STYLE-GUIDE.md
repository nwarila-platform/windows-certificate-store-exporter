# PowerShell House Style Guide

Canonical in `NWarila/powershell-template`; mirrored byte-identical into consuming
repositories (alongside `PSScriptAnalyzerSettings.psd1` and the custom analyzer
rules). Each rule here is **machine-enforced where mechanically decidable** by a
PSScriptAnalyzer rule so it gates CI — the guide explains intent; the analyzer is
the source of truth for pass/fail. Clauses that are design *judgments* with no AST
signal are marked **[judgment]** and are enforced by review instead: the
`powershell-function-design-advisor` skill argues a recommendation, and the
adversarial loop (implement/challenge → audit → owner ratifies) decides.
Foundational decision: ADR-template/0002.

Severity convention: house rules are **Warning** (the settings file gates on
`Error` + `Warning`, so a Warning fails CI).

---

## SG-1 — Variable scope discipline (Private by default; wider scope only by explicit declaration)

**Intent.** Minimize variable scope creep. Every variable lives in the **narrowest
scope that works** — and when a wider scope is genuinely needed, that choice is
**declared explicitly** so it reads as a decision, never an accident.

**Rule.**

1. **Default: `$Private:`.** A variable a function creates is declared with a typed
   `$Private:` assignment — `[System.String]$Private:X = [System.String]::Empty` —
   so it cannot leak into child scopes.
2. **Wider scope when needed — allowed, but explicit.** When a variable genuinely
   requires a wider scope, omit `Private` and declare the scope it actually needs:
   - `$Local:X` — child scriptblocks must *inherit/read* the value (the one thing
     `Private` forbids);
   - `$Script:X` — deliberate script-level state (e.g. shared constants).
   A **bare, unscoped creation** (`$X = …`) is the only prohibited form: it is
   indistinguishable from a forgotten `Private` and hides the scope decision.
3. **Placement** follows the shape SG-2 assigns: pipeline-capable functions
   **declare** locals in `Begin` and **reset** them at the top of `Process` (direct
   assignment to the typed default, so state resets between piped items); flat
   functions declare locals inline.
4. **No `New-Variable`** for locals (slower, honors `-WhatIf` inside
   `SupportsShouldProcess` functions, adds ceremony without type safety) and **no
   `Remove-Variable`** cleanup (the scope disposes itself; explicit removal is
   runtime cost for no effect — a deliberate correction of the older targetstate
   reference sample).

**Exempt:** parameters, PowerShell automatic variables (`$PSItem`, `$_`,
`$PSCmdlet`, `$true`/`$false`/`$null`, `$args`, `$matches`, …), `For`/`ForEach`
loop induction variables, and `Process`-top **resets** of a `Begin`-declared
`$Private:` variable (the reset re-assigns; it does not create).

**Why.** Scope creep is the enemy: a variable readable where it has no business
being read is a latent bug and an audit burden. `Private`-by-default gives every
variable the smallest possible blast radius; the explicit-modifier escape hatch
keeps the rare wider-scope need legal while making it visible in the diff.

**Note (verified).** Private-scoped variables remain usable for *mutation* inside
`ForEach-Object` blocks (e.g. `$list.Add(...)`); Private affects child-scope
*inheritance*, not reading a reference to mutate it. Reassignment (`$x += …`)
inside `ForEach-Object` is a separate PowerShell scoping pitfall and is not made
worse by this rule.

**Enforced by:** custom analyzer rules (Warning) — see the rules module wired via
`CustomRulePath` in `PSScriptAnalyzerSettings.psd1`:
- a rule that flags any **bare, unscoped** function-local creation (`$X = …`) —
  explicit `$Private:` / `$Local:` / `$Script:` declarations all pass;
- a rule that, for pipeline-capable functions, flags locals not declared in
  `Begin` or not reset at the top of `Process`;
- a rule that flags `Remove-Variable` used as end-of-scope cleanup;
- a rule that flags `New-Variable` used for local declarations inside functions.

### Example (pipeline-capable)

```powershell
Function ConvertTo-Thing {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/<org>/<repo>/blob/main/docs/reference/functions.md#convertto-thing',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [System.String]
    $InputValue
  )
  Begin {
    Write-Debug -Message:'[ConvertTo-Thing] Entering Begin'

    # Initialize Variable(s)
    [System.String]$Private:ConvertedValue = [System.String]::Empty
    [System.String]$Private:Result = [System.String]::Empty

    Write-Debug -Message:'[ConvertTo-Thing] Exiting Begin'
  } Process {
    Write-Debug -Message:'[ConvertTo-Thing] Entering Process'

    # Reset Variable(s)
    $ConvertedValue = [System.String]::Empty
    $Result = [System.String]::Empty

    $ConvertedValue = $InputValue.ToUpperInvariant()
    [System.String]$Result = $ConvertedValue
    $Result

    Write-Debug -Message:'[ConvertTo-Thing] Exiting Process'
  }
}
```

(No `End` block: named blocks are written only when they carry real content —
an empty `End { }` is exactly the ceremony SG-2 prohibits.)

### Example (flat function — no pipeline parameter, no named blocks)

```powershell
Function Get-Thing {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/<org>/<repo>/blob/main/docs/reference/functions.md#get-thing',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Object[]])]
  Param ()
  Write-Debug -Message:'[Get-Thing] Entering'

  # Initialize Variable(s)
  [System.Collections.Generic.List[object]]$Private:Items = [System.Collections.Generic.List[object]]::new()
  [System.Object[]]$Private:Result = @()

  [void]$Private:Items.Add('a')
  [void]$Private:Items.Add('b')

  [System.Object[]]$Result = $Items.ToArray()
  $Result

  Write-Debug -Message:'[Get-Thing] Exiting'
}
```

---

## SG-2 — Function construct & shape (right construct first; pipeline-or-flat)

Decide what a unit **is** before styling how it looks. Three clauses, applied in
order — the first can eliminate the later two.

### 2a. Construct — should this even be an advanced function? **[judgment]**

A unit is an advanced function only if it is a genuine cmdlet-style **operation**:
verb-noun, acts on objects, user- or pipeline-facing (`Export-…`, `ConvertTo-…`,
`Get-…`, `Select-…`). Internal machinery is not a function:

- a fixed set of named integer values → **`enum`** (e.g. an ErrorId→exit-code map
  whose identifier strings already mirror the codes);
- a stateless factory, transform, or value shape → **`class`** (static methods).

**Hard signal:** code that needs cmdlet context — `$PSCmdlet.ThrowTerminatingError`,
`ShouldProcess`, or a body that tests must `Mock` — stays a function. Pure
construction does not (create in a class factory; throw at the call site, which has
the `$PSCmdlet`).

Construct recommendations come from the `powershell-function-design-advisor` skill
(ADR-template/0002) and are consumed adversarially; contested calls are settled
empirically with the autoresearch harness (mechanical metric + Pester-green verify).
Every class/enum conversion on the Windows PowerShell 5.1 floor must re-verify:
definition order in concatenated builds; `FullyQualifiedErrorId` leading-segment
preservation when a throw moves; Pester mockability and code-coverage of class
statics.

### 2b. Pipelining — should the function stream input? **[judgment, default ON]**

A function with a logical **primary-input object or collection it acts on per item**
SHOULD accept pipeline input (Microsoft SC02: implement every cmdlet as if it sits
in the *middle* of a pipeline):

- `ValueFromPipeline` when the function consumes the **whole object** (binds by type);
- `ValueFromPipelineByPropertyName` when it needs a **property** (binds by name/alias).

Functions with no per-item input story (orchestrators, whole-set aggregating
writers) take no pipeline input — and are frequently 2a candidates to not be
functions at all. "Should this be pipelined" has **no AST signal**; the analyzer
stays silent here by design, and review carries it.

### 2c. Shape follows pipelining **[mechanical — analyzer-enforced]**

- A function that **declares a pipeline parameter MUST handle it in `Process`**
  (built-in `PSUseProcessBlockForPipelineCommand`; without a `Process` block the
  function executes once and binds only the **last** piped item) and MUST emit
  per-item output from `Process` — genuine aggregators that collect in `Process`
  and emit a single result from `End` are the documented exception.
- A function that **declares NO pipeline parameter MUST NOT use
  `Begin`/`Process`/`End` at all.** Code runs in the implicit `End` block; locals
  are declared inline per SG-1. Named blocks on a non-pipeline function are pure
  ceremony: a direct call runs `Process` exactly once, so the blocks change
  nothing and only obscure whether the function actually streams. (No built-in
  rule covers this inverse — PSScriptAnalyzer issue #1571 — hence the custom house
  rule.)
- Empty named blocks are prohibited in all cases (aligned with the PoshCode
  guidance "do not include empty named blocks"); under SG-1 every block a pipeline
  function keeps carries real content (`Begin` = typed initialization, `Process`
  = work), so this falls out naturally.

**Why.** The construct question removes cmdlet ceremony from code that was never a
cmdlet; the pipeline default keeps real operations composable (the reason the shell
exists); and shape-follows-pipelining makes a function's streaming contract visible
at a glance — `Begin`/`Process`/`End` present *means* "this streams", absent *means*
"this is a single-shot call". Ambiguity is the enemy.

**Enforced by:**
- built-in `PSUseProcessBlockForPipelineCommand` (Warning) — pipeline parameter
  handled outside `Process`;
- custom rule `Measure-FlatNonPipelineFunction` (Warning) — any
  `Begin`/`Process`/`End`/`DynamicParam` block on a function whose `Param` block
  declares no `ValueFromPipeline`/`ValueFromPipelineByPropertyName` parameter;
- custom rule `Measure-CanonicalNamedBlock` (Warning) — named blocks must use
  canonical `Begin`/`Process`/`End` spelling and cuddled block transitions;
- 2a and 2b are **[judgment]** — review-enforced via the advisor skill; the
  analyzer is intentionally silent.

> **Attribute surface (pointer).** ADR-template/0002 also fixes the
> maximal-explicit `[CmdletBinding()]` standard — every option present with a real,
> owned value (`ConfirmImpact` always stated, `DefaultParameterSetName = 'default'`,
> …) plus `[OutputType]`. SG-4 has landed, so the examples above intentionally show
> the full explicit surface instead of the historical bare form.

---

## SG-3 — One True Brace Style (OTBS) **[mechanical — analyzer-enforced]**

**Rule.** All braceable statements use **One True Brace Style**:

- the **opening brace** sits at the **end of the construct's line** (`Function X {`,
  `If (…) {`, `ForEach (…) {`, `Try {`, `Process {`);
- the **closing brace** sits at the **start of its own line**;
- `Else` / `ElseIf` / `Catch` / `Finally` are **cuddled** to the preceding closing
  brace — `} Else {`, `} ElseIf (…) {`, `} Catch {`, `} Finally {` — never on a line
  of their own.

One-line blocks are **allowed** (e.g. `$x = If ($c) { 'a' } Else { 'b' }`,
`ForEach ($i In $set) { $list.Add($i) }`); they are exempt from brace placement.
Braces themselves are not optional — PowerShell's grammar already requires them for
`If`/`While`/`ForEach`/etc. (`If ($x) Do-Thing` is a syntax error), so there is no
"always-braces" choice to make.

**Why.** OTBS is the PowerShell community-idiomatic default (PoshCode
PowerShellPracticeAndStyle recommends it by name): script-block callers
(`ForEach-Object { … }`, `Where-Object { … }`, DSC) force same-line opening braces, so
OTBS is the only brace style consistent across every construct the language has.
Cuddled branch keywords keep an `If`/`Else` or `Try`/`Catch` reading as one unit instead of
visually splitting it. (This is an **alignment** with community guidance, not a house
divergence.)

**The one easy-to-get-wrong setting.** Cuddling is enforced by `PSPlaceCloseBrace`
**only when `NewLineAfter = $false`**. At the rule's *default* `$true`, the analyzer
forces a newline after every closing brace and actively **breaks** cuddling (producing
the Stroustrup form). There is no dedicated "cuddled branch" property; `NewLineAfter =
$false` is the lever (its `GetViolationsForUncuddledBranches` path flags uncuddled
`Else`/`ElseIf`/`Catch`/`Finally`). Ref: PSScriptAnalyzer issue #754 (Closed/Fixed).

**Enforced by** the built-in formatting rules (Warning), configured in
`PSScriptAnalyzerSettings.psd1` — no custom rule needed:

```powershell
PSPlaceOpenBrace  = @{ Enable = $true; OnSameLine = $true; NewLineAfter = $true; IgnoreOneLineBlock = $true }
PSPlaceCloseBrace = @{ Enable = $true; NewLineAfter = $false; IgnoreOneLineBlock = $true; NoEmptyLineBefore = $false }
PSUseConsistentIndentation = @{ Enable = $true; Kind = 'space'; IndentationSize = 2 }
PSUseConsistentWhitespace = @{
  Enable                                   = $true
  CheckInnerBrace                          = $true
  CheckOpenBrace                           = $true
  CheckOpenParen                           = $true
  CheckOperator                            = $true
  CheckParameter                           = $true
  CheckPipe                                = $true
  CheckSeparator                           = $true
  IgnoreAssignmentOperatorInsideHashTable = $true
}
PSAlignAssignmentStatement = @{ Enable = $true; CheckEnums = $false; CheckHashtable = $true }
```

`Invoke-Formatter` can drive a bulk reformat from the same settings, but it has known
edge bugs around branch placement (half-cuddled `Else`, no inter-statement newline
insertion — issues #508, #794), so any auto-reformat must be re-linted and the
`Else`/`Catch`/`Finally` sites eyeballed. Operator, pipe, and parameter spacing are
also formatter-enforced; the hashtable assignment carve-out is deliberate so aligned
hashtables continue to satisfy `PSAlignAssignmentStatement`. Enum member alignment is
disabled because `CheckOperator` owns assignment-operator spacing outside hashtables.

---

## SG-4 — Maximal-explicit `[CmdletBinding()]` surface (ADR-template/0002)

**Rule.** Every advanced function declares the **six documented advanced-function
`CmdletBinding` options explicitly**, plus `[OutputType]` — nothing left implicit, so a
reviewer reads every binding decision on the page. Auditability over brevity (a
deliberate, recorded divergence from the minimalist "omit defaults" idiom).

The six (and **only** these — `SupportsTransactions` and `RemotingCapability` are
compiled-cmdlet-only attributes, **not** documented for advanced functions, and are
**not** set; doing so is undocumented dead metadata):

| Option | House value | Nature |
| --- | --- | --- |
| `PositionalBinding` | **`$false`** — named-only; callers must name every argument | mechanical constant; *breaking* for positional call sites (convert them) |
| `SupportsShouldProcess` | **`$true`** on every function with a real side effect; it must EITHER call `$PSCmdlet.ShouldProcess(...)` directly OR **delegate** to a single downstream `ShouldProcess` call site (an orchestrator exposes `-WhatIf`/`-Confirm` and lets the preference flow down to one writer — never calling `ShouldProcess` itself, to avoid double prompts). **`$false`** on pure readers | **[judgment]** — maximize to the greatest *logical* extent; also part-governed by the built-in `PSUseShouldProcessForStateChangingFunctions` verb rule |
| `ConfirmImpact` | risk-based `Low`/`Medium`/`High` on state-changers; **`None`** on readers (honest — it is inert without `SupportsShouldProcess`) | **[judgment]** — follows `SupportsShouldProcess` |
| `SupportsPaging` | **`$false`** unless the function genuinely emits a large pageable set and honors `$PSCmdlet.PagingParameters` | **[judgment]**, almost always `$false` |
| `DefaultParameterSetName` | **`'default'`** (verified benign on single-set functions — no error/warning) | mechanical constant |
| `HelpUri` | a **per-function deep-link** to that function's reference anchor (`<repo>/docs/reference/<page>#<function-anchor>`) | mechanical; requires the anchor to exist (authored per function) |
| `[OutputType]` | the function's real output type | mechanical |

**Why.** Trust-sensitive automation should make every binding decision visible and
owned, not inferred from a default. `PositionalBinding = $false` forces named arguments
(no positional guessing at call sites). Maximal `SupportsShouldProcess` gives every
state-changing operation `-WhatIf`/`-Confirm` for free — but only where it's *logical*:
a function that changes nothing must not declare it (the auto-injected `-WhatIf`/`-Confirm`
would silently do nothing — a UX hazard).

**Cautions (from the research):**
- `PositionalBinding = $false` is **behavioral**, not cosmetic — it rejects positional
  calls. Fix any positional call sites in the retrofit.
- `SupportsShouldProcess = $true` **requires** an actual `$PSCmdlet.ShouldProcess(...)`
  in the body; setting it without calling it adds dead `-WhatIf`/`-Confirm`.
- `ConfirmImpact`/`SupportsShouldProcess` **values are judgment** (the
  `powershell-function-design-advisor` skill recommends them; review ratifies). The rule
  below enforces only that the options are **present**.

**Enforced by** a custom rule **`Measure-ExplicitCmdletBinding`** (Warning): walks each
`FunctionDefinitionAst`, finds the `[CmdletBinding]` `AttributeAst`, and flags it unless
all six options are present in `AttributeAst.NamedArguments` (and `[OutputType]` is
present). It enforces **presence**, not values — values are the advisor's/review's job,
except `SupportsShouldProcess` which the built-in `PSUseShouldProcessForStateChangingFunctions`
also checks against the verb. (No built-in rule requires option presence;
`PSUseOutputTypeCorrectly` is Information-only and merely *validates* a declared type.)

---

## SG-5 — Canonical (alphabetical) ordering of the attribute/parameter surface **[mechanical — analyzer-enforced]**

**Rule.** The declaration surface of every advanced function is ordered deterministically
so diffs and reviews are stable. Four clauses:

- **(a) `CmdletBinding` options** appear in **alphabetical** order:
  `ConfirmImpact, DefaultParameterSetName, HelpUri, PositionalBinding, SupportsPaging, SupportsShouldProcess`.
- **(b) `[Parameter(...)]` named arguments** appear in **alphabetical** order
  (`DontShow, Mandatory, ParameterSetName, ValueFromPipeline,
  ValueFromPipelineByPropertyName` per SG-7).
- **(c) Attributes on a parameter** appear in this canonical order:
  `[Parameter(...)]` → `[Alias(...)]` → validation/transformation attributes
  (`[Validate*]`, etc., **alphabetical** among themselves) → **the type literal** →
  the variable. **The type literal MUST be last** (immediately before `$Var`).
- **(d) The parameters themselves** appear in **alphabetical order by name**.

**Behavioral safety (why this is allowed).** (a) and (b) are .NET *named attribute
arguments* — order-independent by language definition, purely cosmetic. (c) is cosmetic
among attributes, with **one hard behavioral constraint**: a validation attribute placed
*after* the type validates the **pre-conversion** value and can throw a spurious
`MetadataError`; Microsoft prescribes **attribute-before-type**, so "type last" is a
*correctness* rule, not just style. (d) reordering parameters is **binding-safe only
because the house mandates `PositionalBinding = $false` (SG-4) with no explicit
`Position` and single parameter sets** — under those conditions declaration order does
not drive binding. Accepted tradeoff: alphabetical parameters also reorder the
`Get-Help` parameter listing and `$PSBoundParameters` enumeration (cosmetic, not
behavioral).

**Guard (the rule must respect this).** If a function ever declares an explicit
`Position` on any parameter, or multiple parameter sets (`ParameterSetName` on
parameters), or `PositionalBinding = $true`, then **parameter order is load-bearing** —
clause (d) does NOT apply to that function and the rule must exempt it. (a)/(b)/(c) still
apply. House code currently has none of these.

**Why.** Alphabetical is a deterministic canonical order, so two authors produce
byte-identical declarations and reviews see only real changes — the same auditability
goal as the maximal-explicit surface. (Neither Microsoft nor PoshCode prescribes
alphabetical ordering; it's a deliberate house convention, safe per the classification
above.)

**Enforced by** a custom rule **`Measure-CanonicalAttributeOrder`** (Warning). Via the
AST: `AttributeAst.NamedArguments` must be alphabetical (a, b); within each
`ParameterAst.Attributes`, no `[Validate*]`/transform `AttributeAst` may follow the
`TypeConstraintAst`, and `[Parameter]`→`[Alias]`→`[Validate* alphabetical]`→type order
holds (c); `ParamBlockAst.Parameters` names must be alphabetical **unless** the
function trips the Guard above (d). No built-in rule covers any of this.

---

## SG-6 — Soft return and canonical token surface **[mechanical where decidable — analyzer-enforced]**

See [ADR-repo/0007](decision-records/repo/0007-sg6-soft-return-and-canonical-call-syntax.md)
for the accepted rationale and trade-offs.

**Intent.** Every output-producing function keeps its domain result traceable until
the final handoff, emits a single explicitly typed `$Private:Result`, and flows
through the trailing `Write-Debug '... Exiting ...'` breakpoint anchor. The same rule
set also fixes two house-level readability choices: colon-form command parameters
and canonical PascalCase PowerShell keywords.

**Rule.**

1. **Domain-named computation, typed result.** Output-producing functions compute
   into meaningful domain variables (`$HashString`, `$StoreCertificates`,
   `$SelectedCertificates`) until the final handoff. Declare
   `[<OutputType>]$Private:Result = <typed default>` in the SG-1 initialization
   location; pipeline functions reset `$Result` at the top of `Process` with their
   other Begin-declared locals. Immediately before emitting, assign the final domain
   value into an explicitly typed result: `[<OutputType>]$Result = $DomainValue`.
2. **Soft return, single-exit.** Emit bare `$Result` on its own line immediately
   after the final typed handoff. Do not use `Return` anywhere in a function,
   including guard/early-exit returns; restructure guards so control reaches the
   trailing debug anchor. Loop-local `Continue`/`Break` are fine. Conditional-output
   functions emit `$Result` only in producing branches, while the trailing debug
   anchor still executes on every non-terminating path.
3. **`Write-Debug` anchor.** Flat functions start with
   `Write-Debug -Message:'[<Function>] Entering'` and end with
   `Write-Debug -Message:'[<Function>] Exiting'`; `$Result` is emitted immediately
   before the Exiting line. Pipeline functions put
   `Write-Debug -Message:'[<Function>] Entering <Block>'` first in each named block,
   reset `Process` variables immediately after the `Entering Process` anchor, and
   end each named block with the matching `Exiting <Block>` anchor.
4. **Colon-form parameters.** Command calls bind named parameters as `-Name:Value`.
   Parenthesize expression values (`-ErrorId:([ExporterExitCode]::Unhandled)`) so the
   colon binder cannot greedily consume more than intended. Self-delimiting values
   need no parentheses: simple variables (`-Certificate:$PSItem`), literals, and
   scriptblocks (`-Process:{ ... }`, not `-Process:({ ... })`). There is no space
   after the colon. Switches may be explicit (`-IsFatal:$True`).
5. **PascalCase keywords.** PowerShell keywords use the canonical house spelling:
   `Function`, `Param`, `Begin`, `Process`, `End`, `If`, `ElseIf`, `Else`, `ForEach`,
   `For`, `While`, `Do`, `Switch`, `Try`, `Catch`, `Finally`, `Throw`, `Trap`,
   `Exit`, `Enum`, `DynamicParam`, and the other tokenized language keywords.
   Operators and variable names are unaffected.

**Exempt.** Functions that never emit pipeline output, such as terminating-error
helpers that only throw, do not soft-return. Type definitions such as enums are also
outside the soft-return rule. Terminating-error paths are not required to reach the
success-path Exiting anchor.

**Why.** The Exiting line is a reliable end-of-function breakpoint with all locals,
including the typed result, still in scope. Domain-named locals make the calculation
auditable; the final typed `$Result` makes the emitted shape explicit; single-exit
control flow keeps the debug anchor meaningful.

**Trade-off.** PascalCase keywords and colon-form parameters are non-idiomatic house
preferences. Community examples and `PSUseCorrectCasing` prefer lowercase keywords,
and colon-form has a real greedy-binding hazard. The house accepts those costs for
TargetState fidelity and auditability, with the parenthesize-expression guard as the
safe subset for colon-form calls.

**Enforced by:**

- custom rule `Measure-SoftReturn` (Warning) — flags `Return` inside functions and
  missing trailing `Write-Debug '... Exiting ...'` anchors where mechanically
  decidable;
- custom rule `Measure-CanonicalNamedBlock` (Warning) — named-block spelling and
  cuddled `} Process {` / `} End {` transitions;
- custom rule `Measure-CanonicalKeywordCasing` (Warning) — PascalCase keyword
  spelling;
- built-in `PSUseCorrectCasing` is disabled because it is incompatible with the
  house PascalCase keyword convention; house rules own keyword casing instead;
- colon-form parameter use is review-backed because the safe subset is not
  currently machine-enforced.

### Example (flat)

```powershell
Function Get-Thing {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/<org>/<repo>/blob/main/docs/reference/functions.md#get-thing',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  Param ()
  Write-Debug -Message:'[Get-Thing] Entering'

  # Initialize Variable(s)
  [System.String]$Private:Name = [System.String]::Empty
  [System.String]$Private:Result = [System.String]::Empty

  $Name = 'thing'
  [System.String]$Result = $Name
  $Result

  Write-Debug -Message:'[Get-Thing] Exiting'
}
```

### Example (pipeline)

```powershell
Process {
  Write-Debug -Message:'[ConvertTo-Thing] Entering Process'

  # Reset Variable(s)
  $ConvertedValue = [System.String]::Empty
  $Result = [System.String]::Empty

  $ConvertedValue = $InputValue.ToUpperInvariant()
  [System.String]$Result = $ConvertedValue
  $Result

  Write-Debug -Message:'[ConvertTo-Thing] Exiting Process'
}
```

---

## SG-7 — Explicit parameter surface **[mechanical — analyzer-enforced]**

See [ADR-repo/0008](decision-records/repo/0008-sg7-explicit-parameter-surface.md)
for the accepted rationale and Microsoft-source references.

**Rule.** Every parameter declares exactly one `[Parameter(...)]` attribute with
exactly five named arguments, in SG-5 alphabetical order:

1. `DontShow`
2. `Mandatory`
3. `ParameterSetName`
4. `ValueFromPipeline`
5. `ValueFromPipelineByPropertyName`

Values are **per-parameter** and behavior-preserving: `Mandatory`,
`ValueFromPipeline`, and `ValueFromPipelineByPropertyName` are `$True` only where the
parameter actually has that binding contract; otherwise they are explicitly
`$False`. `ParameterSetName` is `'default'` for the current single-set house model.
`DontShow` is `$False` except for a deliberately hidden test seam.

**Forbidden.** Do not declare `Position`, `HelpMessage`, or
`ValueFromRemainingArguments` in `[Parameter(...)]`.

**Exempt.** The `$StoreFactory` test seam in `Get-StoreCertificate` uses
`DontShow = $True` because it exists only for deterministic tests and is not a CLI
surface. The seam still declares the other four SG-7 options explicitly.

**Why.** The explicit five-option surface is an auditability house preference.
Declaring a Boolean option at its default value is binding-equivalent to omitting it,
so `Mandatory = $False`, `ValueFromPipeline = $False`, and
`ValueFromPipelineByPropertyName = $False` are not behavior changes. In this
single-parameter-set project, `ParameterSetName = 'default'` makes the house set
visible without adding an alternate binding path.

The forbid-list is correctness, not taste:

- `Position` is prohibited because it overrides `CmdletBinding(PositionalBinding =
  $False)`: any declared parameter position re-enables positional binding for that
  parameter.
- `ValueFromPipelineByPropertyName` is a per-parameter choice. Blanket `$True`
  accepts matching object properties or aliases by name, which can silently bind a
  property the function did not intend to consume.
- `HelpMessage` duplicates the comment-based `.PARAMETER` help used by this repo and
  only adds interactive value at the mandatory-parameter `!?` prompt.
- `ValueFromRemainingArguments` is a catch-all positional capture mechanism, and this
  project has no remaining-argument surface.

**Enforced by:**

- custom rule `Measure-ExplicitParameterAttribute` (Warning) — every parameter must
  have `[Parameter(...)]`, must declare the five SG-7 options, and must not declare
  the SG-7 forbid-list;
- custom rule `Measure-CanonicalAttributeOrder` (Warning) — the five options must
  stay in SG-5 alphabetical order.

### Example

```powershell
[Parameter(
  DontShow = $False,
  Mandatory = $True,
  ParameterSetName = 'default',
  ValueFromPipeline = $False,
  ValueFromPipelineByPropertyName = $False
)]
[ValidateNotNullOrEmpty()]
[System.String]
$Path
```

### Example (hidden test seam)

```powershell
[Parameter(
  DontShow = $True,
  Mandatory = $False,
  ParameterSetName = 'default',
  ValueFromPipeline = $False,
  ValueFromPipelineByPropertyName = $False
)]
[ValidateNotNull()]
[System.Management.Automation.ScriptBlock]
$StoreFactory
```

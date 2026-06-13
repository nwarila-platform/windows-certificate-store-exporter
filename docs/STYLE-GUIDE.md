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
   **declare** locals in `begin` and **reset** them at the top of `process` (direct
   assignment to the typed default, so state resets between piped items); flat
   functions declare locals inline.
4. **No `New-Variable`** for locals (slower, honors `-WhatIf` inside
   `SupportsShouldProcess` functions, adds ceremony without type safety) and **no
   `Remove-Variable`** cleanup (the scope disposes itself; explicit removal is
   runtime cost for no effect — a deliberate correction of the older targetstate
   reference sample).

**Exempt:** parameters, PowerShell automatic variables (`$PSItem`, `$_`,
`$PSCmdlet`, `$true`/`$false`/`$null`, `$args`, `$matches`, …), `for`/`foreach`
loop induction variables, and `process`-top **resets** of a `begin`-declared
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
  `begin` or not reset at the top of `process`;
- a rule that flags `Remove-Variable` used as end-of-scope cleanup;
- a rule that flags `New-Variable` used for local declarations inside functions.

### Example (pipeline-capable)

```powershell
function ConvertTo-Thing {
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [System.String]
        $InputValue
    )
    begin {
        Write-Debug -Message '[ConvertTo-Thing] Entering Begin'

        # Initialize Variable(s)
        [System.String]$Private:Result = [System.String]::Empty

        Write-Debug -Message '[ConvertTo-Thing] Exiting Begin'
    }
    process {
        $Result = [System.String]::Empty
        $Result = $InputValue.ToUpperInvariant()
        $Result
    }
}
```

(No `end` block: named blocks are written only when they carry real content —
an empty `end { }` is exactly the ceremony SG-2 prohibits.)

### Example (flat function — no pipeline parameter, no named blocks)

```powershell
function Get-Thing {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param ()
    [System.Collections.Generic.List[object]]$Private:Items = [System.Collections.Generic.List[object]]::new()
    foreach ($Name in 'a', 'b') { $Private:Items.Add($Name) }
    , $Private:Items.ToArray()
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

- A function that **declares a pipeline parameter MUST handle it in `process`**
  (built-in `PSUseProcessBlockForPipelineCommand`; without a `process` block the
  function executes once and binds only the **last** piped item) and MUST emit
  per-item output from `process` — genuine aggregators that collect in `process`
  and emit a single result from `end` are the documented exception.
- A function that **declares NO pipeline parameter MUST NOT use
  `begin`/`process`/`end` at all.** Code runs in the implicit `end` block; locals
  are declared inline per SG-1. Named blocks on a non-pipeline function are pure
  ceremony: a direct call runs `process` exactly once, so the blocks change
  nothing and only obscure whether the function actually streams. (No built-in
  rule covers this inverse — PSScriptAnalyzer issue #1571 — hence the custom house
  rule.)
- Empty named blocks are prohibited in all cases (aligned with the PoshCode
  guidance "do not include empty named blocks"); under SG-1 every block a pipeline
  function keeps carries real content (`begin` = typed initialization, `process`
  = work), so this falls out naturally.

**Why.** The construct question removes cmdlet ceremony from code that was never a
cmdlet; the pipeline default keeps real operations composable (the reason the shell
exists); and shape-follows-pipelining makes a function's streaming contract visible
at a glance — `begin/process/end` present *means* "this streams", absent *means*
"this is a single-shot call". Ambiguity is the enemy.

**Enforced by:**
- built-in `PSUseProcessBlockForPipelineCommand` (Warning) — pipeline parameter
  handled outside `process`;
- custom rule `Measure-FlatNonPipelineFunction` (Warning) — any
  `begin`/`process`/`end`/`dynamicparam` block on a function whose `param` block
  declares no `ValueFromPipeline`/`ValueFromPipelineByPropertyName` parameter;
- 2a and 2b are **[judgment]** — review-enforced via the advisor skill; the
  analyzer is intentionally silent.

> **Attribute surface (pointer).** ADR-template/0002 also fixes the
> maximal-explicit `[CmdletBinding()]` standard — every option present with a real,
> owned value (`ConfirmImpact` always stated, `DefaultParameterSetName = 'default'`,
> …) plus `[OutputType]`. Its per-option criteria land as their own SG rules, one at
> a time; until each lands, the examples above intentionally show the bare form.

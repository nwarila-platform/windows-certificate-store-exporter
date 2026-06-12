# PowerShell House Style Guide

Canonical in `NWarila/powershell-template`; mirrored byte-identical into consuming
repositories (alongside `PSScriptAnalyzerSettings.psd1` and the custom analyzer
rules). Each rule here is **machine-enforced** by a PSScriptAnalyzer rule so it
gates CI — the guide explains intent; the analyzer is the source of truth for
pass/fail.

Severity convention: house rules are **Warning** (the settings file gates on
`Error` + `Warning`, so a Warning fails CI).

---

## SG-1 — Variable discipline (Private scope, Begin-declaration, reset, no Remove)

**Rule.** Every local variable a function *creates* must be **Private-scoped**
with a typed `$Private:` assignment:

- `[System.String]$Private:X = [System.String]::Empty`

Do **not** use `New-Variable` for function-local declarations. It is slower,
honors `-WhatIf` inside `SupportsShouldProcess` functions, and adds ceremony
without buying type safety.

**Exempt:** parameters, PowerShell automatic variables (`$PSItem`, `$_`,
`$PSCmdlet`, `$true`/`$false`/`$null`, `$args`, `$matches`, …), and `for`/`foreach`
loop induction variables.

**Pipeline-capable functions** — those that declare a parameter with
`ValueFromPipeline` or `ValueFromPipelineByPropertyName` — MUST:

1. use `Begin` / `Process` / `End` (the built-in `PSUseProcessBlockForPipelineCommand`
   already requires the process block);
2. **declare** each local in `Begin` using a typed `$Private:` assignment; and
3. **reset** each declared local at the **top of `Process`**, preferably with a
   direct assignment to its typed default, so state resets between piped items.

**Non-pipeline functions** — pure producers with no pipeline-bound parameter
(e.g. `Get-StoreCertificate`, which reads the whole store and cannot be piped
into) — are **exempt** from the `Begin/Process/End` + reset ceremony.
They simply declare locals inline as typed `$Private:X` assignments.

**Do NOT** use `Remove-Variable` for end-of-function cleanup. The function scope
disposes its variables automatically; an explicit `Remove-Variable` in `End` adds
runtime cost for no effect. (This is a deliberate correction of the older
targetstate reference sample, which removed variables in `End`.)

**Why.** Private scope keeps locals from leaking into child scopes; typed
assignments keep declaration cheap and explicit; `Begin` declaration + `Process`
reset assignment make per-item state reset-safe; dropping `New-Variable` and
`Remove-Variable` removes dead overhead.

**Note (verified).** Private-scoped variables remain usable for *mutation* inside
`ForEach-Object` blocks (e.g. `$list.Add(...)`); Private affects child-scope
*inheritance*, not reading a reference to mutate it. Reassignment (`$x += …`)
inside `ForEach-Object` is a separate PowerShell scoping pitfall and is not made
worse by this rule.

**Enforced by:** custom analyzer rules (Warning) — see the rules module wired via
`CustomRulePath` in `PSScriptAnalyzerSettings.psd1`:
- a rule that flags any function-local variable that is assigned but not
  Private-scoped with `$Private:`;
- a rule that, for pipeline-capable functions, flags locals not declared in
  `Begin` or not reset at the top of `Process`;
- a rule that flags `Remove-Variable` used as end-of-scope cleanup.
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

        # Initalize Variable(s)
        [System.String]$Private:Result = [System.String]::Empty

        Write-Debug -Message '[ConvertTo-Thing] Exiting Begin'
    }
    process {
        $Result = [System.String]::Empty
        $Result = $InputValue.ToUpperInvariant()
        $Result
    }
    end { }
}
```

### Example (non-pipeline producer)

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

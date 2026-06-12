# PowerShell House Style Guide

Canonical in `NWarila/powershell-template`; mirrored byte-identical into consuming
repositories (alongside `PSScriptAnalyzerSettings.psd1` and the custom analyzer
rules). Each rule here is **machine-enforced** by a PSScriptAnalyzer rule so it
gates CI — the guide explains intent; the analyzer is the source of truth for
pass/fail.

Severity convention: house rules are **Warning** (the settings file gates on
`Error` + `Warning`, so a Warning fails CI).

---

## SG-1 — Variable discipline (Private scope, Begin-declaration, Clear, no Remove)

**Rule.** Every local variable a function *creates* must be **Private-scoped**,
declared via either:

- `New-Variable -Name 'X' -Force -Option Private -Value (<typed default>)`, or
- the `$private:X = <value>` scope modifier.

**Exempt:** parameters, PowerShell automatic variables (`$PSItem`, `$_`,
`$PSCmdlet`, `$true`/`$false`/`$null`, `$args`, `$matches`, …), and `for`/`foreach`
loop induction variables.

**Pipeline-capable functions** — those that declare a parameter with
`ValueFromPipeline` or `ValueFromPipelineByPropertyName` — MUST:

1. use `Begin` / `Process` / `End` (the built-in `PSUseProcessBlockForPipelineCommand`
   already requires the process block);
2. **declare** each local in `Begin` (`New-Variable -Option Private`, or a
   `$private:` assignment in `Begin`); and
3. **`Clear-Variable`** each declared local at the **top of `Process`**, so state
   resets between piped items.

**Non-pipeline functions** — pure producers with no pipeline-bound parameter
(e.g. `Get-StoreCertificate`, which reads the whole store and cannot be piped
into) — are **exempt** from the `Begin/Process/End` + `Clear-Variable` ceremony.
They simply declare locals inline as `$private:X`.

**Do NOT** use `Remove-Variable` for end-of-function cleanup. The function scope
disposes its variables automatically; an explicit `Remove-Variable` in `End` adds
runtime cost for no effect. (This is a deliberate correction of the older
targetstate reference sample, which removed variables in `End`.)

**Why.** Private scope keeps locals from leaking into child scopes; `Begin`
declaration + `Process` `Clear-Variable` make per-item state explicit and
reset-safe; dropping `Remove-Variable` removes dead overhead.

**Note (verified).** Private-scoped variables remain usable for *mutation* inside
`ForEach-Object` blocks (e.g. `$list.Add(...)`); Private affects child-scope
*inheritance*, not reading a reference to mutate it. Reassignment (`$x += …`)
inside `ForEach-Object` is a separate PowerShell scoping pitfall and is not made
worse by this rule.

**Enforced by:** custom analyzer rules (Warning) — see the rules module wired via
`CustomRulePath` in `PSScriptAnalyzerSettings.psd1`:
- a rule that flags any function-local variable that is assigned but not
  Private-scoped (neither `New-Variable -Option Private` nor `$private:`);
- a rule that, for pipeline-capable functions, flags locals not declared in
  `Begin` or not `Clear-Variable`d at the top of `Process`;
- a rule that flags `Remove-Variable` used as end-of-scope cleanup.

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
        New-Variable -Name 'Result' -Force -Option Private -Value ([System.String]::Empty)
    }
    process {
        Clear-Variable -Name 'Result' -Force -ErrorAction SilentlyContinue
        Set-Variable -Name 'Result' -Value ($InputValue.ToUpperInvariant())
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
    $private:Items = [System.Collections.Generic.List[object]]::new()
    foreach ($Name in 'a', 'b') { $private:Items.Add($Name) }
    , $private:Items.ToArray()
}
```

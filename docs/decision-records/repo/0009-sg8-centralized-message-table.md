# ADR-repo/0009: Adopt SG-8 Centralized Message Table

| Field          | Value                                                        |
| -------------- | ------------------------------------------------------------ |
| Status         | Accepted                                                     |
| Date           | 2026-06-16                                                   |
| Authors        | Nick Warila (@NWarila)                                       |
| Decision-maker | Nick Warila (sole portfolio maintainer)                      |
| Consulted      | Microsoft Learn `ConvertFrom-StringData`, `about_Data_Sections`, and `Import-LocalizedData`; DSC Community localization guidelines; deep-research notes on backslash escaping and DSC string tables. |
| Informed       | Maintainers and reviewers of the script.                     |
| Reversibility  | Medium                                                       |
| Review-by      | N/A (Accepted)                                               |

## TL;DR

Adopt SG-8: user-facing message strings live in a script-scope
`$Script:Message` hashtable. Each function owns its message entries as a
co-located file-scope fragment, and the build merges those fragments into the
single-script artifact. Use plain single-quoted hashtable values, not `data {}` or
`ConvertFrom-StringData`, because `ConvertFrom-StringData` treats backslashes as
regular-expression escapes and is hostile to Windows-store-path messages such as
`{0}\{1}`.

## Context and Problem Statement

The exporter now centralizes user-facing messages so call sites do not carry inline
message literals. The project still ships as one English-only script, supports
Windows PowerShell 5.1, and keeps source split by function for review and tests.

The missing decision was the storage mechanism. PowerShell and DSC examples often
use `data { ConvertFrom-StringData ... }` or external localized `.psd1` string
files. Those are valid localization patterns, but this repository is not
localizing; it needs a small, auditable in-script table that cannot corrupt Windows
paths.

## Decision Drivers

1. **Correct Windows path text** — messages contain literal backslashes such as
   `{0}\{1}` and must not require escape doubling to survive.
2. **PowerShell 5.1 floor** — the style must work in the same runtime the exporter
   verifies.
3. **Single-script release** — no external `.psd1` files or module localization
   layout in the shipped artifact.
4. **Function ownership** — each function's messages should live near the code that
   emits them.
5. **Collision visibility** — duplicate message keys should fail loudly during
   build/merge review instead of silently overwriting another string.

## Considered Options

1. **Plain `$Script:Message` hashtable with per-function fragments** (chosen).
2. **`data { ConvertFrom-StringData ... }` inside script source**.
3. **External localized `.psd1` string files imported with `Import-LocalizedData`**.
4. **One hand-written central table in a single source file**.
5. **Inline `-Message` literals at call sites**.

## Decision Outcome

Chosen: option 1.

User-facing message strings are stored in one script-scope hashtable:

```powershell
$Script:Message += @{
  'Get-Thing.MissingPath' = 'Path ''{0}'' does not exist.'
}
```

Each fragment is authored at file scope next to the owning function. The build emits
`[System.Collections.Hashtable]$Script:Message = @{}` before the merged function
fragments, making the first `+=` StrictMode-safe in the generated artifact.

Call sites index and format directly:

```powershell
New-ErrorRecord -Message:($Script:Message['Get-Thing.MissingPath'] -f $Path)
```

Keys are namespaced as `FunctionName.Purpose`. Duplicate keys intentionally fail
when fragments are added to the hashtable, providing collision detection. Message
values are plain single-quoted hashtable strings.

Inline user-facing `-Message` literals are forbidden, as are
`$FailureMessage`-style intermediates whose only purpose is holding a formatted
message. `Write-Debug` strings are not part of the table because they are diagnostic
trace anchors, not user-facing output.

### Deep-research findings

Microsoft documents `ConvertFrom-StringData` as a key/value-to-hashtable helper that
is safe for `data` sections, but it interprets backslashes through
`Regex.Unescape`. Microsoft also warns that literal backslashes need doubling and
that unescaped backslashes commonly used in file paths can become illegal escape
sequences. That makes it a poor fit for messages containing `{0}\{1}`: valid
Windows path text either has to be doubled everywhere or can be corrupted or thrown
on by the parser. The `-Delimiter` parameter does not help with backslash escaping
and is PowerShell 7-only, so it is outside this repo's Windows PowerShell 5.1 floor.

Microsoft documents `data` sections as a way to isolate strings and other read-only
data from script logic with a restricted language subset, and specifically calls out
script internationalization. Their real powers here are localization-oriented:
restricted execution and the ability to pair default in-script strings with
`Import-LocalizedData` overrides from culture-specific `.psd1` files.

Microsoft documents `Import-LocalizedData` as dynamically retrieving strings from
language-specific subdirectories based on the user's UI culture, with parameters for
alternate UI culture, path, and file name. That is the right mechanism for
localized scripts, but it adds external file layout and culture-selection behavior
that this English-only single-file exporter deliberately rejects.

The DSC Community localization guideline uses per-resource string tables:
`DSC_<ResourceName>.strings.psd1` files under culture folders, populated with
`ConvertFrom-StringData`, imported at the top of each resource module, and consumed
as `$script:localizedData.Key -f ...`. SG-8 mirrors the ownership idea — the
resource/function owns its messages — but swaps external localized `.psd1` files
for build-merged in-script fragments to satisfy this repository's single-file
constraint.

### Honest framing

For a tool this small, option 4 — one central source table — would be equally
correct. The chosen per-function layout is deliberate ease-of-development policy:
when a function changes, its messages change in the same source neighborhood. The
build still produces a single table in the merged artifact, so runtime behavior is
centralized even though source authorship is co-located.

### Consequences

- **Positive:** user-facing text has one lookup surface in the generated script.
- **Positive:** messages stay close to the function and tests that own them.
- **Positive:** literal Windows path text stays literal without escape doubling.
- **Positive:** duplicate keys fail loudly during merge/build validation.
- **Negative:** the convention is review-enforced for now; no analyzer rule blocks
  inline message literals yet.
- **Negative:** localized `.psd1` files would need a new decision if this tool ever
  grows real localization requirements.

## Enforcement

SG-8 is enforced by review. There is no custom analyzer rule yet. A future
`Measure-*` rule could flag inline user-facing `-Message` literals, non-namespaced
message keys, or message fragments outside the expected file-scope shape.

No code, analyzer, or settings change is part of this ADR.

## More Information

- Style guide: [docs/STYLE-GUIDE.md](../../STYLE-GUIDE.md#sg-8--centralized-message-table-judgment--review-enforced)
- Microsoft Learn: [`ConvertFrom-StringData`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-stringdata?view=powershell-7.5)
- Microsoft Learn: [`about_Data_Sections`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_data_sections?view=powershell-7.5)
- Microsoft Learn: [`Import-LocalizedData`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-localizeddata?view=powershell-7.5)
- DSC Community: [Localization style guideline](https://dsccommunity.org/styleguidelines/localization/)

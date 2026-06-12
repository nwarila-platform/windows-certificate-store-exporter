#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'SG-1 house analyzer rules' {
    BeforeAll {
        $script:AnalyzerRulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\analyzers\HouseRules.psm1'
        if (-not (Get-Module -Name PSScriptAnalyzer)) {
            Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
        }
    }

    It 'flags function-local assignments that are not Private-scoped' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding()]
    param ()
    $Value = 'thing'
    $Value
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PrivateVariableDeclaration'

        $Results.RuleName | Should -Contain 'Measure-PrivateVariableDeclaration'
    }

    It 'accepts Private-scoped local assignments' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding()]
    param ()
    [System.String]$Private:Value = 'thing'
    $Value
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PrivateVariableDeclaration'

        $Results | Should -HaveCount 0
    }

    It 'flags New-Variable local declarations' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding()]
    param ()
    New-Variable -Name 'Value' -Force -Option Private -Value ([System.String]::Empty)
    $Value = 'thing'
    $Value
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-NoNewVariableDeclaration'

        $Results.RuleName | Should -Contain 'Measure-NoNewVariableDeclaration'
    }

    It 'flags pipeline locals not declared in Begin' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [System.String]
        $InputObject
    )
    begin { }
    process {
        $Value = [System.String]::Empty
        [System.String]$Private:Value = $InputObject.ToUpperInvariant()
        $Value
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PipelineVariableLifecycle'

        $Results.RuleName | Should -Contain 'Measure-PipelineVariableLifecycle'
        $Results.Message | Should -Match 'without declaring it in Begin'
    }

    It 'flags pipeline locals not reset at the top of Process' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $True)]
        [System.String]
        $InputObject
    )
    begin {
        [System.String]$Private:Value = [System.String]::Empty
    }
    process {
        Write-Debug -Message 'not clear first'
        $Value = $InputObject.ToUpperInvariant()
        $Value
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PipelineVariableLifecycle'

        $Results.RuleName | Should -Contain 'Measure-PipelineVariableLifecycle'
        $Results.Message | Should -Match 'does not reset it at the top of Process'
    }

    It 'accepts the pipeline Begin and reset idiom' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $True)]
        [System.String]
        $InputObject
    )
    begin {
        [System.String]$Private:Value = [System.String]::Empty
    }
    process {
        $Value = [System.String]::Empty
        $Value = $InputObject.ToUpperInvariant()
        $Value
    }
    end { }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PipelineVariableLifecycle'

        $Results | Should -HaveCount 0
    }

    It 'flags Remove-Variable cleanup in End blocks' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding()]
    param ()
    begin {
        [System.String]$Private:Value = [System.String]::Empty
    }
    process {
        $Value = 'thing'
        $Value
    }
    end {
        Remove-Variable -Name 'Value'
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-NoRemoveVariableCleanup'

        $Results.RuleName | Should -Contain 'Measure-NoRemoveVariableCleanup'
    }
}

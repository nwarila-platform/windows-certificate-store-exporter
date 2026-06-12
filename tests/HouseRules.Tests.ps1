#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'SG-1 house analyzer rules' {
    BeforeAll {
        $script:AnalyzerRulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\analyzers\HouseRules.psm1'
        Import-Module -Name PSScriptAnalyzer -Force -ErrorAction Stop
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
    $private:Value = 'thing'
    $Value
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-PrivateVariableDeclaration'

        $Results | Should -HaveCount 0
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
        Clear-Variable -Name 'Value' -Force -ErrorAction SilentlyContinue
        $private:Value = $InputObject.ToUpperInvariant()
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

    It 'flags pipeline locals not cleared at the top of Process' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $True)]
        [System.String]
        $InputObject
    )
    begin {
        New-Variable -Name 'Value' -Force -Option Private -Value ([System.String]::Empty)
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
        $Results.Message | Should -Match 'does not clear it at the top of Process'
    }

    It 'accepts the pipeline Begin and Clear idiom' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $True)]
        [System.String]
        $InputObject
    )
    begin {
        New-Variable -Name 'Value' -Force -Option Private -Value ([System.String]::Empty)
    }
    process {
        Clear-Variable -Name 'Value' -Force -ErrorAction SilentlyContinue
        Set-Variable -Name 'Value' -Value ($InputObject.ToUpperInvariant())
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
        New-Variable -Name 'Value' -Force -Option Private -Value ([System.String]::Empty)
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

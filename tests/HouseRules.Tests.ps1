#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'SG-1 house analyzer rules' {
    BeforeAll {
        $AnalyzerRulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\analyzers\HouseRules.psm1'
        $script:AnalyzerRulePath = $AnalyzerRulePath
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-PrivateVariableDeclaration' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-PrivateVariableDeclaration' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-NoNewVariableDeclaration' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-PipelineVariableLifecycle' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-PipelineVariableLifecycle' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-PipelineVariableLifecycle' })
        $Results | Should -HaveCount 0
    }

    It 'flags named blocks on flat non-pipeline functions' {
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
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-FlatNonPipelineFunction'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-FlatNonPipelineFunction' })
        $Results.RuleName | Should -Contain 'Measure-FlatNonPipelineFunction'
        $Results.Message | Should -Match 'no pipeline input'
    }

    It 'accepts implicit End block flat functions' {
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
            -IncludeRule 'Measure-FlatNonPipelineFunction'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-FlatNonPipelineFunction' })
        $Results | Should -HaveCount 0
    }

    It 'accepts named blocks when a function declares pipeline input' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [System.String]
        $Name
    )
    begin {
        [System.String]$Private:Value = [System.String]::Empty
    }
    process {
        $Value = [System.String]::Empty
        $Value = $Name.ToUpperInvariant()
        $Value
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-FlatNonPipelineFunction'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-FlatNonPipelineFunction' })
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


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-NoRemoveVariableCleanup' })
        $Results.RuleName | Should -Contain 'Measure-NoRemoveVariableCleanup'
    }
}

Describe 'SG-4 house analyzer rules' {
    BeforeAll {
        $script:AnalyzerRulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\analyzers\HouseRules.psm1'
        if (-not (Get-Module -Name PSScriptAnalyzer)) {
            Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
        }

        $script:NewExplicitBindingFixture = {
            param (
                [Parameter()]
                [AllowNull()]
                [System.String]
                $MissingOption = $Null,

                [Parameter()]
                [System.Boolean]
                $IncludeOutputType = $True
            )

            $Options = @(
                @{ Name = 'SupportsShouldProcess'; Value = '$False' },
                @{ Name = 'ConfirmImpact'; Value = "'None'" },
                @{ Name = 'PositionalBinding'; Value = '$False' },
                @{ Name = 'DefaultParameterSetName'; Value = "'default'" },
                @{ Name = 'HelpUri'; Value = "'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing'" },
                @{ Name = 'SupportsPaging'; Value = '$False' }
            ) | Where-Object -FilterScript {
                $PSItem.Name -ine $MissingOption
            }

            $OptionLines = [System.Collections.Generic.List[System.String]]::new()
            for ($Index = 0; $Index -lt $Options.Count; $Index++) {
                $Line = '        {0} = {1}' -f $Options[$Index].Name, $Options[$Index].Value
                if ($Index -lt ($Options.Count - 1)) {
                    $Line = '{0},' -f $Line
                }

                [void]$OptionLines.Add($Line)
            }

            $OutputTypeLine = [System.String]::Empty
            if ($IncludeOutputType -eq $True) {
                $OutputTypeLine = '    [OutputType([System.String])]'
            }

            @"
function Get-Thing {
    [CmdletBinding(
$($OptionLines.ToArray() -join "`n")
    )]
$OutputTypeLine
    param ()
    [System.String]'thing'
}
"@
        }.GetNewClosure()
    }

    It 'accepts the complete explicit CmdletBinding and OutputType surface' {
        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition (& $script:NewExplicitBindingFixture) `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-ExplicitCmdletBinding'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-ExplicitCmdletBinding' })
        $Results | Should -HaveCount 0
    }

    It 'flags every missing explicit CmdletBinding option' {
        $RequiredOptions = [System.String[]]@(
            'SupportsShouldProcess',
            'ConfirmImpact',
            'PositionalBinding',
            'DefaultParameterSetName',
            'HelpUri',
            'SupportsPaging'
        )

        foreach ($RequiredOption in $RequiredOptions) {
            $Results = Invoke-ScriptAnalyzer `
                -ScriptDefinition (& $script:NewExplicitBindingFixture -MissingOption $RequiredOption) `
                -CustomRulePath $script:AnalyzerRulePath `
                -IncludeRule 'Measure-ExplicitCmdletBinding'


                $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-ExplicitCmdletBinding' })
            $Results.RuleName | Should -Contain 'Measure-ExplicitCmdletBinding'
            $Results.Message | Should -Match $RequiredOption
        }
    }

    It 'flags missing OutputType even when CmdletBinding is complete' {
        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition (& $script:NewExplicitBindingFixture -IncludeOutputType $False) `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-ExplicitCmdletBinding'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-ExplicitCmdletBinding' })
        $Results.RuleName | Should -Contain 'Measure-ExplicitCmdletBinding'
        $Results.Message | Should -Match 'OutputType'
    }

    It 'flags functions without CmdletBinding' {
        $ScriptDefinition = @'
function Get-Thing {
    [OutputType([System.String])]
    param ()
    [System.String]'thing'
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-ExplicitCmdletBinding'


            $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-ExplicitCmdletBinding' })
        $Results.RuleName | Should -Contain 'Measure-ExplicitCmdletBinding'
        $Results.Message | Should -Match 'CmdletBinding'
    }
}

Describe 'SG-5 house analyzer rules' {
    BeforeAll {
        $script:AnalyzerRulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\analyzers\HouseRules.psm1'
        if (-not (Get-Module -Name PSScriptAnalyzer)) {
            Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
        }
    }

    It 'flags misordered CmdletBinding options' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding(
        SupportsShouldProcess = $False,
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing',
        PositionalBinding = $False,
        SupportsPaging = $False
    )]
    [OutputType([System.String])]
    param ()
    [System.String]'thing'
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results.RuleName | Should -Contain 'Measure-CanonicalAttributeOrder'
        $Results.Message | Should -Match 'SG-5a'
    }

    It 'flags misordered Parameter attribute arguments' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#convertto-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [Parameter(ValueFromPipeline = $True, Mandatory = $True)]
        [System.String]
        $InputObject
    )
    process {
        $InputObject
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results.RuleName | Should -Contain 'Measure-CanonicalAttributeOrder'
        $Results.Message | Should -Match 'SG-5b'
    }

    It 'flags validation attributes after the type literal' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $True)]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $Name
    )
    $Name
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results.RuleName | Should -Contain 'Measure-CanonicalAttributeOrder'
        $Results.Message -join [System.Environment]::NewLine | Should -Match 'type must be last'
    }

    It 'flags wrong parameter attribute order' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $True)]
        [System.String]
        $Name
    )
    $Name
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results.RuleName | Should -Contain 'Measure-CanonicalAttributeOrder'
        $Results.Message | Should -Match 'SG-5c'
    }

    It 'flags unsorted parameter names' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [Parameter()]
        [System.String]
        $Zoo,

        [Parameter()]
        [System.String]
        $Alpha
    )
    $Alpha
    $Zoo
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results.RuleName | Should -Contain 'Measure-CanonicalAttributeOrder'
        $Results.Message | Should -Match 'SG-5d'
    }

    It 'does not flag unsorted parameter names when explicit Position trips the guard' {
        $ScriptDefinition = @'
function Get-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#get-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [Parameter(Position = 1)]
        [System.String]
        $Zoo,

        [Parameter()]
        [System.String]
        $Alpha
    )
    $Alpha
    $Zoo
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results | Should -HaveCount 0
    }

    It 'accepts the canonical declaration idiom' {
        $ScriptDefinition = @'
function ConvertTo-Thing {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/example/repo/blob/main/docs/reference/functions.md#convertto-thing',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Alpha,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [Alias('n')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )
    process {
        $Name
    }
}
'@

        $Results = Invoke-ScriptAnalyzer `
            -ScriptDefinition $ScriptDefinition `
            -CustomRulePath $script:AnalyzerRulePath `
            -IncludeRule 'Measure-CanonicalAttributeOrder'

        $Results = @($Results | Where-Object -FilterScript { $PSItem.RuleName -eq 'Measure-CanonicalAttributeOrder' })

        $Results | Should -HaveCount 0
    }
}

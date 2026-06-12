<#
.SYNOPSIS
    PSScriptAnalyzer settings for this PowerShell project.

.DESCRIPTION
    Keeps local and CI analysis aligned with the portfolio PowerShell baseline.
    The settings file is intentionally self-clean under these same rules.
#>
@{
    Severity            = @('Error', 'Warning')

    CustomRulePath      = @(
        './analyzers/HouseRules.psm1'
    )

    IncludeDefaultRules = $true

    IncludeRules        = @('*')

    ExcludeRules        = @(
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules               = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }

        PSUseConsistentWhitespace  = @{
            Enable          = $true
            CheckInnerBrace = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $false
            CheckSeparator  = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSUseCorrectCasing         = @{
            Enable = $true
        }

        'Measure-PrivateVariableDeclaration' = @{
            Enable = $true
        }

        'Measure-PipelineVariableLifecycle'  = @{
            Enable = $true
        }

        'Measure-NoRemoveVariableCleanup'    = @{
            Enable = $true
        }

        'Measure-NoNewVariableDeclaration'   = @{
            Enable = $true
        }
    }
}

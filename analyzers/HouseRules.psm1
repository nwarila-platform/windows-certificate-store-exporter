#Requires -Version 5.1

function ConvertTo-HouseRuleDiagnosticRecord {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [Parameter(Mandatory = $True)]
        [System.String]
        $Message,

        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.IScriptExtent]
        $Extent,

        [Parameter(Mandatory = $True)]
        [System.String]
        $RuleName
    )

    process {
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]::new(
            $Message,
            $Extent,
            $RuleName,
            [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity]::Warning,
            $Null,
            $Null,
            $Null
        )
    }
}

function Get-HouseRuleFunctionAst {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.FunctionDefinitionAst[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        [System.Management.Automation.Language.FunctionDefinitionAst[]]@(
            $ScriptBlockAst.FindAll(
                {
                    param (
                        [System.Management.Automation.Language.Ast]
                        $Ast
                    )

                    $Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                },
                $True
            )
        )
    }
}

function Test-HouseRuleAstBelongsToFunction {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.Ast]
        $Ast,

        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        $ParentAst = $Ast

        while ($Null -ne $ParentAst) {
            if ($ParentAst -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                return [System.Boolean]([System.Object]::ReferenceEquals($ParentAst, $FunctionAst))
            }

            $ParentAst = $ParentAst.Parent
        }

        [System.Boolean]$False
    }
}

function Get-HouseRuleVariableName {
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.VariableExpressionAst]
        $VariableAst
    )

    process {
        if ($VariableAst.VariablePath.IsDriveQualified -eq $True) {
            return
        }

        if ($VariableAst.VariablePath.IsVariable -eq $False) {
            return
        }

        if ($VariableAst.VariablePath.IsScript -eq $True -or $VariableAst.VariablePath.IsGlobal -eq $True) {
            return
        }

        [System.String]($VariableAst.VariablePath.UserPath -replace '(?i)^(private|local):', '')
    }
}

function Test-HouseRuleAutomaticVariable {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.String]
        $Name
    )

    process {
        $AutomaticVariables = [System.Collections.Generic.HashSet[System.String]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        [System.String[]]@(
            '_',
            'args',
            'ConsoleFileName',
            'EnabledExperimentalFeatures',
            'Error',
            'ErrorActionPreference',
            'ErrorView',
            'ExecutionContext',
            'false',
            'foreach',
            'HOME',
            'Host',
            'input',
            'IsCoreCLR',
            'IsLinux',
            'IsMacOS',
            'IsWindows',
            'LASTEXITCODE',
            'Matches',
            'MyInvocation',
            'NestedPromptLevel',
            'null',
            'PID',
            'PROFILE',
            'PSBoundParameters',
            'PSCmdlet',
            'PSCommandPath',
            'PSCulture',
            'PSDebugContext',
            'PSDefaultParameterValues',
            'PSEdition',
            'PSHOME',
            'PSItem',
            'PSScriptRoot',
            'PSSenderInfo',
            'PSStyle',
            'PSUICulture',
            'PSVersionTable',
            'PWD',
            'ShellId',
            'StackTrace',
            'switch',
            'this',
            'true'
        ) | ForEach-Object -Process {
            [void]$AutomaticVariables.Add($PSItem)
        }

        [System.Boolean]$AutomaticVariables.Contains($Name)
    }
}

function Get-HouseRuleParameterName {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        [System.String[]]@(
            if ($Null -ne $FunctionAst.Body.ParamBlock) {
                $FunctionAst.Body.ParamBlock.Parameters |
                    ForEach-Object -Process {
                        Get-HouseRuleVariableName -VariableAst $PSItem.Name
                    }
            }
        )
    }
}

function Get-HouseRuleIteratorName {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        $Names = [System.Collections.Generic.HashSet[System.String]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        $FunctionAst.Body.FindAll(
            {
                param (
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )

                $Ast -is [System.Management.Automation.Language.ForEachStatementAst] -or
                    $Ast -is [System.Management.Automation.Language.ForStatementAst]
            },
            $True
        ) | Where-Object -FilterScript {
            Test-HouseRuleAstBelongsToFunction -Ast $PSItem -FunctionAst $FunctionAst
        } | ForEach-Object -Process {
            if ($PSItem -is [System.Management.Automation.Language.ForEachStatementAst]) {
                [void]$Names.Add((Get-HouseRuleVariableName -VariableAst $PSItem.Variable))
                return
            }

            if ($Null -ne $PSItem.Initializer) {
                $PSItem.Initializer.FindAll(
                    {
                        param (
                            [System.Management.Automation.Language.Ast]
                            $Ast
                        )

                        $Ast -is [System.Management.Automation.Language.VariableExpressionAst]
                    },
                    $False
                ) | ForEach-Object -Process {
                    [void]$Names.Add((Get-HouseRuleVariableName -VariableAst $PSItem))
                }
            }

            if ($Null -ne $PSItem.Iterator) {
                $PSItem.Iterator.FindAll(
                    {
                        param (
                            [System.Management.Automation.Language.Ast]
                            $Ast
                        )

                        $Ast -is [System.Management.Automation.Language.VariableExpressionAst]
                    },
                    $False
                ) | ForEach-Object -Process {
                    [void]$Names.Add((Get-HouseRuleVariableName -VariableAst $PSItem))
                }
            }
        }

        [System.String[]]@($Names)
    }
}

function Get-HouseRuleStaticString {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.Language.Ast]
        $Ast
    )

    process {
        if ($Null -eq $Ast) {
            return
        }

        if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            [System.String]$Ast.Value
            return
        }

        if ($Ast -is [System.Management.Automation.Language.ConstantExpressionAst]) {
            [System.String]$Ast.Value
            return
        }

        if ($Ast -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            $Ast.Elements | ForEach-Object -Process {
                Get-HouseRuleStaticString -Ast $PSItem
            }
        }
    }
}

function Get-HouseRuleCommandArgument {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.Ast[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst,

        [Parameter(Mandatory = $True)]
        [System.String]
        $ParameterName
    )

    process {
        for ($Index = 1; $Index -lt $CommandAst.CommandElements.Count; $Index++) {
            $Element = $CommandAst.CommandElements[$Index]

            if ($Element -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                continue
            }

            if ($Element.ParameterName -ine $ParameterName) {
                continue
            }

            if ($Null -ne $Element.Argument) {
                $Element.Argument
                continue
            }

            if (($Index + 1) -lt $CommandAst.CommandElements.Count) {
                $NextElement = $CommandAst.CommandElements[$Index + 1]
                if ($NextElement -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                    $NextElement
                }
            }
        }
    }
}

function Get-HouseRuleCommandArgumentString {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst,

        [Parameter(Mandatory = $True)]
        [System.String]
        $ParameterName
    )

    process {
        Get-HouseRuleCommandArgument -CommandAst $CommandAst -ParameterName $ParameterName |
            ForEach-Object -Process {
                Get-HouseRuleStaticString -Ast $PSItem
            }
    }
}

function Test-HouseRuleCommandHasPrivateOption {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst
    )

    process {
        $Options = [System.String[]]@(
            Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Option'
        )

        [System.Boolean]($Options -icontains 'Private')
    }
}

function Test-HouseRuleCommandUsesNonLocalScope {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst
    )

    process {
        $Scopes = [System.String[]]@(
            Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Scope'
        )

        [System.Boolean]($Scopes -icontains 'Script' -or $Scopes -icontains 'Global')
    }
}

function Get-HouseRuleAssignedExpressionVariable {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.Ast]
        $Ast
    )

    process {
        if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
            [PSCustomObject]@{
                Name      = Get-HouseRuleVariableName -VariableAst $Ast
                Extent    = $Ast.Extent
                IsPrivate = [System.Boolean]$Ast.VariablePath.IsPrivate
            }
            return
        }

        if ($Ast -is [System.Management.Automation.Language.ConvertExpressionAst]) {
            Get-HouseRuleAssignedExpressionVariable -Ast $Ast.Child
            return
        }

        if ($Ast -is [System.Management.Automation.Language.AttributedExpressionAst]) {
            Get-HouseRuleAssignedExpressionVariable -Ast $Ast.Child
            return
        }

        if ($Ast -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            $Ast.Elements | ForEach-Object -Process {
                Get-HouseRuleAssignedExpressionVariable -Ast $PSItem
            }
        }
    }
}

function Get-HouseRuleAssignedVariable {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        $FunctionAst.Body.FindAll(
            {
                param (
                    [System.Management.Automation.Language.Ast]
                    $Ast
                )

                $Ast -is [System.Management.Automation.Language.AssignmentStatementAst] -or
                    $Ast -is [System.Management.Automation.Language.UnaryExpressionAst] -or
                    $Ast -is [System.Management.Automation.Language.CommandAst]
            },
            $True
        ) | Where-Object -FilterScript {
            Test-HouseRuleAstBelongsToFunction -Ast $PSItem -FunctionAst $FunctionAst
        } | ForEach-Object -Process {
            if ($PSItem -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                Get-HouseRuleAssignedExpressionVariable -Ast $PSItem.Left
                return
            }

            if ($PSItem -is [System.Management.Automation.Language.UnaryExpressionAst]) {
                Get-HouseRuleAssignedExpressionVariable -Ast $PSItem.Child
                return
            }

            $CommandAst = $PSItem
            $CommandName = $CommandAst.GetCommandName()
            if ($CommandName -inotmatch '^(New|Set)-Variable$') {
                return
            }

            if (Test-HouseRuleCommandUsesNonLocalScope -CommandAst $CommandAst) {
                return
            }

            $Names = [System.String[]]@(
                Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Name'
            )

            $Names | ForEach-Object -Process {
                [PSCustomObject]@{
                    Name      = [System.String]$PSItem
                    Extent    = $CommandAst.Extent
                    IsPrivate = [System.Boolean](
                        $CommandName -ieq 'New-Variable' -and
                        (Test-HouseRuleCommandHasPrivateOption -CommandAst $CommandAst)
                    )
                }
            }
        } | Where-Object -FilterScript {
            -not [System.String]::IsNullOrWhiteSpace($PSItem.Name)
        }
    }
}

function Get-HouseRulePrivateDeclarationName {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.Language.Ast]
        $SearchAst = $Null
    )

    process {
        if ($Null -eq $SearchAst) {
            $SearchAst = $FunctionAst.Body
        }

        [System.String[]]@(
            $SearchAst.FindAll(
                {
                    param (
                        [System.Management.Automation.Language.Ast]
                        $Ast
                    )

                    $Ast -is [System.Management.Automation.Language.AssignmentStatementAst] -or
                        $Ast -is [System.Management.Automation.Language.CommandAst]
                },
                $True
            ) | Where-Object -FilterScript {
                Test-HouseRuleAstBelongsToFunction -Ast $PSItem -FunctionAst $FunctionAst
            } | ForEach-Object -Process {
                if ($PSItem -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                    Get-HouseRuleAssignedExpressionVariable -Ast $PSItem.Left |
                        Where-Object -FilterScript { $PSItem.IsPrivate -eq $True } |
                        ForEach-Object -Process { $PSItem.Name }
                    return
                }

                if ($PSItem.GetCommandName() -inotmatch '^New-Variable$') {
                    return
                }

                if ((Test-HouseRuleCommandHasPrivateOption -CommandAst $PSItem) -eq $False) {
                    return
                }

                Get-HouseRuleCommandArgumentString -CommandAst $PSItem -ParameterName 'Name'
            }
        )
    }
}

function Test-HouseRulePipelineParameter {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        if ($Null -eq $FunctionAst.Body.ParamBlock) {
            return [System.Boolean]$False
        }

        foreach ($ParameterAst in $FunctionAst.Body.ParamBlock.Parameters) {
            foreach ($AttributeAst in $ParameterAst.Attributes) {
                if ($AttributeAst -isnot [System.Management.Automation.Language.AttributeAst]) {
                    continue
                }

                if ($AttributeAst.TypeName.FullName -ine 'Parameter') {
                    continue
                }

                foreach ($NamedArgument in $AttributeAst.NamedArguments) {
                    if ($NamedArgument.ArgumentName -inotmatch '^ValueFromPipeline(ByPropertyName)?$') {
                        continue
                    }

                    if ($Null -eq $NamedArgument.Argument) {
                        return [System.Boolean]$True
                    }

                    if ($NamedArgument.Argument.Extent.Text -ieq $NamedArgument.ArgumentName) {
                        return [System.Boolean]$True
                    }

                    try {
                        if ($NamedArgument.Argument.SafeGetValue() -eq $True) {
                            return [System.Boolean]$True
                        }
                    } catch {
                        continue
                    }
                }
            }
        }

        [System.Boolean]$False
    }
}

function Test-HouseRuleNamedBlock {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.FunctionDefinitionAst]
        $FunctionAst
    )

    process {
        if ($Null -ne $FunctionAst.Body.DynamicParamBlock) {
            return [System.Boolean]$True
        }

        if ($Null -ne $FunctionAst.Body.BeginBlock) {
            return [System.Boolean]$True
        }

        if ($Null -ne $FunctionAst.Body.ProcessBlock) {
            return [System.Boolean]$True
        }

        if ($Null -ne $FunctionAst.Body.EndBlock -and $FunctionAst.Body.EndBlock.Unnamed -eq $False) {
            return [System.Boolean]$True
        }

        [System.Boolean]$False
    }
}

function Get-HouseRuleProcessResetVariableName {
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.NamedBlockAst]
        $ProcessBlock
    )

    process {
        $Names = [System.Collections.Generic.List[System.String]]::new()

        foreach ($Statement in $ProcessBlock.Statements) {
            if ($Statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                Get-HouseRuleAssignedExpressionVariable -Ast $Statement.Left |
                    ForEach-Object -Process {
                        [void]$Names.Add($PSItem.Name)
                    }
                continue
            }

            if ($Statement -isnot [System.Management.Automation.Language.PipelineAst]) {
                break
            }

            if ($Statement.PipelineElements.Count -ne 1) {
                break
            }

            $CommandAst = $Statement.PipelineElements[0]
            if ($CommandAst -isnot [System.Management.Automation.Language.CommandAst]) {
                break
            }

            if ($CommandAst.GetCommandName() -inotmatch '^Clear-Variable$') {
                break
            }

            Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Name' |
                ForEach-Object -Process {
                    [void]$Names.Add($PSItem)
                }
        }

        [System.String[]]$Names.ToArray()
    }
}

function Measure-PrivateVariableDeclaration {
    <#
    .SYNOPSIS
        Flags function-local assignments that are not Private-scoped.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
            $PrivateDeclarations = [System.Collections.Generic.HashSet[System.String]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            Get-HouseRulePrivateDeclarationName -FunctionAst $FunctionAst | ForEach-Object -Process {
                [void]$PrivateDeclarations.Add($PSItem)
            }

            $ExemptNames = [System.Collections.Generic.HashSet[System.String]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            Get-HouseRuleParameterName -FunctionAst $FunctionAst | ForEach-Object -Process {
                [void]$ExemptNames.Add($PSItem)
            }
            Get-HouseRuleIteratorName -FunctionAst $FunctionAst | ForEach-Object -Process {
                [void]$ExemptNames.Add($PSItem)
            }

            foreach ($AssignedVariable in Get-HouseRuleAssignedVariable -FunctionAst $FunctionAst) {
                if ($ExemptNames.Contains($AssignedVariable.Name)) {
                    continue
                }

                if (Test-HouseRuleAutomaticVariable -Name $AssignedVariable.Name) {
                    continue
                }

                if ($AssignedVariable.IsPrivate -eq $True -or $PrivateDeclarations.Contains($AssignedVariable.Name)) {
                    continue
                }

                ConvertTo-HouseRuleDiagnosticRecord `
                    -RuleName 'Measure-PrivateVariableDeclaration' `
                    -Extent $AssignedVariable.Extent `
                    -Message (
                        "Function '{0}' assigns local variable '{1}' without declaring it Private-scoped." -f
                        $FunctionAst.Name,
                        $AssignedVariable.Name
                    )
            }
        }
    }
}

function Measure-PipelineVariableLifecycle {
    <#
    .SYNOPSIS
        Flags pipeline function locals not declared in Begin or cleared at Process start.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
            if ((Test-HouseRulePipelineParameter -FunctionAst $FunctionAst) -eq $False) {
                continue
            }

            if ($Null -eq $FunctionAst.Body.BeginBlock -or $Null -eq $FunctionAst.Body.ProcessBlock) {
                continue
            }

            $BeginDeclarations = [System.Collections.Generic.HashSet[System.String]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            Get-HouseRulePrivateDeclarationName -FunctionAst $FunctionAst -SearchAst $FunctionAst.Body.BeginBlock |
                ForEach-Object -Process {
                    [void]$BeginDeclarations.Add($PSItem)
                }

            $ResetNames = [System.Collections.Generic.HashSet[System.String]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            Get-HouseRuleProcessResetVariableName -ProcessBlock $FunctionAst.Body.ProcessBlock |
                ForEach-Object -Process {
                    [void]$ResetNames.Add($PSItem)
                }

            $ExemptNames = [System.Collections.Generic.HashSet[System.String]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )
            Get-HouseRuleParameterName -FunctionAst $FunctionAst | ForEach-Object -Process {
                [void]$ExemptNames.Add($PSItem)
            }
            Get-HouseRuleIteratorName -FunctionAst $FunctionAst | ForEach-Object -Process {
                [void]$ExemptNames.Add($PSItem)
            }

            $AssignedNames = [System.Collections.Generic.Dictionary[
                System.String,
                System.Management.Automation.Language.IScriptExtent
            ]]::new([System.StringComparer]::OrdinalIgnoreCase)

            foreach ($AssignedVariable in Get-HouseRuleAssignedVariable -FunctionAst $FunctionAst) {
                if ($ExemptNames.Contains($AssignedVariable.Name)) {
                    continue
                }

                if (Test-HouseRuleAutomaticVariable -Name $AssignedVariable.Name) {
                    continue
                }

                if (-not $AssignedNames.ContainsKey($AssignedVariable.Name)) {
                    $AssignedNames.Add($AssignedVariable.Name, $AssignedVariable.Extent)
                }
            }

            foreach ($AssignedName in $AssignedNames.Keys) {
                if ($BeginDeclarations.Contains($AssignedName) -eq $False) {
                    ConvertTo-HouseRuleDiagnosticRecord `
                        -RuleName 'Measure-PipelineVariableLifecycle' `
                        -Extent $AssignedNames[$AssignedName] `
                        -Message (
                            "Pipeline function '{0}' uses local variable '{1}' without declaring it in Begin." -f
                            $FunctionAst.Name,
                            $AssignedName
                        )
                }
            }

            foreach ($DeclaredName in $BeginDeclarations) {
                if ($ResetNames.Contains($DeclaredName)) {
                    continue
                }

                ConvertTo-HouseRuleDiagnosticRecord `
                    -RuleName 'Measure-PipelineVariableLifecycle' `
                    -Extent $FunctionAst.Body.ProcessBlock.Extent `
                    -Message (
                        "Pipeline function '{0}' declares local variable '{1}' in Begin but does not reset it at the top of Process." -f
                        $FunctionAst.Name,
                        $DeclaredName
                    )
            }
        }
    }
}

function Measure-FlatNonPipelineFunction {
    <#
    .SYNOPSIS
        Flags named blocks on functions that do not accept pipeline input.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
            if ((Test-HouseRulePipelineParameter -FunctionAst $FunctionAst) -eq $True) {
                continue
            }

            if ((Test-HouseRuleNamedBlock -FunctionAst $FunctionAst) -eq $False) {
                continue
            }

            ConvertTo-HouseRuleDiagnosticRecord `
                -RuleName 'Measure-FlatNonPipelineFunction' `
                -Extent $FunctionAst.Extent `
                -Message (
                    "Function '{0}' has no pipeline input, so it must be flat; remove the named blocks and let code run in the implicit End block (SG-2c)." -f
                    $FunctionAst.Name
                )
        }
    }
}

function Measure-NoRemoveVariableCleanup {
    <#
    .SYNOPSIS
        Flags Remove-Variable cleanup in function End blocks.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
            if ($Null -eq $FunctionAst.Body.EndBlock) {
                continue
            }

            $FunctionAst.Body.EndBlock.FindAll(
                {
                    param (
                        [System.Management.Automation.Language.Ast]
                        $Ast
                    )

                    $Ast -is [System.Management.Automation.Language.CommandAst]
                },
                $True
            ) | Where-Object -FilterScript {
                Test-HouseRuleAstBelongsToFunction -Ast $PSItem -FunctionAst $FunctionAst
            } | Where-Object -FilterScript {
                $PSItem.GetCommandName() -imatch '^Remove-Variable$'
            } | ForEach-Object -Process {
                ConvertTo-HouseRuleDiagnosticRecord `
                    -RuleName 'Measure-NoRemoveVariableCleanup' `
                    -Extent $PSItem.Extent `
                    -Message (
                        "Function '{0}' uses Remove-Variable for end-of-scope cleanup." -f
                        $FunctionAst.Name
                    )
            }
        }
    }
}

function Measure-NoNewVariableDeclaration {
    <#
    .SYNOPSIS
        Flags New-Variable local declarations inside functions.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )

    process {
        foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
            $FunctionAst.Body.FindAll(
                {
                    param (
                        [System.Management.Automation.Language.Ast]
                        $Ast
                    )

                    $Ast -is [System.Management.Automation.Language.CommandAst]
                },
                $True
            ) | Where-Object -FilterScript {
                Test-HouseRuleAstBelongsToFunction -Ast $PSItem -FunctionAst $FunctionAst
            } | Where-Object -FilterScript {
                $PSItem.GetCommandName() -imatch '^New-Variable$' -and
                    (Test-HouseRuleCommandUsesNonLocalScope -CommandAst $PSItem) -eq $False
            } | ForEach-Object -Process {
                ConvertTo-HouseRuleDiagnosticRecord `
                    -RuleName 'Measure-NoNewVariableDeclaration' `
                    -Extent $PSItem.Extent `
                    -Message (
                        "Function '{0}' uses New-Variable for a local declaration; use a typed `$Private:Name assignment instead." -f
                        $FunctionAst.Name
                    )
            }
        }
    }
}

Export-ModuleMember -Function 'Measure-*'

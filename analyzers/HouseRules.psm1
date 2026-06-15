#Requires -Version 5.1

function ConvertTo-HouseRuleDiagnosticRecord {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.IScriptExtent]
    $Extent,

    [Parameter(Mandatory = $True)]
    [System.String]
    $Message,

    [Parameter(Mandatory = $True)]
    [System.String]
    $RuleName
  )

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

function Get-HouseRuleFunctionAst {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.Language.FunctionDefinitionAst[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

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

function Test-HouseRuleAstBelongsToFunction {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.Ast]
    $Ast,

    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  $Private:ParentAst = $Ast

  while ($Null -ne $ParentAst) {
    if ($ParentAst -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
      return [System.Boolean]([System.Object]::ReferenceEquals($ParentAst, $FunctionAst))
    }

    $ParentAst = $ParentAst.Parent
  }

  [System.Boolean]$False

}

function Get-HouseRuleVariableName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.VariableExpressionAst]
    $VariableAst
  )

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

function Test-HouseRuleAutomaticVariable {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.String]
    $Name
  )

  $Private:AutomaticVariables = [System.Collections.Generic.HashSet[System.String]]::new(
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

function Get-HouseRuleParameterName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  [System.String[]]@(
    if ($Null -ne $FunctionAst.Body.ParamBlock) {
      $FunctionAst.Body.ParamBlock.Parameters |
        ForEach-Object -Process {
          Get-HouseRuleVariableName -VariableAst $PSItem.Name
        }
    }
  )

}

function Get-HouseRuleIteratorName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  $Private:Names = [System.Collections.Generic.HashSet[System.String]]::new(
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

function Get-HouseRuleStaticString {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String[]])]
  param (
    [Parameter()]
    [AllowNull()]
    [System.Management.Automation.Language.Ast]
    $Ast
  )

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

function Get-HouseRuleCommandArgument {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.Language.Ast[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.CommandAst]
    $CommandAst,

    [Parameter(Mandatory = $True)]
    [System.String]
    $ParameterName
  )

  for ($Index = 1; $Index -lt $CommandAst.CommandElements.Count; $Index++) {
    $Private:Element = $CommandAst.CommandElements[$Index]

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
      $Private:NextElement = $CommandAst.CommandElements[$Index + 1]
      if ($NextElement -isnot [System.Management.Automation.Language.CommandParameterAst]) {
        $NextElement
      }
    }
  }

}

function Get-HouseRuleCommandArgumentString {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.CommandAst]
    $CommandAst,

    [Parameter(Mandatory = $True)]
    [System.String]
    $ParameterName
  )

  Get-HouseRuleCommandArgument -CommandAst $CommandAst -ParameterName $ParameterName |
    ForEach-Object -Process {
      Get-HouseRuleStaticString -Ast $PSItem
    }

}

function Test-HouseRuleCommandHasPrivateOption {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.CommandAst]
    $CommandAst
  )

  $Private:Options = [System.String[]]@(
    Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Option'
  )

  [System.Boolean]($Options -icontains 'Private')

}

function Test-HouseRuleCommandUsesNonLocalScope {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.CommandAst]
    $CommandAst
  )

  $Private:Scopes = [System.String[]]@(
    Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Scope'
  )

  [System.Boolean]($Scopes -icontains 'Script' -or $Scopes -icontains 'Global')

}

function Get-HouseRuleAssignedExpressionVariable {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([PSCustomObject[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.Ast]
    $Ast
  )

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

function Get-HouseRuleAssignedVariable {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([PSCustomObject[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

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

    $Private:CommandAst = $PSItem
    $Private:CommandName = $CommandAst.GetCommandName()
    if ($CommandName -inotmatch '^(New|Set)-Variable$') {
      return
    }

    if (Test-HouseRuleCommandUsesNonLocalScope -CommandAst $CommandAst) {
      return
    }

    $Private:Names = [System.String[]]@(
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

function Get-HouseRulePrivateDeclarationName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
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

function Test-HouseRulePipelineParameter {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

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

function Test-HouseRuleNamedBlock {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

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

function Get-HouseRuleNamedBlockAst {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.Language.NamedBlockAst[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  [System.Collections.Generic.List[System.Management.Automation.Language.NamedBlockAst]]$Private:Blocks = [System.Collections.Generic.List[System.Management.Automation.Language.NamedBlockAst]]::new()

  if ($Null -ne $FunctionAst.Body.DynamicParamBlock) {
    [void]$Blocks.Add($FunctionAst.Body.DynamicParamBlock)
  }

  if ($Null -ne $FunctionAst.Body.BeginBlock) {
    [void]$Blocks.Add($FunctionAst.Body.BeginBlock)
  }

  if ($Null -ne $FunctionAst.Body.ProcessBlock) {
    [void]$Blocks.Add($FunctionAst.Body.ProcessBlock)
  }

  if ($Null -ne $FunctionAst.Body.EndBlock -and $FunctionAst.Body.EndBlock.Unnamed -eq $False) {
    [void]$Blocks.Add($FunctionAst.Body.EndBlock)
  }

  [System.Management.Automation.Language.NamedBlockAst[]]@(
    $Blocks | Sort-Object -Property { $PSItem.Extent.StartOffset }
  )

}

function Get-HouseRuleFunctionAttribute {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.Language.AttributeAst[]])]
  param (
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $AttributeName,

    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  if ($Null -eq $FunctionAst.Body.ParamBlock) {
    return
  }

  $FunctionAst.Body.ParamBlock.Attributes |
    Where-Object -FilterScript {
      $PSItem -is [System.Management.Automation.Language.AttributeAst] -and
      (
        (
          ([System.String]$PSItem.TypeName.FullName) -replace
          '^(System\.Management\.Automation\.)?',
          ''
        ) -replace 'Attribute$',
        ''
      ) -ieq $AttributeName
    }

}

function Get-HouseRuleAttributeName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.AttributeAst]
    $AttributeAst
  )

  [System.String](
    (
      ([System.String]$AttributeAst.TypeName.FullName) -replace
      '^(System\.Management\.Automation\.)?',
      ''
    ) -replace 'Attribute$',
    ''
  )

}

function Get-HouseRuleParameterAttributeOrderKey {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.AttributeBaseAst]
    $AttributeAst
  )

  if ($AttributeAst -is [System.Management.Automation.Language.TypeConstraintAst]) {
    return [System.String]'3|'
  }

  if ($AttributeAst -isnot [System.Management.Automation.Language.AttributeAst]) {
    return [System.String]'2|'
  }

  $Private:AttributeName = Get-HouseRuleAttributeName -AttributeAst $AttributeAst

  if ($AttributeName -ieq 'Parameter') {
    return [System.String]'0|Parameter'
  }

  if ($AttributeName -ieq 'Alias') {
    return [System.String]'1|Alias'
  }

  [System.String]('2|{0}' -f $AttributeName)

}

function Test-HouseRuleAlphabeticalOrder {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [AllowEmptyCollection()]
    [System.String[]]
    $Value
  )

  for ($Index = 1; $Index -lt $Value.Count; $Index++) {
    if ([System.StringComparer]::OrdinalIgnoreCase.Compare($Value[$Index - 1], $Value[$Index]) -gt 0) {
      return [System.Boolean]$False
    }
  }

  [System.Boolean]$True

}

function Test-HouseRuleNamedArgumentValueIsTrue {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.NamedAttributeArgumentAst]
    $NamedArgument
  )

  if ($Null -eq $NamedArgument.Argument) {
    return [System.Boolean]$True
  }

  if ($NamedArgument.Argument.Extent.Text -ieq $NamedArgument.ArgumentName) {
    return [System.Boolean]$True
  }

  try {
    return [System.Boolean]$NamedArgument.Argument.SafeGetValue()
  } catch {
    return [System.Boolean]$False
  }

}

function Get-HouseRuleNamedAttributeArgument {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.Language.NamedAttributeArgumentAst])]
  param (
    [Parameter(Mandatory = $True)]
    [System.String]
    $ArgumentName,

    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.AttributeAst]
    $AttributeAst
  )

  foreach ($NamedArgument in $AttributeAst.NamedArguments) {
    if ($NamedArgument.ArgumentName -ieq $ArgumentName) {
      return [System.Management.Automation.Language.NamedAttributeArgumentAst]$NamedArgument
    }
  }

  $Null

}

function Test-HouseRuleNamedArgumentValueEqual {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [AllowNull()]
    [System.Object]
    $ExpectedValue,

    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.NamedAttributeArgumentAst]
    $NamedArgument
  )

  # Bare attribute flags are intentionally rejected here; house style spells out the value.
  if ($Null -eq $NamedArgument.Argument) {
    return [System.Boolean]$False
  }

  try {
    $Private:ActualValue = $NamedArgument.Argument.SafeGetValue()
  } catch {
    return [System.Boolean]$False
  }

  [System.Boolean]([System.Object]::Equals($ActualValue, $ExpectedValue))

}

function Test-HouseRuleParameterAttributeOrder {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ParameterAst]
    $ParameterAst
  )

  # Initialize Variable(s)
  [System.String]$Private:CurrentKey = [System.String]::Empty
  [System.Boolean]$Private:HasPreviousKey = $False
  [System.String]$Private:PreviousKey = [System.String]::Empty

  foreach ($AttributeAst in $ParameterAst.Attributes) {
    $CurrentKey = Get-HouseRuleParameterAttributeOrderKey -AttributeAst $AttributeAst

    if (
      $HasPreviousKey -eq $True -and
      [System.StringComparer]::OrdinalIgnoreCase.Compare($PreviousKey, $CurrentKey) -gt 0
    ) {
      return [System.Boolean]$False
    }

    $HasPreviousKey = $True
    $PreviousKey = $CurrentKey
  }

  [System.Boolean]$True

}

function Test-HouseRuleParameterTypeLast {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ParameterAst]
    $ParameterAst
  )

  $Private:HasSeenType = $False

  foreach ($AttributeAst in $ParameterAst.Attributes) {
    if ($AttributeAst -is [System.Management.Automation.Language.TypeConstraintAst]) {
      $HasSeenType = $True
      continue
    }

    if (
      $HasSeenType -eq $True -and
      $AttributeAst -is [System.Management.Automation.Language.AttributeAst]
    ) {
      return [System.Boolean]$False
    }
  }

  [System.Boolean]$True

}

function Test-HouseRuleParameterOrderGuard {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.FunctionDefinitionAst]
    $FunctionAst
  )

  foreach ($CmdletBindingAttribute in Get-HouseRuleFunctionAttribute -FunctionAst $FunctionAst -AttributeName 'CmdletBinding') {
    foreach ($NamedArgument in $CmdletBindingAttribute.NamedArguments) {
      if ($NamedArgument.ArgumentName -ine 'PositionalBinding') {
        continue
      }

      if ((Test-HouseRuleNamedArgumentValueIsTrue -NamedArgument $NamedArgument) -eq $True) {
        return [System.Boolean]$True
      }
    }
  }

  if ($Null -eq $FunctionAst.Body.ParamBlock) {
    return [System.Boolean]$False
  }

  foreach ($ParameterAst in $FunctionAst.Body.ParamBlock.Parameters) {
    foreach ($AttributeAst in $ParameterAst.Attributes) {
      if ($AttributeAst -isnot [System.Management.Automation.Language.AttributeAst]) {
        continue
      }

      if ((Get-HouseRuleAttributeName -AttributeAst $AttributeAst) -ine 'Parameter') {
        continue
      }

      foreach ($NamedArgument in $AttributeAst.NamedArguments) {
        if ($NamedArgument.ArgumentName -ieq 'Position') {
          return [System.Boolean]$True
        }
      }
    }
  }

  [System.Boolean]$False

}

function Get-HouseRuleProcessResetVariableName {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.NamedBlockAst]
    $ProcessBlock
  )

  $Private:Names = [System.Collections.Generic.List[System.String]]::new()
  [System.Boolean]$Private:CanSkipEnteringProcess = $True

  foreach ($Statement in $ProcessBlock.Statements) {
    if (
      $CanSkipEnteringProcess -eq $True -and
      (Test-HouseRuleEnteringProcessDebugStatement -StatementAst $Statement) -eq $True
    ) {
      $CanSkipEnteringProcess = $False
      continue
    }

    $CanSkipEnteringProcess = $False

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

    $Private:CommandAst = $Statement.PipelineElements[0]
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

function Test-HouseRuleEnteringProcessDebugStatement {
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.StatementAst]
    $StatementAst
  )

  if ($StatementAst -isnot [System.Management.Automation.Language.PipelineAst]) {
    return [System.Boolean]$False
  }

  if ($StatementAst.PipelineElements.Count -ne 1) {
    return [System.Boolean]$False
  }

  [System.Management.Automation.Language.CommandAst]$Private:CommandAst = $StatementAst.PipelineElements[0] -as [System.Management.Automation.Language.CommandAst]
  if ($Null -eq $CommandAst) {
    return [System.Boolean]$False
  }

  if ($CommandAst.GetCommandName() -inotmatch '^Write-Debug$') {
    return [System.Boolean]$False
  }

  foreach ($Message in Get-HouseRuleCommandArgumentString -CommandAst $CommandAst -ParameterName 'Message') {
    if ($Message -imatch '\]\s+Entering Process$') {
      return [System.Boolean]$True
    }
  }

  [System.Boolean]$False

}

function Measure-CanonicalAttributeOrder {
  <#
    .SYNOPSIS
        Flags non-canonical ordering in function declaration attributes and parameters.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

  foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
    foreach ($CmdletBindingAttribute in Get-HouseRuleFunctionAttribute -FunctionAst $FunctionAst -AttributeName 'CmdletBinding') {
      $Private:CmdletBindingOptionNames = [System.String[]]@(
        $CmdletBindingAttribute.NamedArguments |
          ForEach-Object -Process { $PSItem.ArgumentName }
      )

      if ((Test-HouseRuleAlphabeticalOrder -Value $CmdletBindingOptionNames) -eq $False) {
        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-CanonicalAttributeOrder' `
          -Extent $CmdletBindingAttribute.Extent `
          -Message (
          "Function '{0}' CmdletBinding options are not in alphabetical order (SG-5a)." -f
          $FunctionAst.Name
        )
      }
    }

    if ($Null -eq $FunctionAst.Body.ParamBlock) {
      continue
    }

    foreach ($ParameterAst in $FunctionAst.Body.ParamBlock.Parameters) {
      foreach ($AttributeAst in $ParameterAst.Attributes) {
        if ($AttributeAst -isnot [System.Management.Automation.Language.AttributeAst]) {
          continue
        }

        if ((Get-HouseRuleAttributeName -AttributeAst $AttributeAst) -ine 'Parameter') {
          continue
        }

        $Private:ParameterArgumentNames = [System.String[]]@(
          $AttributeAst.NamedArguments |
            ForEach-Object -Process { $PSItem.ArgumentName }
        )

        if ((Test-HouseRuleAlphabeticalOrder -Value $ParameterArgumentNames) -eq $False) {
          ConvertTo-HouseRuleDiagnosticRecord `
            -RuleName 'Measure-CanonicalAttributeOrder' `
            -Extent $AttributeAst.Extent `
            -Message (
            "Function '{0}' parameter '{1}' Parameter attribute arguments are not in alphabetical order (SG-5b)." -f
            $FunctionAst.Name,
            (Get-HouseRuleVariableName -VariableAst $ParameterAst.Name)
          )
        }

        foreach ($NamedArgument in $AttributeAst.NamedArguments) {
          if ($NamedArgument.ArgumentName -ine 'Position') {
            continue
          }

          ConvertTo-HouseRuleDiagnosticRecord `
            -RuleName 'Measure-CanonicalAttributeOrder' `
            -Extent $NamedArgument.Extent `
            -Message (
            "Function '{0}' parameter '{1}' must not use Parameter(Position); PositionalBinding must stay false (SG-5e)." -f
            $FunctionAst.Name,
            (Get-HouseRuleVariableName -VariableAst $ParameterAst.Name)
          )
        }

      }

      if ((Test-HouseRuleParameterTypeLast -ParameterAst $ParameterAst) -eq $False) {
        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-CanonicalAttributeOrder' `
          -Extent $ParameterAst.Extent `
          -Message (
          "Function '{0}' parameter '{1}' has an attribute after the type literal; the type must be last before the variable (SG-5c)." -f
          $FunctionAst.Name,
          (Get-HouseRuleVariableName -VariableAst $ParameterAst.Name)
        )
      }

      if ((Test-HouseRuleParameterAttributeOrder -ParameterAst $ParameterAst) -eq $False) {
        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-CanonicalAttributeOrder' `
          -Extent $ParameterAst.Extent `
          -Message (
          "Function '{0}' parameter '{1}' attributes are not in canonical Parameter/Alias/attribute/type order (SG-5c)." -f
          $FunctionAst.Name,
          (Get-HouseRuleVariableName -VariableAst $ParameterAst.Name)
        )
      }
    }

    $Private:ParameterNames = [System.String[]]@(Get-HouseRuleParameterName -FunctionAst $FunctionAst)
    if ((Test-HouseRuleAlphabeticalOrder -Value $ParameterNames) -eq $True) {
      continue
    }

    ConvertTo-HouseRuleDiagnosticRecord `
      -RuleName 'Measure-CanonicalAttributeOrder' `
      -Extent $FunctionAst.Body.ParamBlock.Extent `
      -Message (
      "Function '{0}' parameters are not in alphabetical order by name (SG-5d)." -f
      $FunctionAst.Name
    )
  }

}

function Measure-ExplicitCmdletBinding {
  <#
    .SYNOPSIS
        Flags functions missing the house explicit CmdletBinding surface.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

  # Initialize Variable(s)
  [System.Management.Automation.Language.AttributeAst]$Private:CmdletBindingAttribute = $Null
  [System.Management.Automation.Language.AttributeAst[]]$Private:CmdletBindingAttributes = @()
  [System.Boolean]$Private:HasOutputType = $False
  [System.String[]]$Private:RequiredOptionNames = @(
    'SupportsShouldProcess',
    'ConfirmImpact',
    'PositionalBinding',
    'DefaultParameterSetName',
    'HelpUri',
    'SupportsPaging'
  )
  [System.Collections.Generic.HashSet[System.String]]$Private:SeenOptionNames = $Null

  foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
    $CmdletBindingAttributes = [System.Management.Automation.Language.AttributeAst[]]@(
      Get-HouseRuleFunctionAttribute -FunctionAst $FunctionAst -AttributeName 'CmdletBinding'
    )
    $CmdletBindingAttribute = $Null
    if ($CmdletBindingAttributes.Count -gt 0) {
      $CmdletBindingAttribute = $CmdletBindingAttributes[0]
    }

    if ($Null -eq $CmdletBindingAttribute) {
      ConvertTo-HouseRuleDiagnosticRecord `
        -RuleName 'Measure-ExplicitCmdletBinding' `
        -Extent $FunctionAst.Extent `
        -Message (
        "Function '{0}' is missing the explicit CmdletBinding attribute required by SG-4." -f
        $FunctionAst.Name
      )
    } else {
      $SeenOptionNames = [System.Collections.Generic.HashSet[System.String]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
      )
      foreach ($NamedArgument in $CmdletBindingAttribute.NamedArguments) {
        [void]$SeenOptionNames.Add($NamedArgument.ArgumentName)
      }

      foreach ($RequiredOptionName in $RequiredOptionNames) {
        if ($SeenOptionNames.Contains($RequiredOptionName) -eq $True) {
          continue
        }

        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-ExplicitCmdletBinding' `
          -Extent $CmdletBindingAttribute.Extent `
          -Message (
          "Function '{0}' CmdletBinding is missing explicit option '{1}' required by SG-4." -f
          $FunctionAst.Name,
          $RequiredOptionName
        )
      }

      $Private:PositionalBindingArgument = Get-HouseRuleNamedAttributeArgument `
        -ArgumentName 'PositionalBinding' `
        -AttributeAst $CmdletBindingAttribute

      if (
        $Null -ne $PositionalBindingArgument -and
        (Test-HouseRuleNamedArgumentValueEqual `
          -ExpectedValue $False `
          -NamedArgument $PositionalBindingArgument) -eq $False
      ) {
        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-ExplicitCmdletBinding' `
          -Extent $PositionalBindingArgument.Extent `
          -Message (
          "Function '{0}' CmdletBinding must set PositionalBinding = `$False required by SG-4." -f
          $FunctionAst.Name
        )
      }
    }

    $HasOutputType = [System.Boolean](
      @(
        Get-HouseRuleFunctionAttribute -FunctionAst $FunctionAst -AttributeName 'OutputType'
      ).Count -gt 0
    )
    if ($HasOutputType -eq $True) {
      continue
    }

    ConvertTo-HouseRuleDiagnosticRecord `
      -RuleName 'Measure-ExplicitCmdletBinding' `
      -Extent $FunctionAst.Extent `
      -Message (
      "Function '{0}' is missing the OutputType attribute required by SG-4." -f
      $FunctionAst.Name
    )
  }

}

function Measure-PrivateVariableDeclaration {
  <#
    .SYNOPSIS
        Flags function-local assignments that are not Private-scoped.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

  foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
    $Private:PrivateDeclarations = [System.Collections.Generic.HashSet[System.String]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )
    Get-HouseRulePrivateDeclarationName -FunctionAst $FunctionAst | ForEach-Object -Process {
      [void]$PrivateDeclarations.Add($PSItem)
    }

    $Private:ExemptNames = [System.Collections.Generic.HashSet[System.String]]::new(
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

function Measure-PipelineVariableLifecycle {
  <#
    .SYNOPSIS
        Flags pipeline function locals not declared in Begin or cleared at Process start.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

  foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
    if ((Test-HouseRulePipelineParameter -FunctionAst $FunctionAst) -eq $False) {
      continue
    }

    if ($Null -eq $FunctionAst.Body.BeginBlock -or $Null -eq $FunctionAst.Body.ProcessBlock) {
      continue
    }

    $Private:BeginDeclarations = [System.Collections.Generic.HashSet[System.String]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )
    Get-HouseRulePrivateDeclarationName -FunctionAst $FunctionAst -SearchAst $FunctionAst.Body.BeginBlock |
      ForEach-Object -Process {
        [void]$BeginDeclarations.Add($PSItem)
      }

    $Private:ResetNames = [System.Collections.Generic.HashSet[System.String]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )
    Get-HouseRuleProcessResetVariableName -ProcessBlock $FunctionAst.Body.ProcessBlock |
      ForEach-Object -Process {
        [void]$ResetNames.Add($PSItem)
      }

    $Private:ExemptNames = [System.Collections.Generic.HashSet[System.String]]::new(
      [System.StringComparer]::OrdinalIgnoreCase
    )
    Get-HouseRuleParameterName -FunctionAst $FunctionAst | ForEach-Object -Process {
      [void]$ExemptNames.Add($PSItem)
    }
    Get-HouseRuleIteratorName -FunctionAst $FunctionAst | ForEach-Object -Process {
      [void]$ExemptNames.Add($PSItem)
    }

    $Private:AssignedNames = [System.Collections.Generic.Dictionary[
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

function Measure-FlatNonPipelineFunction {
  <#
    .SYNOPSIS
        Flags named blocks on functions that do not accept pipeline input.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

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

function Measure-CanonicalNamedBlock {
  <#
    .SYNOPSIS
        Flags non-canonical named block casing and brace layout.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

  foreach ($FunctionAst in Get-HouseRuleFunctionAst -ScriptBlockAst $ScriptBlockAst) {
    [System.Management.Automation.Language.NamedBlockAst[]]$Private:Blocks = @(
      Get-HouseRuleNamedBlockAst -FunctionAst $FunctionAst
    )

    foreach ($Block in $Blocks) {
      [System.String]$Private:ExpectedHeader = '{0} {{' -f $Block.BlockKind.ToString()
      [System.String]$Private:HeaderPattern = '^\s*{0}\s*\{{' -f [System.Text.RegularExpressions.Regex]::Escape($Block.BlockKind.ToString())

      if ($Block.Extent.Text -cnotmatch $HeaderPattern) {
        ConvertTo-HouseRuleDiagnosticRecord `
          -RuleName 'Measure-CanonicalNamedBlock' `
          -Extent $Block.Extent `
          -Message (
          "Function '{0}' named block must start with '{1}'." -f
          $FunctionAst.Name,
          $ExpectedHeader
        )
      }
    }

    for ($Index = 1; $Index -lt $Blocks.Count; $Index++) {
      [System.Management.Automation.Language.NamedBlockAst]$Private:PreviousBlock = $Blocks[$Index - 1]
      [System.Management.Automation.Language.NamedBlockAst]$Private:CurrentBlock = $Blocks[$Index]

      if ($PreviousBlock.Extent.EndLineNumber -eq $CurrentBlock.Extent.StartLineNumber) {
        continue
      }

      ConvertTo-HouseRuleDiagnosticRecord `
        -RuleName 'Measure-CanonicalNamedBlock' `
        -Extent $CurrentBlock.Extent `
        -Message (
        "Function '{0}' named block transition must be cuddled as '}} {1} {{'." -f
        $FunctionAst.Name,
        $CurrentBlock.BlockKind.ToString()
      )
    }
  }

}

function Measure-NoRemoveVariableCleanup {
  <#
    .SYNOPSIS
        Flags Remove-Variable cleanup in function End blocks.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

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

function Measure-NoNewVariableDeclaration {
  <#
    .SYNOPSIS
        Flags New-Variable local declarations inside functions.
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/NWarila/powershell-template/blob/main/docs/README.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
  param (
    [Parameter(Mandatory = $True)]
    [System.Management.Automation.Language.ScriptBlockAst]
    $ScriptBlockAst
  )

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

Export-ModuleMember -Function 'Measure-*'

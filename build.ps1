#Requires -Version 5.1

<#
.SYNOPSIS
    Builds, analyzes, and tests the certificate store exporter.

.PARAMETER Task
    One or more tasks to run: Build, Test, Analyze, Clean, or All.

.EXAMPLE
    .\build.ps1 -Task All
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Build', 'Test', 'Analyze', 'Clean', 'All')]
    [System.String[]]
    $Task = 'Build'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$ProjectRoot = [System.String]$PSScriptRoot
$ProjectName = 'Export-CertificateStoreBundle'
$SourceRoot = Join-Path -Path $ProjectRoot -ChildPath 'src'
$TestRoot = Join-Path -Path $ProjectRoot -ChildPath 'tests'
$BuildRoot = Join-Path -Path $ProjectRoot -ChildPath 'build'
$OutputFile = Join-Path -Path $BuildRoot -ChildPath ('{0}.ps1' -f $ProjectName)
$FunctionsFile = Join-Path -Path $BuildRoot -ChildPath ('{0}.Functions.ps1' -f $ProjectName)

function Get-LatestAvailableModule {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    Get-Module -ListAvailable -Name $Name |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
}

function Test-Syntax {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Path
    )

    $private:Messages = [System.Collections.Generic.List[System.String]]::new()

    $Path | ForEach-Object -Process {
        $private:ScriptPath = [System.String]$PSItem
        if (-not (Test-Path -LiteralPath $ScriptPath)) {
            return
        }

        $private:Tokens = $Null
        $private:ParseErrors = $Null
        $Null = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptPath,
            [ref]$Tokens,
            [ref]$ParseErrors
        )

        if ($ParseErrors.Count -gt 0) {
            $ParseErrors | ForEach-Object -Process {
                $Messages.Add(
                    (
                        '{0}: line {1}: {2}' -f
                        $ScriptPath,
                        $PSItem.Extent.StartLineNumber,
                        $PSItem.Message
                    )
                )
            }
        }
    }

    if ($Messages.Count -gt 0) {
        throw (
            'Syntax errors detected:{0}{1}' -f
            [System.Environment]::NewLine,
            ($Messages -join [System.Environment]::NewLine)
        )
    }
}

function Get-EntryPointContent {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([PSCustomObject])]
    param ()

    $private:EntryPointPath = Join-Path -Path $SourceRoot -ChildPath 'EntryPoint.ps1'
    $private:EntryPointText = (Get-Content -LiteralPath $EntryPointPath -Raw).Trim()
    $private:EntryPointLines = [System.String[]]($EntryPointText -split '\r?\n')
    $private:ParamEnd = -1
    $private:InParamBlock = $False
    $private:ParenDepth = 0

    for ($Index = 0; $Index -lt $EntryPointLines.Count; $Index++) {
        $private:Line = [System.String]$EntryPointLines[$Index]
        $private:TrimmedLine = $Line.Trim()

        if ($InParamBlock -eq $False -and $TrimmedLine -match '^Param\s*\(') {
            $InParamBlock = $True
        }

        if ($InParamBlock -eq $True) {
            $private:OpenParenCount = ([regex]::Matches($Line, '\(')).Count
            $private:CloseParenCount = ([regex]::Matches($Line, '\)')).Count
            $ParenDepth += ($OpenParenCount - $CloseParenCount)

            if ($ParenDepth -eq 0) {
                $ParamEnd = $Index
                break
            }
        }
    }

    if ($ParamEnd -lt 0) {
        throw 'EntryPoint.ps1 must contain a Param block.'
    }

    [PSCustomObject]@{
        Lines    = $EntryPointLines
        ParamEnd = $ParamEnd
    }
}

function Add-FunctionFileContent {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Directory,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RegionName,

        [Parameter(Mandatory = $True)]
        [System.Text.StringBuilder]
        $StringBuilder
    )

    $private:FunctionFiles = @(
        Get-ChildItem `
            -LiteralPath $Directory `
            -Filter '*.ps1' `
            -ErrorAction SilentlyContinue |
            Sort-Object -Property Name
    )

    if ($FunctionFiles.Count -eq 0) {
        return
    }

    $Null = $StringBuilder.AppendLine(('#region {0}' -f $RegionName))
    $Null = $StringBuilder.AppendLine('')

    $FunctionFiles | ForEach-Object -Process {
        $private:Content = (Get-Content -LiteralPath $PSItem.FullName -Raw).Trim()
        $Content = $Content -replace '(?m)^#Requires[^\r\n]*(\r?\n)?', ''
        $Null = $StringBuilder.AppendLine($Content.Trim())
        $Null = $StringBuilder.AppendLine('')
    }

    $Null = $StringBuilder.AppendLine('#endregion')
    $Null = $StringBuilder.AppendLine('')
}

function Invoke-SmokeTest {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param ()

    $private:SmokeRoot = Join-Path -Path $TestRoot -ChildPath 'Smoke'
    $private:SmokeFiles = @(
        Get-ChildItem `
            -LiteralPath $SmokeRoot `
            -Filter '*.ps1' `
            -ErrorAction SilentlyContinue |
            Sort-Object -Property Name
    )

    if ($SmokeFiles.Count -eq 0) {
        Write-Warning -Message 'No smoke tests found.'
        return
    }

    $SmokeFiles | ForEach-Object -Process {
        Write-Information -MessageData ('Smoke: {0}' -f $PSItem.Name) -InformationAction Continue
        & $PSItem.FullName
    }
}

function Invoke-Build {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param ()

    if (-not (Test-Path -LiteralPath $BuildRoot)) {
        $Null = New-Item -Path $BuildRoot -ItemType Directory
    }

    $private:EntryPoint = Get-EntryPointContent
    $private:FunctionBuilder = [System.Text.StringBuilder]::new(32768)
    $Null = $FunctionBuilder.AppendLine('#Requires -Version 5.1')
    $Null = $FunctionBuilder.AppendLine('')

    Add-FunctionFileContent `
        -StringBuilder $FunctionBuilder `
        -Directory (Join-Path -Path $SourceRoot -ChildPath 'Private') `
        -RegionName 'Private Functions'

    Add-FunctionFileContent `
        -StringBuilder $FunctionBuilder `
        -Directory (Join-Path -Path $SourceRoot -ChildPath 'Public') `
        -RegionName 'Public Functions'

    $private:FunctionsContent = $FunctionBuilder.ToString().TrimEnd() + [System.Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $FunctionsFile,
        $FunctionsContent,
        [System.Text.UTF8Encoding]::new($False)
    )

    $private:FullBuilder = [System.Text.StringBuilder]::new(32768)
    $Null = $FullBuilder.AppendLine('#Requires -Version 5.1')
    $Null = $FullBuilder.AppendLine('')

    for ($Index = 0; $Index -le $EntryPoint.ParamEnd; $Index++) {
        $private:Line = [System.String]$EntryPoint.Lines[$Index]
        if ($Line.Trim() -match '^#Requires') {
            continue
        }

        $Null = $FullBuilder.AppendLine($Line)
    }

    $Null = $FullBuilder.AppendLine('')
    $private:FunctionBody = $FunctionsContent -replace '(?s)^#Requires[^\r\n]*\r?\n\r?\n', ''
    $Null = $FullBuilder.Append($FunctionBody)
    $Null = $FullBuilder.AppendLine('#region Entry Point')
    $Null = $FullBuilder.AppendLine('')

    for ($Index = ($EntryPoint.ParamEnd + 1); $Index -lt $EntryPoint.Lines.Count; $Index++) {
        $Null = $FullBuilder.AppendLine([System.String]$EntryPoint.Lines[$Index])
    }

    $Null = $FullBuilder.AppendLine('')
    $Null = $FullBuilder.AppendLine('#endregion')

    $private:FullContent = $FullBuilder.ToString().TrimEnd() + [System.Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $OutputFile,
        $FullContent,
        [System.Text.UTF8Encoding]::new($False)
    )

    Test-Syntax -Path @($FunctionsFile, $OutputFile)
    Write-Information -MessageData ('Build complete: {0}' -f $OutputFile) -InformationAction Continue
}

function Invoke-Analyze {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param ()

    if (-not (Test-Path -LiteralPath $OutputFile)) {
        Invoke-Build
    }

    $private:AnalyzerRuleFile = Join-Path -Path $ProjectRoot -ChildPath 'analyzers\HouseRules.psm1'
    $private:SyntaxTargets = @(
        Join-Path -Path $ProjectRoot -ChildPath 'build.ps1'
        $AnalyzerRuleFile
        $OutputFile
        $FunctionsFile
    )

    Test-Syntax -Path $SyntaxTargets

    $private:AnalyzerModule = Get-LatestAvailableModule -Name 'PSScriptAnalyzer'
    if ($Null -eq $AnalyzerModule) {
        Write-Warning -Message 'PSScriptAnalyzer is not installed. Syntax validation passed.'
        return
    }

    Import-Module -Name $AnalyzerModule.Path -Force

    $private:SettingsFile = Join-Path -Path $ProjectRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
    $private:Results = @(
        Invoke-ScriptAnalyzer -Path $OutputFile -Settings $SettingsFile
        Invoke-ScriptAnalyzer -Path $FunctionsFile -Settings $SettingsFile
        Invoke-ScriptAnalyzer -Path $AnalyzerRuleFile -Settings $SettingsFile
        Invoke-ScriptAnalyzer -Path (Join-Path -Path $ProjectRoot -ChildPath 'build.ps1') -Settings $SettingsFile
    )

    if ($Results.Count -gt 0) {
        $private:FormattedResults = $Results |
            Format-Table -Property RuleName, Severity, ScriptName, Line, Message -AutoSize |
            Out-String
        Write-Information -MessageData $FormattedResults -InformationAction Continue

        throw ('PSScriptAnalyzer found {0} issue(s).' -f $Results.Count)
    }

    Write-Information -MessageData 'Analysis passed.' -InformationAction Continue
}

function Invoke-Test {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param ()

    if (-not (Test-Path -LiteralPath $FunctionsFile)) {
        Invoke-Build
    }

    Invoke-SmokeTest

    $private:PesterModule = Get-LatestAvailableModule -Name 'Pester'
    if ($Null -eq $PesterModule -or $PesterModule.Version.Major -lt 5) {
        throw 'Pester 5 or newer is required for tests and coverage.'
    }

    Import-Module -Name $PesterModule.Path -Force

    $private:PesterConfig = [PesterConfiguration]::Default
    $PesterConfig.Run.Path = $TestRoot
    $PesterConfig.Run.Throw = $True
    $PesterConfig.Output.Verbosity = 'Detailed'
    $PesterConfig.TestResult.Enabled = $True
    $PesterConfig.TestResult.OutputFormat = 'NUnitXml'
    $PesterConfig.TestResult.OutputPath = Join-Path -Path $BuildRoot -ChildPath 'testResults.xml'
    $PesterConfig.CodeCoverage.Enabled = $True
    $PesterConfig.CodeCoverage.Path = $FunctionsFile
    $PesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $PesterConfig.CodeCoverage.OutputPath = Join-Path -Path $BuildRoot -ChildPath 'coverage.xml'
    $PesterConfig.CodeCoverage.CoveragePercentTarget = 90

    Invoke-Pester -Configuration $PesterConfig
}

function Invoke-Clean {
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/README.md',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Void])]
    param ()

    if (Test-Path -LiteralPath $BuildRoot) {
        Remove-Item -LiteralPath $BuildRoot -Recurse -Force
    }

    Write-Information -MessageData 'Clean complete.' -InformationAction Continue
}

if ('All' -in $Task) {
    $Task = @('Clean', 'Build', 'Analyze', 'Test')
}

$Task | ForEach-Object -Process {
    Write-Information -MessageData ('{0}=== {1} ===' -f [System.Environment]::NewLine, $PSItem) -InformationAction Continue
    & "Invoke-$PSItem"
}

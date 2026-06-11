#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Runs the windows-certificate-store-exporter Pester v5 suite.

.DESCRIPTION
    Builds a PesterConfiguration object explicitly so local and CI runs share
    the same behavior. Emits an NUnit XML result file and a JaCoCo coverage
    report under the output directory, and enforces a minimum coverage target.

.PARAMETER OutputPath
    Directory for the NUnit result and coverage report. Created if missing.

.PARAMETER MinimumCoverage
    Minimum line-coverage percentage required for the run to succeed.
#>
[CmdletBinding()]
param(
    [string]$OutputPath,
    [ValidateRange(0, 100)]
    [double]$MinimumCoverage = 80
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path -Path $PSScriptRoot -ChildPath '../TestResults'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
if (-not (Test-Path -LiteralPath $OutputPath)) {
    $null = New-Item -ItemType Directory -Path $OutputPath -Force
}
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Run.Throw = $true
$config.Output.Verbosity = 'Detailed'

$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = Join-Path -Path $OutputPath -ChildPath 'pester-results.xml'

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = Join-Path -Path $repoRoot -ChildPath 'windows-certificate-store-exporter.ps1'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = Join-Path -Path $OutputPath -ChildPath 'coverage.xml'
$config.CodeCoverage.CoveragePercentTarget = $MinimumCoverage

Invoke-Pester -Configuration $config

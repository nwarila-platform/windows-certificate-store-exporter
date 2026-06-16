#Requires -Version 5.1

[CmdletBinding(
  ConfirmImpact = 'Medium',
  DefaultParameterSetName = 'default',
  HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/cli-contract.md',
  PositionalBinding = $False,
  SupportsPaging = $False,
  SupportsShouldProcess = $True
)]
Param (
  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidatePattern('^\d{3}$')]
  [System.String]
  $DebugLevel = '000',

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $IncludeExpired,

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidatePattern('^\d{7}$')]
  [System.String]
  $LogLevel = '1111111',

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidateRange(1, [System.Int32]::MaxValue)]
  [System.Int32]
  $MinimumCertificateCount = 1,

  [Parameter(
    DontShow = $False,
    Mandatory = $True,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidateNotNullOrEmpty()]
  [System.String]
  $Path,

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidateSet('LocalMachine', 'CurrentUser')]
  [System.String]
  $StoreLocation = 'LocalMachine',

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [ValidateSet('Root', 'CA')]
  [System.String[]]
  $StoreName = @('Root', 'CA'),

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $Trap,

  [Parameter(
    DontShow = $False,
    Mandatory = $False,
    ParameterSetName = 'default',
    ValueFromPipeline = $False,
    ValueFromPipelineByPropertyName = $False
  )]
  [System.Management.Automation.SwitchParameter]
  $WriteManifest
)

# This file is not a function. build.ps1 folds this body after the merged
# Private/Public function definitions.

Trap {
  $Script:ExitCode = 1

  If ($Script:TrapEnabled -eq $True) {
    Write-Error -ErrorRecord $PSItem -ErrorAction Continue
  }

  Exit ([System.Int32]$Script:ExitCode)
}

#region Initialization

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$Script:ExitCode = 0
$Script:TrapEnabled = [System.Boolean]$Trap.IsPresent

$EnvironmentContext = [PSCustomObject]@{
  DebugLevel = $DebugLevel
  LogLevel   = $LogLevel
  Platform   = [System.Environment]::OSVersion.Platform.ToString()
  PSVersion  = $PSVersionTable.PSVersion.ToString()
}

Write-Debug -Message:(
  '[EntryPoint] Runtime context: PowerShell {0} on {1}' -f
  $EnvironmentContext.PSVersion,
  $EnvironmentContext.Platform
)

#endregion

#region Execution

$ExporterParameters = @{
  IncludeExpired          = $IncludeExpired
  MinimumCertificateCount = $MinimumCertificateCount
  Path                    = $Path
  StoreLocation           = $StoreLocation
  StoreName               = $StoreName
  WriteManifest           = $WriteManifest
}

Try {
  Write-Debug -Message '[EntryPoint] Invoking Export-CertificateStoreBundle'
  $Result = Export-CertificateStoreBundle @ExporterParameters

  If ($Null -ne $Result) {
    $Result
  }

  Write-Debug -Message '[EntryPoint] Exiting with code 0'
  Exit ([System.Int32]$Script:ExitCode)
} Catch {
  # Map a known exporter ErrorId to its process exit code. The short id is the leading segment
  #   before the first comma (ThrowTerminatingError appends ",<FunctionName>"). Success/Unhandled and
  #   unknown ids resolve to $Null, so the Throw below routes them to the trap as unhandled (exit 1).
  $ShortErrorId = ([System.String]$PSItem.FullyQualifiedErrorId -split ',', 2)[0]
  $ResolvedExitCode = $Null

  If ([System.Enum]::IsDefined([ExporterExitCode], $ShortErrorId) -eq $True) {
    $CandidateExitCode = [ExporterExitCode]$ShortErrorId

    If ($CandidateExitCode -notin @([ExporterExitCode]::Success, [ExporterExitCode]::Unhandled)) {
      $ResolvedExitCode = [System.Int32]$CandidateExitCode
    }
  }

  If ($Null -ne $ResolvedExitCode) {
    $Script:ExitCode = [System.Int32]$ResolvedExitCode

    If ($Script:TrapEnabled -eq $True) {
      Write-Error -ErrorRecord $PSItem -ErrorAction Continue
    }

    Exit ([System.Int32]$Script:ExitCode)
  }

  Throw
}

#endregion

#Requires -Version 5.1

[CmdletBinding(
    ConfirmImpact = 'Medium',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/cli-contract.md',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $True
)]
param (
    [Parameter()]
    [ValidatePattern('^\d{3}$')]
    [System.String]
    $DebugLevel = '000',

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $IncludeExpired,

    [Parameter()]
    [ValidatePattern('^\d{7}$')]
    [System.String]
    $LogLevel = '1111111',

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $MinimumCertificateCount = 1,

    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

    [Parameter()]
    [ValidateSet('LocalMachine', 'CurrentUser')]
    [System.String]
    $StoreLocation = 'LocalMachine',

    [Parameter()]
    [ValidateSet('Root', 'CA')]
    [System.String[]]
    $StoreName = @('Root', 'CA'),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $Trap,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $WriteManifest
)

# This file is not a function. build.ps1 folds this body after the merged
# Private/Public function definitions.

trap {
    $Script:ExitCode = 1

    if ($Script:TrapEnabled -eq $True) {
        Write-Error -ErrorRecord $PSItem -ErrorAction Continue
    }

    exit ([System.Int32]$Script:ExitCode)
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

try {
    Write-Debug -Message '[EntryPoint] Invoking Export-CertificateStoreBundle'
    $Result = Export-CertificateStoreBundle @ExporterParameters

    if ($Null -ne $Result) {
        $Result
    }

    Write-Debug -Message '[EntryPoint] Exiting with code 0'
    exit ([System.Int32]$Script:ExitCode)
} catch {
    $ResolvedExitCode = Resolve-ExitCode -ErrorRecord $PSItem

    if ($Null -ne $ResolvedExitCode) {
        $Script:ExitCode = [System.Int32]$ResolvedExitCode

        if ($Script:TrapEnabled -eq $True) {
            Write-Error -ErrorRecord $PSItem -ErrorAction Continue
        }

        exit ([System.Int32]$Script:ExitCode)
    }

    throw
}

#endregion

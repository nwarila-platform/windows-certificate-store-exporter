#Requires -Version 5.1

function New-ErrorRecord {
  <#
    .SYNOPSIS
        Creates or throws a structured PowerShell error record.

    .DESCRIPTION
        Creates an ErrorRecord using one of the exporter failure-class ErrorIds.
        The short ErrorId is the leading segment used by the EntryPoint exit-code
        resolver.

    .PARAMETER Message
        Human-readable error message.

    .PARAMETER ErrorId
        Stable error identifier.

    .PARAMETER Category
        PowerShell error category.

    .PARAMETER TargetObject
        Object related to the error.

    .PARAMETER IsFatal
        Throws the record as a terminating error instead of returning it.

    .EXAMPLE
        New-ErrorRecord -Message 'Example failure.' -ErrorId WriteFailure

    .OUTPUTS
        [System.Management.Automation.ErrorRecord]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#new-errorrecord',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Management.Automation.ErrorRecord])]
  param (
    [Parameter()]
    [System.Management.Automation.ErrorCategory]
    $Category = [System.Management.Automation.ErrorCategory]::InvalidOperation,

    [Parameter(Mandatory = $True)]
    [ExporterExitCode]
    $ErrorId,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $IsFatal,

    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Message,

    [Parameter()]
    [AllowNull()]
    [System.Object]
    $TargetObject = $Null
  )

  # Initialize Variable(s)
  [System.Management.Automation.ErrorRecord]$Private:ErrorRecord = $Null
  [System.InvalidOperationException]$Private:Exception = $Null

  $Exception = [System.InvalidOperationException]::new($Message)
  $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
    $Exception,
    $ErrorId.ToString(),
    $Category,
    $TargetObject
  )

  if ($IsFatal.IsPresent -eq $True) {
    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
  }

  $ErrorRecord
}

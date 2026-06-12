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
        New-ErrorRecord -Message 'Example failure.' -ErrorId ExampleFailure

    .OUTPUTS
        [System.Management.Automation.ErrorRecord]
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet(
            'NotWindows',
            'StoreReadFailure',
            'BelowMinimumCertificateCount',
            'WriteFailure'
        )]
        [System.String]
        $ErrorId,

        [Parameter()]
        [System.Management.Automation.ErrorCategory]
        $Category = [System.Management.Automation.ErrorCategory]::InvalidOperation,

        [Parameter()]
        [AllowNull()]
        [System.Object]
        $TargetObject = $Null,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IsFatal
    )

    begin {
        Write-Debug -Message '[New-ErrorRecord] Entering Begin'

        # Initalize Variable(s)
        [System.Management.Automation.ErrorRecord]$Private:ErrorRecord = $Null
        [System.InvalidOperationException]$Private:Exception = $Null

        Write-Debug -Message '[New-ErrorRecord] Exiting Begin'
    }

    process {
        $ErrorRecord = $Null
        $Exception = $Null
        Write-Debug -Message '[New-ErrorRecord] Entering Process'

        $Exception = [System.InvalidOperationException]::new($Message)
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            $ErrorId,
            $Category,
            $TargetObject
        )

        if ($IsFatal.IsPresent -eq $True) {
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        $ErrorRecord

        Write-Debug -Message '[New-ErrorRecord] Exiting Process'
    }

    end {
        Write-Debug -Message '[New-ErrorRecord] Entering End'
        Write-Debug -Message '[New-ErrorRecord] Exiting End'
    }
}

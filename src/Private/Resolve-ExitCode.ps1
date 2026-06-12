#Requires -Version 5.1

function Resolve-ExitCode {
    <#
    .SYNOPSIS
        Resolves exporter error records to process exit codes.

    .DESCRIPTION
        Maps known short exporter ErrorId values to their process exit codes.
        Unknown errors intentionally produce no output so the EntryPoint trap can
        handle them as unhandled failures.

    .PARAMETER ErrorRecord
        Error record to inspect.

    .EXAMPLE
        Resolve-ExitCode -ErrorRecord $ErrorRecord

    .OUTPUTS
        [System.Int32]
    #>
    [CmdletBinding()]
    [OutputType([System.Int32])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    begin {
        Write-Debug -Message '[Resolve-ExitCode] Entering Begin'
        Write-Debug -Message '[Resolve-ExitCode] Exiting Begin'
    }

    process {
        Write-Debug -Message '[Resolve-ExitCode] Entering Process'

        $ExitCodeByErrorId = @{}
        $ExitCodeByErrorId[$Script:CertificateStoreExporterErrorIdBelowMinimumCertificateCount] = 2
        $ExitCodeByErrorId[$Script:CertificateStoreExporterErrorIdNotWindows] = 3
        $ExitCodeByErrorId[$Script:CertificateStoreExporterErrorIdStoreReadFailure] = 4
        $ExitCodeByErrorId[$Script:CertificateStoreExporterErrorIdWriteFailure] = 5

        $FullyQualifiedErrorId = [System.String]$ErrorRecord.FullyQualifiedErrorId
        $ShortErrorId = [System.String]($FullyQualifiedErrorId -split ',', 2)[0]

        if ($ExitCodeByErrorId.ContainsKey($ShortErrorId)) {
            [System.Int32]$ExitCodeByErrorId[$ShortErrorId]
        }

        Write-Debug -Message '[Resolve-ExitCode] Exiting Process'
    }

    end {
        Write-Debug -Message '[Resolve-ExitCode] Entering End'
        Write-Debug -Message '[Resolve-ExitCode] Exiting End'
    }
}

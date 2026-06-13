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

    # Initalize Variable(s)
    [hashtable]$Private:ExitCodeByErrorId = $Null
    [System.String]$Private:FullyQualifiedErrorId = [System.String]::Empty
    [System.String]$Private:ShortErrorId = [System.String]::Empty

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
}

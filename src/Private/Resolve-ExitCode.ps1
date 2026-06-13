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
    [CmdletBinding(
        ConfirmImpact = 'None',
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#resolve-exitcode',
        PositionalBinding = $False,
        SupportsPaging = $False,
        SupportsShouldProcess = $False
    )]
    [OutputType([System.Int32])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    # Initalize Variable(s)
    [ExporterExitCode]$Private:ExitCode = [ExporterExitCode]::Unhandled
    [System.String]$Private:FullyQualifiedErrorId = [System.String]::Empty
    [System.String]$Private:ShortErrorId = [System.String]::Empty

    $FullyQualifiedErrorId = [System.String]$ErrorRecord.FullyQualifiedErrorId
    $ShortErrorId = [System.String]($FullyQualifiedErrorId -split ',', 2)[0]

    if ([System.Enum]::IsDefined([ExporterExitCode], $ShortErrorId) -eq $False) {
        return
    }

    $ExitCode = [ExporterExitCode]$ShortErrorId

    if ($ExitCode -in @([ExporterExitCode]::Success, [ExporterExitCode]::Unhandled)) {
        return
    }

    [System.Int32]$ExitCode
}

#Requires -Version 5.1

function Test-CertificateStoreExporterWindows {
    <#
    .SYNOPSIS
        Tests whether the exporter is running on Windows.

    .DESCRIPTION
        Provides a small internal platform seam so tests can force the
        non-Windows branch without weakening the production guard.

    .EXAMPLE
        Test-CertificateStoreExporterWindows

    .OUTPUTS
        [System.Boolean]
    #>
    [CmdletBinding(
        SupportsShouldProcess = $False,
        ConfirmImpact = 'None',
        PositionalBinding = $False,
        DefaultParameterSetName = 'default',
        HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#test-certificatestoreexporterwindows',
        SupportsPaging = $False
    )]
    [OutputType([System.Boolean])]
    param ()

    [System.Boolean](
        [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    )
}

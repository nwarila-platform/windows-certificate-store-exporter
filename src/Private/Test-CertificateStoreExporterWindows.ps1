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
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param ()

    begin {
        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Entering Begin'
        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Exiting Begin'
    }

    process {
        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Entering Process'

        [System.Boolean](
            [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
        )

        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Exiting Process'
    }

    end {
        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Entering End'
        Write-Debug -Message '[Test-CertificateStoreExporterWindows] Exiting End'
    }
}

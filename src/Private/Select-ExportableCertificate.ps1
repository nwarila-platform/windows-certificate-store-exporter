#Requires -Version 5.1

function Select-ExportableCertificate {
    <#
    .SYNOPSIS
        Selects certificates eligible for export.

    .DESCRIPTION
        Placeholder for the P2 selection helper. The P0 skeleton returns the
        supplied certificates unchanged and does not filter, de-duplicate, or
        subtract Disallowed certificates.

    .PARAMETER Certificate
        Candidate certificates.

    .PARAMETER DisallowedThumbprint
        SHA-256 thumbprints that will later be subtracted.

    .PARAMETER IncludeExpired
        Placeholder switch for the eventual validity filter.

    .EXAMPLE
        Select-ExportableCertificate -Certificate $Certificates

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
    param (
        [Parameter()]
        [AllowEmptyCollection()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
        $Certificate = @(),

        [Parameter()]
        [AllowEmptyCollection()]
        [System.String[]]
        $DisallowedThumbprint = @(),

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeExpired
    )

    begin {
        Write-Debug -Message '[Select-ExportableCertificate] Entering Begin'
        Write-Debug -Message '[Select-ExportableCertificate] Exiting Begin'
    }

    process {
        Write-Debug -Message '[Select-ExportableCertificate] Entering Process'
        Write-Debug -Message (
            '[Select-ExportableCertificate] Stubbed selection: disallowed={0}; includeExpired={1}' -f
            $DisallowedThumbprint.Count,
            $IncludeExpired.IsPresent
        )

        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@($Certificate)

        Write-Debug -Message '[Select-ExportableCertificate] Exiting Process'
    }

    end {
        Write-Debug -Message '[Select-ExportableCertificate] Entering End'
        Write-Debug -Message '[Select-ExportableCertificate] Exiting End'
    }
}

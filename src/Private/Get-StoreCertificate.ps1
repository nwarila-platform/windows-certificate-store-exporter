#Requires -Version 5.1

function Get-StoreCertificate {
    <#
    .SYNOPSIS
        Reads certificates from a Windows certificate store.

    .DESCRIPTION
        Placeholder for the P3 X509Store seam. The P0 skeleton returns an empty
        collection and performs no platform or store I/O.

    .PARAMETER StoreLocation
        Logical certificate store location.

    .PARAMETER StoreName
        Logical certificate store name.

    .EXAMPLE
        Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
    param (
        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $StoreLocation = 'LocalMachine',

        [Parameter()]
        [ValidateSet('Root', 'CA', 'Disallowed')]
        [System.String]
        $StoreName = 'Root'
    )

    begin {
        Write-Debug -Message '[Get-StoreCertificate] Entering Begin'

        # Initalize Variable(s)

        Write-Debug -Message '[Get-StoreCertificate] Exiting Begin'
    }

    process {
        Write-Debug -Message '[Get-StoreCertificate] Entering Process'
        Write-Debug -Message (
            '[Get-StoreCertificate] Stubbed read for {0}\{1}' -f
            $StoreLocation,
            $StoreName
        )

        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@()

        Write-Debug -Message '[Get-StoreCertificate] Exiting Process'
    }

    end {
        Write-Debug -Message '[Get-StoreCertificate] Entering End'
        Write-Debug -Message '[Get-StoreCertificate] Exiting End'
    }
}

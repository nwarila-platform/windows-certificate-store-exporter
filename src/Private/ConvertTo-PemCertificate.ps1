#Requires -Version 5.1

function ConvertTo-PemCertificate {
    <#
    .SYNOPSIS
        Converts a certificate into a PEM block.

    .DESCRIPTION
        Placeholder for the P2 PEM conversion helper. The P0 skeleton returns a
        deterministic stub string and does not encode certificate bytes.

    .PARAMETER Certificate
        Certificate that will eventually be converted.

    .PARAMETER StoreName
        Source store name used by the eventual PEM header.

    .EXAMPLE
        ConvertTo-PemCertificate -Certificate $Certificate -StoreName Root

    .OUTPUTS
        [System.String]
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $True)]
        [AllowNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter()]
        [ValidateSet('Root', 'CA', 'Disallowed')]
        [System.String]
        $StoreName = 'Root'
    )

    begin {
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering Begin'
        [System.Boolean]$Private:HasCertificate = $False
        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting Begin'
    }

    process {
        $HasCertificate = $False
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering Process'

        $HasCertificate = [System.Boolean]($Null -ne $Certificate)
        [System.String]('STUB-PEM:{0}:{1}' -f $StoreName, $HasCertificate)

        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting Process'
    }

    end {
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering End'
        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting End'
    }
}

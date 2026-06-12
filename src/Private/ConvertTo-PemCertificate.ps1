#Requires -Version 5.1

function ConvertTo-PemCertificate {
    <#
    .SYNOPSIS
        Converts a certificate into a PEM block.

    .DESCRIPTION
        Converts the certificate DER RawData into an RFC 7468 PEM block and
        prefixes certifi-style metadata comments. Distinguished-name values are
        kept ASCII by escaping backslashes as \\ and non-ASCII UTF-8 bytes as
        \xHH.

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
        [ValidateNotNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter()]
        [ValidateSet('Root', 'CA', 'Disallowed')]
        [System.String]
        $StoreName = 'Root'
    )

    begin {
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering Begin'

        # Initalize Variable(s)
        [System.String]$Private:Base64 = [System.String]::Empty
        [System.Byte[]]$Private:CharacterBytes = [System.Byte[]]@()
        [System.Int32]$Private:CharacterCode = 0
        [System.Text.StringBuilder]$Private:EscapedIssuerBuilder = $Null
        [System.Text.StringBuilder]$Private:EscapedSubjectBuilder = $Null
        [System.String]$Private:Issuer = [System.String]::Empty
        [System.Collections.Generic.List[System.String]]$Private:Lines = $Null
        [System.String]$Private:NotAfter = [System.String]::Empty
        [System.String]$Private:NotBefore = [System.String]::Empty
        [System.String]$Private:Sha256 = [System.String]::Empty
        [System.String]$Private:Subject = [System.String]::Empty

        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting Begin'
    }

    process {
        $Base64 = [System.String]::Empty
        $CharacterBytes = [System.Byte[]]@()
        $CharacterCode = 0
        $EscapedIssuerBuilder = $Null
        $EscapedSubjectBuilder = $Null
        $Issuer = [System.String]::Empty
        $Lines = $Null
        $NotAfter = [System.String]::Empty
        $NotBefore = [System.String]::Empty
        $Sha256 = [System.String]::Empty
        $Subject = [System.String]::Empty
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering Process'

        $EscapedSubjectBuilder = [System.Text.StringBuilder]::new()
        foreach ($Character in $Certificate.Subject.ToCharArray()) {
            $CharacterCode = [System.Int32]$Character

            if ($CharacterCode -eq 0x5C) {
                [void]$EscapedSubjectBuilder.Append('\\')
                continue
            }

            if ($CharacterCode -ge 0x20 -and $CharacterCode -le 0x7E) {
                [void]$EscapedSubjectBuilder.Append($Character)
                continue
            }

            $CharacterBytes = [System.Text.Encoding]::UTF8.GetBytes([System.String]$Character)
            foreach ($CharacterByte in $CharacterBytes) {
                [void]$EscapedSubjectBuilder.Append(('\x{0:X2}' -f $CharacterByte))
            }
        }

        $EscapedIssuerBuilder = [System.Text.StringBuilder]::new()
        foreach ($Character in $Certificate.Issuer.ToCharArray()) {
            $CharacterCode = [System.Int32]$Character

            if ($CharacterCode -eq 0x5C) {
                [void]$EscapedIssuerBuilder.Append('\\')
                continue
            }

            if ($CharacterCode -ge 0x20 -and $CharacterCode -le 0x7E) {
                [void]$EscapedIssuerBuilder.Append($Character)
                continue
            }

            $CharacterBytes = [System.Text.Encoding]::UTF8.GetBytes([System.String]$Character)
            foreach ($CharacterByte in $CharacterBytes) {
                [void]$EscapedIssuerBuilder.Append(('\x{0:X2}' -f $CharacterByte))
            }
        }

        $Subject = $EscapedSubjectBuilder.ToString()
        $Issuer = $EscapedIssuerBuilder.ToString()
        $Sha256 = Get-CertificateRawDataSha256 -Certificate $Certificate
        $NotBefore = $Certificate.NotBefore.ToUniversalTime().ToString(
            'yyyy-MM-ddTHH:mm:ssZ',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $NotAfter = $Certificate.NotAfter.ToUniversalTime().ToString(
            'yyyy-MM-ddTHH:mm:ssZ',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $Base64 = [System.Convert]::ToBase64String($Certificate.RawData)
        $Lines = [System.Collections.Generic.List[System.String]]::new()

        [void]$Lines.Add(('# Subject: {0}' -f $Subject))
        [void]$Lines.Add(('# Issuer: {0}' -f $Issuer))
        [void]$Lines.Add(('# Serial: {0}' -f $Certificate.SerialNumber))
        [void]$Lines.Add(('# SHA-256: {0}' -f $Sha256))
        [void]$Lines.Add(('# NotBefore: {0}' -f $NotBefore))
        [void]$Lines.Add(('# NotAfter: {0}' -f $NotAfter))
        [void]$Lines.Add(('# Source: {0}' -f $StoreName))
        [void]$Lines.Add('-----BEGIN CERTIFICATE-----')

        for ($Index = 0; $Index -lt $Base64.Length; $Index += 64) {
            [void]$Lines.Add(
                $Base64.Substring($Index, [System.Math]::Min(64, $Base64.Length - $Index))
            )
        }

        [void]$Lines.Add('-----END CERTIFICATE-----')

        [System.String]($Lines.ToArray() -join "`n")

        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting Process'
    }

    end {
        Write-Debug -Message '[ConvertTo-PemCertificate] Entering End'
        Write-Debug -Message '[ConvertTo-PemCertificate] Exiting End'
    }
}

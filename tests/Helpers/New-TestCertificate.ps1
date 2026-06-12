#Requires -Version 5.1

function New-TestCertificate {
    <#
    .SYNOPSIS
        Creates certificate fixtures for exporter tests.

    .DESCRIPTION
        Uses CertificateRequest with RSA-2048 and fixed validity windows. The
        returned certificate contains only public DER material. The temporary
        private key and self-signed certificate are disposed before returning.

    .PARAMETER Scenario
        Fixture shape to create.

    .PARAMETER DuplicateOf
        Existing certificate whose RawData should be cloned for a duplicate
        thumbprint fixture.

    .PARAMETER Subject
        Optional subject distinguished name.

    .EXAMPLE
        New-TestCertificate -Scenario Valid

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter()]
        [ValidateSet(
            'Valid',
            'Expired',
            'NotYetValid',
            'DuplicateThumbprint',
            'NoBasicConstraints',
            'Disallowed'
        )]
        [System.String]
        $Scenario = 'Valid',

        [Parameter()]
        [AllowNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $DuplicateOf = $Null,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Subject
    )

    process {
        if ($Scenario -eq 'DuplicateThumbprint') {
            if ($Null -eq $DuplicateOf) {
                throw 'DuplicateThumbprint fixtures require -DuplicateOf.'
            }

            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $DuplicateOf.RawData
            )
        }

        if ([System.String]::IsNullOrEmpty($Subject)) {
            $Subject = 'CN=Certificate Store Exporter {0}' -f $Scenario
        }

        $Validity = @{
            Disallowed         = @{
                NotBefore = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                NotAfter  = [System.DateTimeOffset]::new(2099, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
            }
            Expired            = @{
                NotBefore = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                NotAfter  = [System.DateTimeOffset]::new(2001, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
            }
            NoBasicConstraints = @{
                NotBefore = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                NotAfter  = [System.DateTimeOffset]::new(2099, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
            }
            NotYetValid        = @{
                NotBefore = [System.DateTimeOffset]::new(2099, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                NotAfter  = [System.DateTimeOffset]::new(2100, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
            }
            Valid              = @{
                NotBefore = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                NotAfter  = [System.DateTimeOffset]::new(2099, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
            }
        }

        $Rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $CreatedCertificate = $Null

        try {
            $DistinguishedName = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new(
                $Subject
            )
            $Request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                $DistinguishedName,
                $Rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
            )

            if ($Scenario -ne 'NoBasicConstraints') {
                $Request.CertificateExtensions.Add(
                    [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new(
                        $True,
                        $False,
                        0,
                        $True
                    )
                )
            }

            $Request.CertificateExtensions.Add(
                [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
                    (
                        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign -bor
                        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::CrlSign
                    ),
                    $True
                )
            )

            $CreatedCertificate = $Request.CreateSelfSigned(
                $Validity[$Scenario].NotBefore,
                $Validity[$Scenario].NotAfter
            )
            $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $CreatedCertificate.Export(
                    [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert
                )
            )

            if ($Scenario -eq 'Disallowed') {
                $Certificate |
                    Add-Member `
                        -NotePropertyName 'FixtureStoreName' `
                        -NotePropertyValue 'Disallowed' `
                        -Force
            }

            $Certificate
        }
        finally {
            if ($Null -ne $CreatedCertificate) {
                $CreatedCertificate.Dispose()
            }

            if ($Null -ne $Rsa) {
                $Rsa.Dispose()
            }
        }
    }
}

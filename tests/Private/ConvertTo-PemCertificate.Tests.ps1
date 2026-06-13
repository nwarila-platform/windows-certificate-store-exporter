#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'ConvertTo-PemCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')

        function Get-TestAsciiBytes {
            param (
                [Parameter(Mandatory = $True)]
                [System.String]
                $Text
            )

            [System.Text.Encoding]::UTF8.GetBytes($Text)
        }

        function Get-TestPemPayload {
            param (
                [Parameter(Mandatory = $True)]
                [System.String]
                $PemBlock
            )

            $Lines = [System.String[]]($PemBlock -split "`n")
            $BeginIndex = [System.Array]::IndexOf($Lines, '-----BEGIN CERTIFICATE-----')
            $EndIndex = [System.Array]::IndexOf($Lines, '-----END CERTIFICATE-----')

            ($Lines[($BeginIndex + 1)..($EndIndex - 1)] -join '')
        }
    }

    It 'emits an ASCII LF PEM block with certifi-style metadata and round-trippable DER' {
        $Certificate = New-TestCertificate -Scenario Valid -Subject 'CN=PEM Valid'

        try {
            $Result = ConvertTo-PemCertificate -Certificate $Certificate -StoreName Root
            $Bytes = Get-TestAsciiBytes -Text $Result
            $Lines = [System.String[]]($Result -split "`n")
            $ExpectedSha256 = Get-CertificateRawDataSha256 -Certificate $Certificate
            $ExpectedNotBefore = $Certificate.NotBefore.ToUniversalTime().ToString(
                'yyyy-MM-ddTHH:mm:ssZ',
                [System.Globalization.CultureInfo]::InvariantCulture
            )
            $ExpectedNotAfter = $Certificate.NotAfter.ToUniversalTime().ToString(
                'yyyy-MM-ddTHH:mm:ssZ',
                [System.Globalization.CultureInfo]::InvariantCulture
            )

            $Result.Contains("`r") | Should -BeFalse
            $Bytes[0..2] | Should -Not -Be ([System.Byte[]]@(0xEF, 0xBB, 0xBF))
            ($Bytes | Where-Object -FilterScript { $PSItem -gt 0x7F }) | Should -HaveCount 0

            $Lines[0] | Should -Be '# Subject: CN=PEM Valid'
            $Lines[1] | Should -Be '# Issuer: CN=PEM Valid'
            $Lines[2] | Should -Be ('# Serial: {0}' -f $Certificate.SerialNumber)
            $Lines[3] | Should -Be ('# SHA-256: {0}' -f $ExpectedSha256)
            $Lines[4] | Should -Be ('# NotBefore: {0}' -f $ExpectedNotBefore)
            $Lines[5] | Should -Be ('# NotAfter: {0}' -f $ExpectedNotAfter)
            $Lines[6] | Should -Be '# Source: Root'

            $BeginIndex = [System.Array]::IndexOf($Lines, '-----BEGIN CERTIFICATE-----')
            $EndIndex = [System.Array]::IndexOf($Lines, '-----END CERTIFICATE-----')
            $BeginIndex | Should -Be 7
            $EndIndex | Should -BeGreaterThan $BeginIndex

            $Base64Lines = [System.String[]]$Lines[($BeginIndex + 1)..($EndIndex - 1)]
            $Base64Lines[0..($Base64Lines.Count - 2)] | ForEach-Object -Process {
                $PSItem.Length | Should -Be 64
                $PSItem | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
            }
            $Base64Lines[-1].Length | Should -BeLessOrEqual 64
            $Base64Lines[-1] | Should -Match '^[A-Za-z0-9+/]+={0,2}$'

            $DecodedBytes = [System.Convert]::FromBase64String((Get-TestPemPayload -PemBlock $Result))
            $RoundTrip = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($DecodedBytes)

            try {
                [System.Convert]::ToBase64String($RoundTrip.RawData) |
                    Should -Be ([System.Convert]::ToBase64String($Certificate.RawData))
            } finally {
                $RoundTrip.Dispose()
            }
        } finally {
            $Certificate.Dispose()
        }
    }

    It 'escapes non-ASCII distinguished-name bytes as reversible UTF-8 hex escapes' {
        $NonAsciiSubject = 'CN=Jos' + [System.Char]0x00E9
        $Certificate = New-TestCertificate -Scenario Valid -Subject $NonAsciiSubject

        try {
            $Result = ConvertTo-PemCertificate -Certificate $Certificate -StoreName CA
            $Bytes = Get-TestAsciiBytes -Text $Result

            ($Bytes | Where-Object -FilterScript { $PSItem -gt 0x7F }) | Should -HaveCount 0
            $Result.Contains([System.String][System.Char]0x00E9) | Should -BeFalse
            $Result | Should -Match '\\xC3\\xA9'
            ([System.String[]]($Result -split "`n"))[0] | Should -Be '# Subject: CN=Jos\xC3\xA9'
            ([System.String[]]($Result -split "`n"))[1] | Should -Be '# Issuer: CN=Jos\xC3\xA9'
        } finally {
            $Certificate.Dispose()
        }
    }
}

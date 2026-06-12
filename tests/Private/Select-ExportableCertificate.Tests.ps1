#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Select-ExportableCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')

        function Get-TestCertificateSha256 {
            param (
                [Parameter(Mandatory = $True)]
                [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
                $Certificate
            )

            [System.String[]]@(
                $Certificate | ForEach-Object -Process {
                    Get-CertificateRawDataSha256 -Certificate $PSItem
                }
            )
        }
    }

    It 'returns an empty array for empty input' {
        $Result = Select-ExportableCertificate -Certificate @()

        $Result | Should -HaveCount 0
    }

    It 'drops expired and not-yet-valid certificates by default' {
        $Valid = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Valid'
        $Expired = New-TestCertificate -Scenario Expired -Subject 'CN=Selection Expired'
        $NotYetValid = New-TestCertificate -Scenario NotYetValid -Subject 'CN=Selection Future'

        try {
            $Result = Select-ExportableCertificate -Certificate @($Expired, $Valid, $NotYetValid)

            $Result | Should -HaveCount 1
            $Result[0] | Should -Be $Valid
        }
        finally {
            $NotYetValid.Dispose()
            $Expired.Dispose()
            $Valid.Dispose()
        }
    }

    It 'keeps expired and not-yet-valid certificates when IncludeExpired is present' {
        $Expired = New-TestCertificate -Scenario Expired -Subject 'CN=Selection Include Expired'
        $NotYetValid = New-TestCertificate -Scenario NotYetValid -Subject 'CN=Selection Include Future'

        try {
            $Result = Select-ExportableCertificate `
                -Certificate @($NotYetValid, $Expired) `
                -IncludeExpired
            $ExpectedHashes = Get-TestCertificateSha256 -Certificate @($Expired, $NotYetValid) |
                Sort-Object

            $Result | Should -HaveCount 2
            Get-TestCertificateSha256 -Certificate $Result | Should -Be $ExpectedHashes
        }
        finally {
            $NotYetValid.Dispose()
            $Expired.Dispose()
        }
    }

    It 'subtracts Disallowed certificates by SHA-256 case-insensitively' {
        $Valid = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Allowed'
        $Disallowed = New-TestCertificate -Scenario Disallowed -Subject 'CN=Selection Disallowed'

        try {
            $DisallowedHash = (Get-CertificateRawDataSha256 -Certificate $Disallowed).ToLowerInvariant()

            $Result = Select-ExportableCertificate `
                -Certificate @($Disallowed, $Valid) `
                -DisallowedThumbprint @($DisallowedHash)

            $Result | Should -HaveCount 1
            $Result[0] | Should -Be $Valid
        }
        finally {
            $Disallowed.Dispose()
            $Valid.Dispose()
        }
    }

    It 'collapses duplicate DER identities without disposing the retained certificate' {
        $Original = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Duplicate'
        $Duplicate = New-TestCertificate -Scenario DuplicateThumbprint -DuplicateOf $Original

        try {
            $Result = Select-ExportableCertificate -Certificate @($Duplicate, $Original)

            $Result | Should -HaveCount 1
            (Get-CertificateRawDataSha256 -Certificate $Result[0]) |
                Should -Be (Get-CertificateRawDataSha256 -Certificate $Original)
        }
        finally {
            $Duplicate.Dispose()
            $Original.Dispose()
        }
    }

    It 'keeps certificates without a BasicConstraints extension' {
        $Certificate = New-TestCertificate -Scenario NoBasicConstraints -Subject 'CN=Selection No Basic Constraints'

        try {
            $Result = Select-ExportableCertificate -Certificate @($Certificate)

            $Result | Should -HaveCount 1
            $Result[0] | Should -Be $Certificate
        }
        finally {
            $Certificate.Dispose()
        }
    }

    It 'sorts selected certificates ascending by SHA-256 regardless of input order' {
        $First = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort First'
        $Second = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort Second'
        $Third = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort Third'

        try {
            $Input = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
                $Third,
                $First,
                $Second
            )
            $ExpectedHashes = Get-TestCertificateSha256 -Certificate $Input | Sort-Object

            $Result = Select-ExportableCertificate -Certificate $Input

            Get-TestCertificateSha256 -Certificate $Result | Should -Be $ExpectedHashes
        }
        finally {
            $Third.Dispose()
            $Second.Dispose()
            $First.Dispose()
        }
    }
}

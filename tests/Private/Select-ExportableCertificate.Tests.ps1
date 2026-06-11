#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Select-ExportableCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'returns supplied certificates unchanged in the P0 skeleton' {
        $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()

        $Result = Select-ExportableCertificate `
            -Certificate @($Certificate) `
            -DisallowedThumbprint @('ABC') `
            -IncludeExpired

        $Result | Should -HaveCount 1
        $Result[0] | Should -Be $Certificate
    }
}

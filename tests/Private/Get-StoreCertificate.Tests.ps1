#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Get-StoreCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'returns an empty collection in the P0 skeleton' {
        $Result = Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root

        @($Result) | Should -HaveCount 0
    }
}

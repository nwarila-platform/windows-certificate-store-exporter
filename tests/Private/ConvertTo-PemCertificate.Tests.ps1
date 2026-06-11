#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'ConvertTo-PemCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'returns the P0 placeholder string without encoding bytes' {
        $Result = ConvertTo-PemCertificate -Certificate $Null -StoreName Root

        $Result | Should -Be 'STUB-PEM:Root:False'
    }
}

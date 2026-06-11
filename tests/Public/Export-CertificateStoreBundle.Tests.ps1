#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Export-CertificateStoreBundle' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'wires the placeholder helpers without writing a bundle' {
        $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'export-bundle.pem'

        $Result = Export-CertificateStoreBundle -Path $Path -StoreName Root -WhatIf

        $Result.Path | Should -Be $Path
        $Result.PemBlockCount | Should -Be 0
        $Result.WouldWrite | Should -BeFalse
        Test-Path -LiteralPath $Path | Should -BeFalse
    }
}

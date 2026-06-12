#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Export-CertificateStoreBundle' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'wires the placeholder helpers without writing a bundle' {
        $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'export-bundle.pem'

        $Result = Export-CertificateStoreBundle -Path $Path -StoreName Root -WhatIf

        $Result.PSTypeNames[0] | Should -Be 'CertificateStoreExporter.Result'
        $Result.Path | Should -Be $Path
        $Result.Status | Should -Be 'WhatIf'
        $Result.CertificateCount | Should -Be 0
        $Result.Thumbprints | Should -HaveCount 0
        $Result.BundleSha256 | Should -Be 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
        $Result.Examined | Should -Be 0
        $Result.Excluded.Expired | Should -Be 0
        $Result.Excluded.NotYetValid | Should -Be 0
        $Result.Excluded.Disallowed | Should -Be 0
        $Result.Excluded.Duplicate | Should -Be 0
        Test-Path -LiteralPath $Path | Should -BeFalse
    }
}

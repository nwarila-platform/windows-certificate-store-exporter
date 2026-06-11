#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Write-CertificateBundle' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'reports the placeholder write plan without touching disk' {
        $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bundle.pem'

        $Result = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @('one', 'two') `
            -MinimumCertificateCount 2 `
            -WriteManifest

        $Result.Path | Should -Be $Path
        $Result.PemBlockCount | Should -Be 2
        $Result.MinimumCertificateCount | Should -Be 2
        $Result.WriteManifest | Should -BeTrue
        $Result.WouldWrite | Should -BeTrue
        Test-Path -LiteralPath $Path | Should -BeFalse
    }

    It 'honors WhatIf through the single writer ShouldProcess call site' {
        $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'whatif-bundle.pem'

        $Result = Write-CertificateBundle -Path $Path -WhatIf

        $Result.WouldWrite | Should -BeFalse
        Test-Path -LiteralPath $Path | Should -BeFalse
    }
}

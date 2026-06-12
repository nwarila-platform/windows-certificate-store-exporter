#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Get-StoreCertificate' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'detects the supported Windows runtime in CI' {
        Test-CertificateStoreExporterWindows | Should -BeTrue
    }

    It 'throws NotWindows before touching a store when the platform guard fails' {
        Mock -CommandName Test-CertificateStoreExporterWindows -MockWith {
            $False
        }

        {
            Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root
        } | Should -Throw -ErrorId 'NotWindows,New-ErrorRecord'

        Should -Invoke -CommandName Test-CertificateStoreExporterWindows -Times 1 -Exactly
    }

    It 'wraps store factory failures with StoreReadFailure' {
        Mock -CommandName Test-CertificateStoreExporterWindows -MockWith {
            $True
        }

        $StoreFactory = {
            throw 'Synthetic store-open failure.'
        }

        {
            Get-StoreCertificate `
                -StoreLocation LocalMachine `
                -StoreName Root `
                -StoreFactory $StoreFactory
        } | Should -Throw -ErrorId 'StoreReadFailure,New-ErrorRecord'
    }
}

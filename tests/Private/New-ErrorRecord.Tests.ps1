#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'New-ErrorRecord' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'defines read-only exporter error id constants' {
        $ExpectedValues = @{
            CertificateStoreExporterErrorIdBelowMinimumCertificateCount = 'BelowMinimumCertificateCount'
            CertificateStoreExporterErrorIdNotWindows                   = 'NotWindows'
            CertificateStoreExporterErrorIdStoreReadFailure             = 'StoreReadFailure'
            CertificateStoreExporterErrorIdWriteFailure                 = 'WriteFailure'
        }

        $ExpectedValues.GetEnumerator() | ForEach-Object -Process {
            $Variable = Get-Variable -Name $PSItem.Key -Scope Script

            $Variable.Value | Should -Be $PSItem.Value
            ($Variable.Options -band [System.Management.Automation.ScopedItemOptions]::ReadOnly) |
                Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
        }
    }

    It 'returns an error record with a known short id' {
        $Result = New-ErrorRecord `
            -Message 'Windows certificate stores require Windows.' `
            -ErrorId $Script:CertificateStoreExporterErrorIdNotWindows

        $Result | Should -BeOfType ([System.Management.Automation.ErrorRecord])
        $Result.FullyQualifiedErrorId | Should -Be $Script:CertificateStoreExporterErrorIdNotWindows
    }

    It 'rejects unknown error ids' {
        {
            New-ErrorRecord `
                -Message 'Unknown failure.' `
                -ErrorId UnknownFailure
        } | Should -Throw
    }

    It 'can throw the error record as a terminating error' {
        {
            New-ErrorRecord `
                -Message 'Fatal Windows failure.' `
                -ErrorId $Script:CertificateStoreExporterErrorIdNotWindows `
                -IsFatal
        } | Should -Throw -ErrorId 'NotWindows,New-ErrorRecord'
    }
}

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Resolve-ExitCode' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'maps known short error ids to process exit codes' {
        $Cases = @(
            @{
                ErrorId  = $Script:CertificateStoreExporterErrorIdBelowMinimumCertificateCount
                ExitCode = 2
            }
            @{
                ErrorId  = $Script:CertificateStoreExporterErrorIdNotWindows
                ExitCode = 3
            }
            @{
                ErrorId  = $Script:CertificateStoreExporterErrorIdStoreReadFailure
                ExitCode = 4
            }
            @{
                ErrorId  = $Script:CertificateStoreExporterErrorIdWriteFailure
                ExitCode = 5
            }
        )

        $Cases | ForEach-Object -Process {
            $ErrorRecord = New-ErrorRecord `
                -Message ('Failure: {0}' -f $PSItem.ErrorId) `
                -ErrorId $PSItem.ErrorId

            Resolve-ExitCode -ErrorRecord $ErrorRecord | Should -Be $PSItem.ExitCode
        }
    }

    It 'uses the leading segment of the fully qualified error id' {
        try {
            New-ErrorRecord `
                -Message 'Store read failed.' `
                -ErrorId $Script:CertificateStoreExporterErrorIdStoreReadFailure `
                -IsFatal
        }
        catch {
            $ThrownRecord = $PSItem
        }

        $ThrownRecord.FullyQualifiedErrorId | Should -Be 'StoreReadFailure,New-ErrorRecord'
        Resolve-ExitCode -ErrorRecord $ThrownRecord | Should -Be 4
    }

    It 'returns no output for unmapped errors' {
        $UnknownRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new('Unknown failure.'),
            'UnknownFailure',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Null
        )

        @(Resolve-ExitCode -ErrorRecord $UnknownRecord) | Should -HaveCount 0
    }
}

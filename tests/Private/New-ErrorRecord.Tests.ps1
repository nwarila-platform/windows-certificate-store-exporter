#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'New-ErrorRecord' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    }

    It 'returns an error record with the requested id' {
        $Result = New-ErrorRecord -Message 'Example failure.' -ErrorId ExampleFailure

        $Result | Should -BeOfType ([System.Management.Automation.ErrorRecord])
        $Result.FullyQualifiedErrorId | Should -Be 'ExampleFailure'
    }

    It 'can throw the error record as a terminating error' {
        {
            New-ErrorRecord `
                -Message 'Fatal example.' `
                -ErrorId FatalExample `
                -IsFatal
        } | Should -Throw -ErrorId 'FatalExample,New-ErrorRecord'
    }
}

#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $script:ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../windows-certificate-store-exporter.ps1'
    $script:ScriptPath = (Resolve-Path -LiteralPath $script:ScriptPath).Path
}

Describe 'windows-certificate-store-exporter.ps1 scaffold' {
    It 'exists as the single project script' {
        Test-Path -LiteralPath $script:ScriptPath | Should -BeTrue
    }

    It 'parses as valid PowerShell' {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
    }

    It 'is intentionally not implemented yet' {
        { & $script:ScriptPath } | Should -Throw '*not implemented yet*'
    }
}

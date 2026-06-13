#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Export-CertificateStoreBundle' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')

        function Get-TestSha256Hex {
            param (
                [Parameter(Mandatory = $True)]
                [System.Byte[]]
                $Bytes
            )

            $Sha256 = [System.Security.Cryptography.SHA256]::Create()

            try {
                [System.BitConverter]::ToString($Sha256.ComputeHash($Bytes)).Replace('-', '')
            }
            finally {
                $Sha256.Dispose()
            }
        }

        function Get-TestCertificateSha256 {
            param (
                [Parameter(Mandatory = $True)]
                [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
                $Certificate
            )

            [System.String[]]@(
                $Certificate | ForEach-Object -Process {
                    Get-CertificateRawDataSha256 -Certificate $PSItem
                }
            )
        }

        function New-TestEntryPointHarness {
            param (
                [Parameter(Mandatory = $True)]
                [System.String]
                $ReleaseFile,

                [Parameter(Mandatory = $True)]
                [System.String]
                $Scenario,

                [Parameter(Mandatory = $True)]
                [System.String]
                $Directory
            )

            $HarnessFile = Join-Path `
                -Path $Directory `
                -ChildPath ('entrypoint-{0}.ps1' -f [System.Guid]::NewGuid().ToString('N'))
            $ReleaseText = Get-Content -LiteralPath $ReleaseFile -Raw
            $Override = @"
function Export-CertificateStoreBundle {
    [CmdletBinding(SupportsShouldProcess = `$True)]
    param (
        [Parameter(Mandatory = `$True)]
        [System.String]
        `$Path,

        [Parameter()]
        [System.String]
        `$StoreLocation = 'LocalMachine',

        [Parameter()]
        [System.String[]]
        `$StoreName = @('Root', 'CA'),

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$IncludeExpired,

        [Parameter()]
        [System.Int32]
        `$MinimumCertificateCount = 1,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        `$WriteManifest
    )

    process {
        switch ('$Scenario') {
            'Success' {
                [PSCustomObject]@{
                    Status = 'Written'
                }
                return
            }

            'Unhandled' {
                throw 'Synthetic unmapped entrypoint failure.'
            }

            default {
                New-ErrorRecord -Message 'Synthetic mapped entrypoint failure.' -ErrorId ([ExporterExitCode]::$Scenario) -IsFatal
            }
        }
    }
}

"@

            $HarnessText = $ReleaseText.Replace('#region Entry Point', ('{0}#region Entry Point' -f $Override))
            [System.IO.File]::WriteAllText(
                $HarnessFile,
                $HarnessText,
                [System.Text.UTF8Encoding]::new($False)
            )

            $HarnessFile
        }

        function Invoke-TestEntryPointHarness {
            param (
                [Parameter(Mandatory = $True)]
                [System.String]
                $Scenario,

                [Parameter(Mandatory = $True)]
                [System.String]
                $Directory
            )

            $ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
            $ReleaseFile = Join-Path -Path $ProjectRoot -ChildPath 'build\Export-CertificateStoreBundle.ps1'
            $HarnessFile = New-TestEntryPointHarness `
                -ReleaseFile $ReleaseFile `
                -Scenario $Scenario `
                -Directory $Directory
            $PowerShellCommand = Get-Command -Name 'powershell.exe' -ErrorAction Stop
            $BundlePath = Join-Path `
                -Path $Directory `
                -ChildPath ('entrypoint-{0}.pem' -f [System.Guid]::NewGuid().ToString('N'))
            $Arguments = [System.Collections.Generic.List[System.String]]::new()
            $Arguments.Add('-NoLogo')
            $Arguments.Add('-NoProfile')
            $Arguments.Add('-NonInteractive')
            $Arguments.Add('-ExecutionPolicy')
            $Arguments.Add('Bypass')
            $Arguments.Add('-File')
            $Arguments.Add($HarnessFile)
            $Arguments.Add('-Path')
            $Arguments.Add($BundlePath)

            $Null = & $PowerShellCommand.Source @Arguments 2>&1
            [System.Int32]$LASTEXITCODE
        }
    }

    BeforeEach {
        $TestRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $Null = New-Item -Path $TestRoot -ItemType Directory

        $Script:RootValid = New-TestCertificate -Scenario Valid -Subject 'CN=Export Root Valid'
        $Script:RootDuplicate = New-TestCertificate `
            -Scenario DuplicateThumbprint `
            -DuplicateOf $Script:RootValid
        $Script:RootExpired = New-TestCertificate -Scenario Expired -Subject 'CN=Export Root Expired'
        $Script:DisallowedSource = New-TestCertificate -Scenario Disallowed -Subject 'CN=Export Disallowed'
        $Script:RootDisallowed = New-TestCertificate `
            -Scenario DuplicateThumbprint `
            -DuplicateOf $Script:DisallowedSource
        $Script:CaFuture = New-TestCertificate -Scenario NotYetValid -Subject 'CN=Export CA Future'
        $Script:CaNoBasic = New-TestCertificate -Scenario NoBasicConstraints -Subject 'CN=Export CA No Basic'
        $Script:CaValid = New-TestCertificate -Scenario Valid -Subject 'CN=Export CA Valid'

        $Script:RootStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $Script:RootExpired,
            $Script:RootValid,
            $Script:RootDuplicate,
            $Script:RootDisallowed
        )
        $Script:CaStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $Script:CaFuture,
            $Script:CaNoBasic,
            $Script:CaValid
        )
        $Script:DisallowedStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $Script:DisallowedSource
        )
        $Script:AllFixtureCertificates = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $Script:RootValid,
            $Script:RootDuplicate,
            $Script:RootExpired,
            $Script:DisallowedSource,
            $Script:RootDisallowed,
            $Script:CaFuture,
            $Script:CaNoBasic,
            $Script:CaValid
        )

        Mock -CommandName Get-StoreCertificate -MockWith {
            switch ($StoreName) {
                'Root' {
                    $Script:RootStore
                    return
                }

                'CA' {
                    $Script:CaStore
                    return
                }

                'Disallowed' {
                    $Script:DisallowedStore
                    return
                }
            }
        }
    }

    AfterEach {
        foreach ($Certificate in $Script:AllFixtureCertificates) {
            if ($Null -ne $Certificate) {
                $Certificate.Dispose()
            }
        }

        if (Test-Path -LiteralPath $TestRoot) {
            Remove-Item -LiteralPath $TestRoot -Recurse -Force
        }
    }

    It 'writes the full result contract for requested stores plus Disallowed accounting' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
        $ExpectedSelected = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $Script:RootValid,
            $Script:CaNoBasic,
            $Script:CaValid
        )
        $ExpectedThumbprints = Get-TestCertificateSha256 -Certificate $ExpectedSelected |
            Sort-Object

        $Result = Export-CertificateStoreBundle -Path $Path -WriteManifest

        $BundleBytes = [System.IO.File]::ReadAllBytes($Path)
        $BundleText = [System.IO.File]::ReadAllText($Path)

        $Result.PSTypeNames[0] | Should -Be 'CertificateStoreExporter.Result'
        $Result.Path | Should -Be $Path
        $Result.Status | Should -Be 'Written'
        $Result.CertificateCount | Should -Be 3
        $Result.Thumbprints | Should -Be $ExpectedThumbprints
        $Result.BundleSha256 | Should -Be (Get-TestSha256Hex -Bytes $BundleBytes)
        $Result.Examined | Should -Be 7
        $Result.Excluded.Expired | Should -Be 1
        $Result.Excluded.NotYetValid | Should -Be 1
        $Result.Excluded.Disallowed | Should -Be 1
        $Result.Excluded.Duplicate | Should -Be 1
        $Result.StoreLocation | Should -Be 'LocalMachine'
        $Result.StoreNames | Should -Be @('Root', 'CA')
        $Result.ManifestPath | Should -Be ('{0}.sha256' -f $Path)
        $Result.GeneratedAtUtc.Kind | Should -Be ([System.DateTimeKind]::Utc)
        Test-Path -LiteralPath $Result.ManifestPath | Should -BeTrue
        $BundleText | Should -Match '# Source: Root'
        $BundleText | Should -Match '# Source: CA'

        Should -Invoke -CommandName Get-StoreCertificate -Times 1 -Exactly -ParameterFilter {
            $StoreName -eq 'Root'
        }
        Should -Invoke -CommandName Get-StoreCertificate -Times 1 -Exactly -ParameterFilter {
            $StoreName -eq 'CA'
        }
        Should -Invoke -CommandName Get-StoreCertificate -Times 1 -Exactly -ParameterFilter {
            $StoreName -eq 'Disallowed'
        }

        $SecondResult = Export-CertificateStoreBundle -Path $Path -WriteManifest

        $SecondResult.Status | Should -Be 'Unchanged'
        $SecondResult.BundleSha256 | Should -Be $Result.BundleSha256
        $SecondResult.Thumbprints | Should -Be $ExpectedThumbprints
    }

    It 'honors WhatIf through the writer without writing bundle or manifest files' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'whatif.pem'

        $Result = Export-CertificateStoreBundle -Path $Path -WriteManifest -WhatIf

        $Result.Status | Should -Be 'WhatIf'
        $Result.CertificateCount | Should -Be 3
        $Result.ManifestPath | Should -Be ('{0}.sha256' -f $Path)
        Test-Path -LiteralPath $Path | Should -BeFalse
        Test-Path -LiteralPath $Result.ManifestPath | Should -BeFalse
    }

    It 'propagates BelowMinimumCertificateCount from the writer' {
        $Script:RootStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@()
        $Script:CaStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@()
        $Script:DisallowedStore = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@()
        $Path = Join-Path -Path $TestRoot -ChildPath 'minimum.pem'

        {
            Export-CertificateStoreBundle -Path $Path -MinimumCertificateCount 1
        } | Should -Throw -ErrorId 'BelowMinimumCertificateCount,New-ErrorRecord'
    }

    It 'propagates StoreReadFailure from the store seam' {
        Mock -CommandName Get-StoreCertificate -MockWith {
            New-ErrorRecord `
                -Message 'Synthetic store failure.' `
                -ErrorId ([ExporterExitCode]::StoreReadFailure) `
                -IsFatal
        }
        $Path = Join-Path -Path $TestRoot -ChildPath 'store-failure.pem'

        {
            Export-CertificateStoreBundle -Path $Path
        } | Should -Throw -ErrorId 'StoreReadFailure,New-ErrorRecord'
    }

    It 'propagates WriteFailure from the writer' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'missing\bundle.pem'

        {
            Export-CertificateStoreBundle -Path $Path -StoreName Root
        } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'
    }

    It 'maps built EntryPoint exits for <Scenario> to <ExpectedExitCode>' -TestCases @(
        @{
            Scenario         = 'Success'
            ExpectedExitCode = 0
        }
        @{
            Scenario         = 'Unhandled'
            ExpectedExitCode = 1
        }
        @{
            Scenario         = 'BelowMinimumCertificateCount'
            ExpectedExitCode = 2
        }
        @{
            Scenario         = 'NotWindows'
            ExpectedExitCode = 3
        }
        @{
            Scenario         = 'StoreReadFailure'
            ExpectedExitCode = 4
        }
        @{
            Scenario         = 'WriteFailure'
            ExpectedExitCode = 5
        }
    ) {
        param (
            [System.String]
            $Scenario,

            [System.Int32]
            $ExpectedExitCode
        )

        Invoke-TestEntryPointHarness -Scenario $Scenario -Directory $TestRoot |
            Should -Be $ExpectedExitCode
    }
}

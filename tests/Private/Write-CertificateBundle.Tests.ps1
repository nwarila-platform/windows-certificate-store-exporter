#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Write-CertificateBundle' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')

        $Script:FirstPemBlock = "-----BEGIN CERTIFICATE-----`nQUJD`n-----END CERTIFICATE-----"
        $Script:SecondPemBlock = "-----BEGIN CERTIFICATE-----`nREVG`n-----END CERTIFICATE-----"

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

        function Assert-TestBundleBytes {
            param (
                [Parameter(Mandatory = $True)]
                [System.Byte[]]
                $Bytes
            )

            $Bytes[0..2] | Should -Not -Be ([System.Byte[]]@(0xEF, 0xBB, 0xBF))
            ($Bytes | Where-Object -FilterScript { $PSItem -gt 0x7F }) | Should -HaveCount 0
            [System.Text.Encoding]::ASCII.GetString($Bytes).Contains("`r") | Should -BeFalse
        }
    }

    BeforeEach {
        $TestRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $Null = New-Item -Path $TestRoot -ItemType Directory
    }

    AfterEach {
        if (Test-Path -LiteralPath $TestRoot) {
            Remove-Item -LiteralPath $TestRoot -Recurse -Force
        }
    }

    It 'creates a first bundle with ASCII LF bytes and no leftover temp files' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
        $ExpectedText = '{0}{1}{2}' -f $Script:FirstPemBlock, "`n", $Script:SecondPemBlock

        $Result = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @($Script:FirstPemBlock, $Script:SecondPemBlock) `
            -MinimumCertificateCount 2

        $Bytes = [System.IO.File]::ReadAllBytes($Path)

        $Result.Path | Should -Be $Path
        $Result.Status | Should -Be 'Written'
        $Result.CertificateCount | Should -Be 2
        $Result.BundleSha256 | Should -Be (Get-TestSha256Hex -Bytes $Bytes)
        $Result.ManifestPath | Should -BeNullOrEmpty
        [System.Text.Encoding]::ASCII.GetString($Bytes) | Should -Be $ExpectedText
        Assert-TestBundleBytes -Bytes $Bytes
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'returns Unchanged and preserves bytes and mtime for identical content' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
        $FixedTime = [System.DateTime]::SpecifyKind(
            [System.DateTime]::Parse('2026-01-01T00:00:00Z'),
            [System.DateTimeKind]::Utc
        )

        $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
        [System.IO.File]::SetLastWriteTimeUtc($Path, $FixedTime)
        $OriginalBytes = [System.IO.File]::ReadAllBytes($Path)

        $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)

        $Result.Status | Should -Be 'Unchanged'
        [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBytes
        [System.IO.File]::GetLastWriteTimeUtc($Path) | Should -Be $FixedTime
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'replaces an existing bundle when the content changes' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

        $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
        $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)

        $Result.Status | Should -Be 'Written'
        [System.IO.File]::ReadAllText($Path) | Should -Be $Script:SecondPemBlock
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'throws below the minimum count and leaves an existing bundle intact' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
        $ExistingText = 'existing bundle'
        [System.IO.File]::WriteAllText($Path, $ExistingText, [System.Text.UTF8Encoding]::new($False))

        {
            Write-CertificateBundle `
                -Path $Path `
                -PemBlock @($Script:FirstPemBlock) `
                -MinimumCertificateCount 2
        } | Should -Throw -ErrorId 'BelowMinimumCertificateCount,New-ErrorRecord'

        [System.IO.File]::ReadAllText($Path) | Should -Be $ExistingText
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'rejects non-ASCII bundle content before writing' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
        $InvalidBlock = '-----BEGIN CERTIFICATE-----' + [System.Char]0x00E9

        {
            Write-CertificateBundle -Path $Path -PemBlock @($InvalidBlock)
        } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

        Test-Path -LiteralPath $Path | Should -BeFalse
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'wraps filesystem write failures with the write-failure ErrorId' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'missing\bundle.pem'

        {
            Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
        } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

        Test-Path -LiteralPath $Path | Should -BeFalse
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'honors WhatIf without writing bundle or manifest bytes' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

        $Result = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @($Script:FirstPemBlock) `
            -WriteManifest `
            -WhatIf

        $Result.Status | Should -Be 'WhatIf'
        $Result.CertificateCount | Should -Be 1
        $Result.ManifestPath | Should -Be ('{0}.sha256' -f $Path)
        Test-Path -LiteralPath $Path | Should -BeFalse
        Test-Path -LiteralPath $Result.ManifestPath | Should -BeFalse
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }

    It 'writes an opt-in sha256sum manifest consistently and idempotently' {
        $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

        $Result = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @($Script:FirstPemBlock) `
            -WriteManifest

        $ManifestPath = '{0}.sha256' -f $Path
        $BundleBytes = [System.IO.File]::ReadAllBytes($Path)
        $ExpectedManifest = '{0}  {1}{2}' -f
            (Get-TestSha256Hex -Bytes $BundleBytes),
            [System.IO.Path]::GetFileName($Path),
            "`n"

        $Result.Status | Should -Be 'Written'
        $Result.ManifestPath | Should -Be $ManifestPath
        [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ExpectedManifest
        Assert-TestBundleBytes -Bytes ([System.IO.File]::ReadAllBytes($ManifestPath))

        $SecondResult = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @($Script:FirstPemBlock) `
            -WriteManifest

        $SecondResult.Status | Should -Be 'Unchanged'
        [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ExpectedManifest

        $ThirdResult = Write-CertificateBundle `
            -Path $Path `
            -PemBlock @($Script:SecondPemBlock) `
            -WriteManifest
        $ChangedBundleBytes = [System.IO.File]::ReadAllBytes($Path)
        $ChangedManifest = '{0}  {1}{2}' -f
            (Get-TestSha256Hex -Bytes $ChangedBundleBytes),
            [System.IO.Path]::GetFileName($Path),
            "`n"

        $ThirdResult.Status | Should -Be 'Written'
        [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ChangedManifest
        Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    }
}

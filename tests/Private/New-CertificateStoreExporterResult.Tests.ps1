#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'New-CertificateStoreExporterResult' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')
  }

  It 'creates the success result contract object' {
    $FirstCertificate = New-TestCertificate -Scenario Valid -Subject 'CN=Result First'
    $SecondCertificate = New-TestCertificate -Scenario NoBasicConstraints -Subject 'CN=Result Second'
    $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bundle.pem'
    $ManifestPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'bundle.pem.json'
    $GeneratedAtUtc = [System.DateTime]::SpecifyKind(
      [System.DateTime]::Parse('2026-01-01T12:00:00Z'),
      [System.DateTimeKind]::Utc
    )

    try {
      $FirstHash = Get-CertificateRawDataSha256 -Certificate $FirstCertificate
      $SecondHash = Get-CertificateRawDataSha256 -Certificate $SecondCertificate

      $Result = New-CertificateStoreExporterResult `
        -Path $Path `
        -Status Written `
        -Certificate @($FirstCertificate, $SecondCertificate) `
        -BundleSha256 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' `
        -Examined 7 `
        -ExcludedExpired 1 `
        -ExcludedNotYetValid 2 `
        -ExcludedDisallowed 3 `
        -ExcludedDuplicate 4 `
        -StoreLocation LocalMachine `
        -StoreName @('Root', 'CA') `
        -ManifestPath $ManifestPath `
        -GeneratedAtUtc $GeneratedAtUtc

      $Result.PSTypeNames[0] | Should -Be 'CertificateStoreExporter.Result'
      $Result.Path | Should -Be $Path
      $Result.Status | Should -Be 'Written'
      $Result.CertificateCount | Should -Be 2
      $Result.Thumbprints | Should -Be @($FirstHash, $SecondHash)
      $Result.Thumbprints[0] | Should -Not -Be $FirstCertificate.Thumbprint
      $Result.BundleSha256 | Should -Be 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
      $Result.Examined | Should -Be 7
      $Result.Excluded.Expired | Should -Be 1
      $Result.Excluded.NotYetValid | Should -Be 2
      $Result.Excluded.Disallowed | Should -Be 3
      $Result.Excluded.Duplicate | Should -Be 4
      $Result.StoreLocation | Should -Be 'LocalMachine'
      $Result.StoreNames | Should -Be @('Root', 'CA')
      $Result.ManifestPath | Should -Be $ManifestPath
      $Result.GeneratedAtUtc | Should -Be $GeneratedAtUtc
    } finally {
      $SecondCertificate.Dispose()
      $FirstCertificate.Dispose()
    }
  }

  It 'supports every success status and excludes Failed' {
    $Statuses = @('Written', 'Unchanged', 'WhatIf')

    $Statuses | ForEach-Object -Process {
      $Result = New-CertificateStoreExporterResult `
        -Path 'bundle.pem' `
        -Status $PSItem `
        -BundleSha256 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'

      $Result.Status | Should -Be $PSItem
    }

    $FailureOutput = @(
      try {
        New-CertificateStoreExporterResult `
          -Path 'bundle.pem' `
          -Status Failed `
          -BundleSha256 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
      } catch {
      }
    )

    $FailureOutput | Should -HaveCount 0
  }
}

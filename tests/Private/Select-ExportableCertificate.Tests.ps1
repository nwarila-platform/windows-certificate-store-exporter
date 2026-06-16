#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Select-ExportableCertificate' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')

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
  }

  It 'returns an empty selection contract for empty input' {
    $Result = Select-ExportableCertificate -Certificate @()

    @($Result.Selected) | Should -HaveCount 0
    @($Result.SelectedThumbprint) | Should -HaveCount 0
    $Result.ExcludedExpired | Should -Be 0
    $Result.ExcludedNotYetValid | Should -Be 0
    $Result.ExcludedDisallowed | Should -Be 0
    $Result.ExcludedDuplicate | Should -Be 0
  }

  It 'drops expired and not-yet-valid certificates by default' {
    $Valid = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Valid'
    $Expired = New-TestCertificate -Scenario Expired -Subject 'CN=Selection Expired'
    $NotYetValid = New-TestCertificate -Scenario NotYetValid -Subject 'CN=Selection Future'

    try {
      $Result = Select-ExportableCertificate -Certificate @($Expired, $Valid, $NotYetValid)

      @($Result.Selected) | Should -HaveCount 1
      $Result.Selected[0] | Should -Be $Valid
      $Result.SelectedThumbprint | Should -Be @(Get-CertificateRawDataSha256 -Certificate $Valid)
      $Result.ExcludedExpired | Should -Be 1
      $Result.ExcludedNotYetValid | Should -Be 1
      $Result.ExcludedDisallowed | Should -Be 0
      $Result.ExcludedDuplicate | Should -Be 0
    } finally {
      $NotYetValid.Dispose()
      $Expired.Dispose()
      $Valid.Dispose()
    }
  }

  It 'keeps expired and not-yet-valid certificates when IncludeExpired is present' {
    $Expired = New-TestCertificate -Scenario Expired -Subject 'CN=Selection Include Expired'
    $NotYetValid = New-TestCertificate -Scenario NotYetValid -Subject 'CN=Selection Include Future'

    try {
      $Result = Select-ExportableCertificate `
        -Certificate @($NotYetValid, $Expired) `
        -IncludeExpired
      $ExpectedHashes = Get-TestCertificateSha256 -Certificate @($Expired, $NotYetValid) |
        Sort-Object

      @($Result.Selected) | Should -HaveCount 2
      Get-TestCertificateSha256 -Certificate $Result.Selected | Should -Be $ExpectedHashes
      $Result.SelectedThumbprint | Should -Be $ExpectedHashes
      $Result.ExcludedExpired | Should -Be 0
      $Result.ExcludedNotYetValid | Should -Be 0
      $Result.ExcludedDisallowed | Should -Be 0
      $Result.ExcludedDuplicate | Should -Be 0
    } finally {
      $NotYetValid.Dispose()
      $Expired.Dispose()
    }
  }

  It 'subtracts Disallowed certificates by SHA-256 case-insensitively' {
    $Valid = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Allowed'
    $Disallowed = New-TestCertificate -Scenario Disallowed -Subject 'CN=Selection Disallowed'

    try {
      $DisallowedHash = (Get-CertificateRawDataSha256 -Certificate $Disallowed).ToLowerInvariant()

      $Result = Select-ExportableCertificate `
        -Certificate @($Disallowed, $Valid) `
        -DisallowedThumbprint @($DisallowedHash)

      @($Result.Selected) | Should -HaveCount 1
      $Result.Selected[0] | Should -Be $Valid
      $Result.SelectedThumbprint | Should -Be @(Get-CertificateRawDataSha256 -Certificate $Valid)
      $Result.ExcludedExpired | Should -Be 0
      $Result.ExcludedNotYetValid | Should -Be 0
      $Result.ExcludedDisallowed | Should -Be 1
      $Result.ExcludedDuplicate | Should -Be 0
    } finally {
      $Disallowed.Dispose()
      $Valid.Dispose()
    }
  }

  It 'collapses duplicate DER identities without disposing the retained certificate' {
    $Original = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Duplicate'
    $Duplicate = New-TestCertificate -Scenario DuplicateThumbprint -DuplicateOf $Original

    try {
      $Result = Select-ExportableCertificate -Certificate @($Duplicate, $Original)

      @($Result.Selected) | Should -HaveCount 1
      (Get-CertificateRawDataSha256 -Certificate $Result.Selected[0]) |
        Should -Be (Get-CertificateRawDataSha256 -Certificate $Original)
      $Result.SelectedThumbprint |
        Should -Be @(Get-CertificateRawDataSha256 -Certificate $Original)
      $Result.ExcludedExpired | Should -Be 0
      $Result.ExcludedNotYetValid | Should -Be 0
      $Result.ExcludedDisallowed | Should -Be 0
      $Result.ExcludedDuplicate | Should -Be 1
    } finally {
      $Duplicate.Dispose()
      $Original.Dispose()
    }
  }

  It 'keeps certificates without a BasicConstraints extension' {
    $Certificate = New-TestCertificate -Scenario NoBasicConstraints -Subject 'CN=Selection No Basic Constraints'

    try {
      $Result = Select-ExportableCertificate -Certificate @($Certificate)

      @($Result.Selected) | Should -HaveCount 1
      $Result.Selected[0] | Should -Be $Certificate
      $Result.SelectedThumbprint | Should -Be @(Get-CertificateRawDataSha256 -Certificate $Certificate)
      $Result.ExcludedExpired | Should -Be 0
      $Result.ExcludedNotYetValid | Should -Be 0
      $Result.ExcludedDisallowed | Should -Be 0
      $Result.ExcludedDuplicate | Should -Be 0
    } finally {
      $Certificate.Dispose()
    }
  }

  It 'sorts selected certificates ascending by SHA-256 regardless of input order' {
    $First = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort First'
    $Second = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort Second'
    $Third = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Sort Third'

    try {
      $InputCertificates = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
        $Third,
        $First,
        $Second
      )
      $ExpectedHashes = Get-TestCertificateSha256 -Certificate $InputCertificates | Sort-Object

      $Result = Select-ExportableCertificate -Certificate $InputCertificates

      Get-TestCertificateSha256 -Certificate $Result.Selected | Should -Be $ExpectedHashes
      $Result.SelectedThumbprint | Should -Be $ExpectedHashes
    } finally {
      $Third.Dispose()
      $Second.Dispose()
      $First.Dispose()
    }
  }

  It 'uses aligned precomputed SHA-256 identities without recomputing certificate hashes' {
    $First = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Precomputed First'
    $Second = New-TestCertificate -Scenario Valid -Subject 'CN=Selection Precomputed Second'
    $FirstHash = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
    $SecondHash = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

    Mock -CommandName Get-CertificateRawDataSha256 -MockWith {
      Throw 'Select-ExportableCertificate should not recompute aligned certificate hashes.'
    }

    try {
      $Result = Select-ExportableCertificate `
        -Certificate @($First, $Second) `
        -CertificateThumbprint @($FirstHash, $SecondHash)

      @($Result.Selected) | Should -HaveCount 2
      $Result.Selected[0] | Should -Be $Second
      $Result.Selected[1] | Should -Be $First
      $Result.SelectedThumbprint | Should -Be @($SecondHash, $FirstHash)
      $Result.ExcludedExpired | Should -Be 0
      $Result.ExcludedNotYetValid | Should -Be 0
      $Result.ExcludedDisallowed | Should -Be 0
      $Result.ExcludedDuplicate | Should -Be 0
      Should -Invoke -CommandName Get-CertificateRawDataSha256 -Times 0 -Exactly
    } finally {
      $Second.Dispose()
      $First.Dispose()
    }
  }
}

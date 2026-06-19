#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Describe 'New-TestCertificate' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'New-TestCertificate.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
  }

  It 'creates RSA-2048 fixtures for each non-duplicate scenario' {
    $Scenarios = @(
      'Valid',
      'Expired',
      'NotYetValid',
      'NoBasicConstraints',
      'Disallowed'
    )

    $Scenarios | ForEach-Object -Process {
      $Certificate = New-TestCertificate -Scenario $PSItem
      $PublicKey = $Null

      try {
        $PublicKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey(
          $Certificate
        )

        $Certificate.GetKeyAlgorithm() | Should -Be '1.2.840.113549.1.1.1'
        $PublicKey.KeySize | Should -Be 2048
      } finally {
        if ($Null -ne $PublicKey) {
          $PublicKey.Dispose()
        }

        $Certificate.Dispose()
      }
    }
  }

  It 'uses fixed validity windows for validity edge cases' {
    $Expired = New-TestCertificate -Scenario Expired
    $NotYetValid = New-TestCertificate -Scenario NotYetValid
    $Valid = New-TestCertificate -Scenario Valid

    try {
      $Expired.NotAfter.Year | Should -Be 2001
      $NotYetValid.NotBefore.Year | Should -Be 2099
      $Valid.NotBefore.Year | Should -Be 2000
      $Valid.NotAfter.Year | Should -Be 2099
    } finally {
      $Expired.Dispose()
      $NotYetValid.Dispose()
      $Valid.Dispose()
    }
  }

  It 'can omit BasicConstraints' {
    $Certificate = New-TestCertificate -Scenario NoBasicConstraints

    try {
      $BasicConstraints = @(
        $Certificate.Extensions |
          Where-Object -FilterScript {
            $PSItem.Oid.Value -eq '2.5.29.19'
          }
      )

      $BasicConstraints | Should -HaveCount 0
    } finally {
      $Certificate.Dispose()
    }
  }

  It 'can mint duplicate-thumbprint fixtures' {
    $Original = New-TestCertificate -Scenario Valid
    $Duplicate = New-TestCertificate -Scenario DuplicateThumbprint -DuplicateOf $Original

    try {
      [System.Object]::ReferenceEquals($Duplicate, $Original) | Should -BeFalse
      Get-CertificateRawDataSha256 -Certificate $Duplicate |
        Should -Be (Get-CertificateRawDataSha256 -Certificate $Original)
    } finally {
      $Duplicate.Dispose()
      $Original.Dispose()
    }
  }

  It 'can earmark a Disallowed member certificate' {
    $Certificate = New-TestCertificate -Scenario Disallowed

    try {
      $Certificate.FixtureStoreName | Should -Be 'Disallowed'
    } finally {
      $Certificate.Dispose()
    }
  }
}

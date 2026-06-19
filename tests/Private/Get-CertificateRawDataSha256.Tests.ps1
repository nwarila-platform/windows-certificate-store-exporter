#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Describe 'Get-CertificateRawDataSha256' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\Helpers\New-TestCertificate.ps1')
  }

  It 'hashes certificate RawData with SHA-256 instead of the SHA-1 Thumbprint property' {
    $Certificate = New-TestCertificate -Scenario Valid
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
      $Expected = [System.BitConverter]::ToString(
        $Sha256.ComputeHash($Certificate.RawData)
      ).Replace('-', '')

      $Result = Get-CertificateRawDataSha256 -Certificate $Certificate

      $Result | Should -Be $Expected
      $Result | Should -Match '^[A-F0-9]{64}$'
      $Result | Should -Not -Be $Certificate.Thumbprint
      $Certificate.Thumbprint | Should -Match '^[A-F0-9]{40}$'
    } finally {
      $Sha256.Dispose()
      $Certificate.Dispose()
    }
  }

  It 'fails closed when certificate RawData is empty' {
    $Certificate = New-MockObject `
      -Type ([System.Security.Cryptography.X509Certificates.X509Certificate2]) `
      -Properties @{
        RawData = [System.Byte[]]@()
        Subject = 'CN=Empty RawData'
      }

    ($Null -eq $Certificate.RawData) | Should -BeFalse
    $Certificate.RawData.Length | Should -Be 0

    {
      Get-CertificateRawDataSha256 -Certificate $Certificate
    } | Should -Throw -ErrorId 'Unhandled,New-ErrorRecord'
  }
}

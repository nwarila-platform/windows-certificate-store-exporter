#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Describe 'Get-StoreCertificate' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
  }

  It 'detects the supported Windows runtime in CI' {
    Test-CertificateStoreExporterWindows | Should -BeTrue
  }

  It 'throws NotWindows before touching a store when the platform guard fails' {
    Mock -CommandName Test-CertificateStoreExporterWindows -MockWith {
      $False
    }
    Mock -CommandName New-X509Store -MockWith {
      throw 'Synthetic unexpected store access.'
    }

    {
      Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root
    } | Should -Throw -ErrorId 'NotWindows,New-ErrorRecord'

    Should -Invoke -CommandName Test-CertificateStoreExporterWindows -Times 1 -Exactly
    Should -Invoke -CommandName New-X509Store -Times 0 -Exactly
  }

  It 'wraps store constructor failures with StoreReadFailure' {
    Mock -CommandName Test-CertificateStoreExporterWindows -MockWith {
      $True
    }
    Mock -CommandName New-X509Store -MockWith {
      throw 'Access is denied.'
    }

    {
      Get-StoreCertificate `
        -StoreLocation LocalMachine `
        -StoreName Root
    } | Should -Throw -ErrorId 'StoreReadFailure,New-ErrorRecord'

    Should -Invoke -CommandName New-X509Store -Times 1 -Exactly -ParameterFilter {
      ($Name -eq 'Root') -and
      ($Location -eq [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    }
  }
}

Describe 'New-X509Store' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
  }

  It 'creates an X509Store for the requested name and location' {
    $Store = New-X509Store -Name Root -Location LocalMachine

    try {
      $Store | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Store])
      $Store.Name | Should -Be 'Root'
      $Store.Location | Should -Be ([System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    } finally {
      $Store.Dispose()
    }
  }
}

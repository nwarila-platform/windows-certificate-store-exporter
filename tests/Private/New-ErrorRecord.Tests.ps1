#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'New-ErrorRecord' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
  }

  It 'defines exporter exit-code enum values' {
    [System.Int32][ExporterExitCode]::Success | Should -Be 0
    [System.Int32][ExporterExitCode]::Unhandled | Should -Be 1
    [System.Int32][ExporterExitCode]::BelowMinimumCertificateCount | Should -Be 2
    [System.Int32][ExporterExitCode]::NotWindows | Should -Be 3
    [System.Int32][ExporterExitCode]::StoreReadFailure | Should -Be 4
    [System.Int32][ExporterExitCode]::WriteFailure | Should -Be 5
  }

  It 'returns an error record with a known short id' {
    $Result = New-ErrorRecord `
      -Message 'Windows certificate stores require Windows.' `
      -ErrorId ([ExporterExitCode]::NotWindows)

    $Result | Should -BeOfType ([System.Management.Automation.ErrorRecord])
    $Result.FullyQualifiedErrorId | Should -Be 'NotWindows'
  }

  It 'preserves a supplied inner exception' {
    [System.Exception]$InnerException = [System.FormatException]::new('Bad DER bytes.')

    $Result = New-ErrorRecord `
      -Message 'Failed to compute certificate identity.' `
      -ErrorId ([ExporterExitCode]::Unhandled) `
      -Exception $InnerException

    $Result.Exception.Message | Should -Be 'Failed to compute certificate identity.'
    $Result.Exception.InnerException | Should -Be $InnerException
  }

  It 'rejects unknown error ids' {
    {
      New-ErrorRecord `
        -Message 'Unknown failure.' `
        -ErrorId UnknownFailure
    } | Should -Throw
  }

  It 'can throw the error record as a terminating error' {
    {
      New-ErrorRecord `
        -Message 'Fatal Windows failure.' `
        -ErrorId ([ExporterExitCode]::NotWindows) `
        -IsFatal
    } | Should -Throw -ErrorId 'NotWindows,New-ErrorRecord'
  }
}

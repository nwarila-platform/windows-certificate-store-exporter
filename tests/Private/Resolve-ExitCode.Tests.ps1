#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Resolve-ExitCode' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')
  }

  It 'maps known short error ids to process exit codes' {
    $Cases = @(
      @{
        ErrorId  = [ExporterExitCode]::BelowMinimumCertificateCount
        ExitCode = 2
      }
      @{
        ErrorId  = [ExporterExitCode]::NotWindows
        ExitCode = 3
      }
      @{
        ErrorId  = [ExporterExitCode]::StoreReadFailure
        ExitCode = 4
      }
      @{
        ErrorId  = [ExporterExitCode]::WriteFailure
        ExitCode = 5
      }
    )

    $Cases | ForEach-Object -Process {
      $ErrorRecord = New-ErrorRecord `
        -Message ('Failure: {0}' -f $PSItem.ErrorId) `
        -ErrorId $PSItem.ErrorId

      Resolve-ExitCode -ErrorRecord $ErrorRecord | Should -Be $PSItem.ExitCode
    }
  }

  It 'uses the leading segment of the fully qualified error id' {
    try {
      New-ErrorRecord `
        -Message 'Store read failed.' `
        -ErrorId ([ExporterExitCode]::StoreReadFailure) `
        -IsFatal
    } catch {
      $ThrownRecord = $PSItem
    }

    $ThrownRecord.FullyQualifiedErrorId | Should -Be 'StoreReadFailure,New-ErrorRecord'
    Resolve-ExitCode -ErrorRecord $ThrownRecord | Should -Be 4
  }

  It 'returns no output for unmapped errors' {
    $UnknownRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new('Unknown failure.'),
      'UnknownFailure',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Null
    )

    @(Resolve-ExitCode -ErrorRecord $UnknownRecord) | Should -HaveCount 0
  }

  It 'does not resolve process-state enum names from caught errors' {
    $SuccessRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new('Unexpected success failure.'),
      'Success',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Null
    )
    $UnhandledRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new('Unexpected unhandled failure.'),
      'Unhandled',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Null
    )

    @(Resolve-ExitCode -ErrorRecord $SuccessRecord) | Should -HaveCount 0
    @(Resolve-ExitCode -ErrorRecord $UnhandledRecord) | Should -HaveCount 0
  }
}

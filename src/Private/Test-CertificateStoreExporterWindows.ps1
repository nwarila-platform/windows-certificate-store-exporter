#Requires -Version 5.1

function Test-CertificateStoreExporterWindows {
  <#
    .SYNOPSIS
        Tests whether the exporter is running on Windows.

    .DESCRIPTION
        Provides a small internal platform seam so tests can force the
        non-Windows branch without weakening the production guard.

    .EXAMPLE
        Test-CertificateStoreExporterWindows

    .OUTPUTS
        [System.Boolean]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#test-certificatestoreexporterwindows',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Boolean])]
  param ()

  Write-Debug -Message:'[Test-CertificateStoreExporterWindows] Entering'

  # Initialize Variable(s)
  [System.Boolean]$Private:Result = $False

  # Keep platform detection behind a seam so tests can force the non-Windows branch.
  [System.Boolean]$Result = [System.Boolean](
    [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
  )
  $Result
  Write-Debug -Message:'[Test-CertificateStoreExporterWindows] Exiting'
}

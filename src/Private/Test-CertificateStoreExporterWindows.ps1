#Requires -Version 5.1

Function Test-CertificateStoreExporterWindows {
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
  Param ()

  Write-Debug -Message:'[Test-CertificateStoreExporterWindows] Entering'

  # Initialize Variable(s)
  [System.Boolean]$Private:Result = $False

  # Keep platform detection behind a seam so tests can force the non-Windows branch.
  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [System.Boolean]$Result = [System.Boolean](
    [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
  )

  # Do a  'soft'  return by outputting the result to the pipe without using the return function
  #   which would immediately end the function,  this enables us to have the very last
  #   executing item be write-debug giving us a valuable breakpoint & enabling better
  #   debugging functionality and output.
  $Result
  Write-Debug -Message:'[Test-CertificateStoreExporterWindows] Exiting'
}

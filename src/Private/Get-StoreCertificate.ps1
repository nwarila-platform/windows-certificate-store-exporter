#Requires -Version 5.1

# Message(s)
$Script:Message += @{
  'Get-StoreCertificate.NotWindows'  = 'Windows certificate stores are only available on Windows.'
  'Get-StoreCertificate.ReadFailure' = 'Failed to read Windows certificate store {0}\{1}: {2}'
}

Function Get-StoreCertificate {
  <#
    .SYNOPSIS
        Reads certificates from a Windows certificate store.

    .DESCRIPTION
        Opens one Windows X509Store read-only and returns its certificates. This
        is the only live certificate-store I/O seam in the exporter.

    .PARAMETER StoreLocation
        Logical certificate store location.

    .PARAMETER StoreName
        Logical certificate store name.

    .PARAMETER StoreFactory
        Internal factory used by tests to force store-open failures.

    .EXAMPLE
        Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#get-storecertificate',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
  Param (
    [Parameter(
      DontShow = $True,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNull()]
    [System.Management.Automation.ScriptBlock]
    $StoreFactory = {
      Param (
        [Parameter(
          DontShow = $False,
          Mandatory = $True,
          ParameterSetName = 'default',
          ValueFromPipeline = $False,
          ValueFromPipelineByPropertyName = $False
        )]
        [System.String]
        $Name,

        [Parameter(
          DontShow = $False,
          Mandatory = $True,
          ParameterSetName = 'default',
          ValueFromPipeline = $False,
          ValueFromPipelineByPropertyName = $False
        )]
        [System.Security.Cryptography.X509Certificates.StoreLocation]
        $Location
      )

      [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, $Location)
    },

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateSet('LocalMachine', 'CurrentUser')]
    [System.String]
    $StoreLocation = 'LocalMachine',

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateSet('Root', 'CA', 'Disallowed')]
    [System.String]
    $StoreName = 'Root'
  )

  Write-Debug -Message:'[Get-StoreCertificate] Entering'

  # Initialize Variable(s)
  [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]$Private:CertificateCollection = $Null
  # Open least-privilege and never create a missing store while this exporter is only reading.
  [System.Security.Cryptography.X509Certificates.OpenFlags]$Private:OpenFlags = (
    [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor
    [System.Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly
  )
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:Result = @()
  [System.Security.Cryptography.X509Certificates.X509Store]$Private:Store = $Null
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:StoreCertificates = @()
  [System.Security.Cryptography.X509Certificates.StoreLocation]$Private:TypedStoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine

  If ((Test-CertificateStoreExporterWindows) -eq $False) {
    New-ErrorRecord `
      -Category:([System.Management.Automation.ErrorCategory]::InvalidOperation) `
      -ErrorId:([ExporterExitCode]::NotWindows) `
      -IsFatal:$True `
      -Message:($Script:Message['Get-StoreCertificate.NotWindows']) `
      -TargetObject:('{0}\{1}' -f $StoreLocation, $StoreName)
  }

  # Safe dynamic enum lookup: StoreLocation is constrained by ValidateSet before binding succeeds.
  $TypedStoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation

  Try {
    # StoreFactory exists only so tests can inject store-open failures; it is not a CLI surface.
    $Store = & $StoreFactory -Name:$StoreName -Location:$TypedStoreLocation
    $Store.Open($OpenFlags)
    $CertificateCollection = $Store.Certificates
    $StoreCertificates = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
      $CertificateCollection
    )
  } Catch {
    New-ErrorRecord `
      -Category:([System.Management.Automation.ErrorCategory]::ReadError) `
      -ErrorId:([ExporterExitCode]::StoreReadFailure) `
      -Exception:$PSItem.Exception `
      -IsFatal:$True `
      -Message:($Script:Message['Get-StoreCertificate.ReadFailure'] -f $StoreLocation, $StoreName, $PSItem.Exception.Message) `
      -TargetObject:('{0}\{1}' -f $StoreLocation, $StoreName)
  } Finally {
    # Always release the native store handle, even if opening or enumeration fails.
    If ($Null -ne $Store) {
      $Store.Dispose()
    }
  }

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Result = $StoreCertificates

  # Do a  'soft'  return by outputting the result to the pipe without using the return function
  #   which would immediately end the function,  this enables us to have the very last
  #   executing item be write-debug giving us a valuable breakpoint & enabling better
  #   debugging functionality and output.
  $Result
  Write-Debug -Message:'[Get-StoreCertificate] Exiting'
}

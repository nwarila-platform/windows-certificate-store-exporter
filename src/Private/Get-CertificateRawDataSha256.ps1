#Requires -Version 5.1

function Get-CertificateRawDataSha256 {
  <#
    .SYNOPSIS
        Computes the SHA-256 thumbprint for a certificate.

    .DESCRIPTION
        Hashes the certificate DER bytes from RawData and returns an uppercase
        hex string. This intentionally does not use X509Certificate2.Thumbprint,
        which is SHA-1.

    .PARAMETER Certificate
        Certificate whose DER bytes should be hashed.

    .EXAMPLE
        Get-CertificateRawDataSha256 -Certificate $Certificate

    .OUTPUTS
        [System.String]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#get-certificaterawdatasha256',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.String])]
  param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [ValidateNotNull()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
    $Certificate
  )

  begin {
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering Begin'

    # Initialize Variable(s)
    [System.Byte[]]$Private:HashBytes = [System.Byte[]]@()
    [System.String]$Private:Result = [System.String]::Empty
    [System.Security.Cryptography.SHA256]$Private:Sha256 = $Null

    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting Begin'
  }

  process {
    # Reset Variable(s)
    $HashBytes = [System.Byte[]]@()
    $Result = [System.String]::Empty
    $Sha256 = $Null
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering Process'

    $Sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
      $HashBytes = $Sha256.ComputeHash($Certificate.RawData)
      $Result = [System.String]([System.BitConverter]::ToString($HashBytes).Replace('-', ''))
    } finally {
      if ($Null -ne $Sha256) {
        $Sha256.Dispose()
      }
    }

    ([System.String]$Result)
    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting Process'
  }

  end {
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering End'
    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting End'
  }
}

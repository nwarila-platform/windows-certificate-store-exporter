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
  Param (
    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $True,
      ValueFromPipelineByPropertyName = $True
    )]
    [ValidateNotNull()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
    $Certificate
  )

  Begin {
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering Begin'

    # Initialize Variable(s)
    [System.Byte[]]$Private:HashBytes = [System.Byte[]]@()
    [System.Security.Cryptography.SHA256]$Private:Sha256 = $Null
    [System.String]$Private:HashString = [System.String]::Empty
    [System.String]$Private:Result = [System.String]::Empty

    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting Begin'
  } Process {
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering Process'

    # Reset Variable(s)
    [System.Byte[]]$HashBytes = [System.Byte[]]@()
    [System.String]$HashString = [System.String]::Empty
    [System.String]$Result = [System.String]::Empty
    [System.Security.Cryptography.SHA256]$Sha256 = $Null

    Try {
      # BitConverter.ToString renders bytes as hyphen-delimited hex ("4A-B2-..."); strip the
      # separators to produce the contiguous uppercase hex that is the conventional certificate
      # fingerprint AND the exact identity key our dedup / Disallowed matching compares against.
      [System.Security.Cryptography.SHA256]$Sha256 = [System.Security.Cryptography.SHA256]::Create()
      [System.Byte[]]$HashBytes = $Sha256.ComputeHash($Certificate.RawData)
      [System.String]$HashString = [System.BitConverter]::ToString($HashBytes).Replace('-', '')
    } Catch {
      # This hash IS the certificate's identity; a failure must fail closed, never yield a partial or
      # empty identity. Re-raise as a structured fatal error, preserving the original as inner exception.
      New-ErrorRecord                                                                                                                    `
        -Category:([System.Management.Automation.ErrorCategory]::InvalidResult) `
        -ErrorId:([ExporterExitCode]::Unhandled)                                `
        -Exception:$PSItem.Exception                                            `
        -IsFatal:$True                                                          `
        -Message:('Failed to compute SHA-256 identity for certificate {0}: {1}' -f $Certificate.Subject, $PSItem.Exception.Message) `
        -TargetObject:$Certificate
    } Finally {
      # Dispose in Finally so the SHA256 provider's unmanaged crypto resources are released on
      # EVERY path -- including when ComputeHash throws -- preventing a handle leak, since this
      # runs once per certificate across the pipeline. Null-guarded because Create() may have
      # failed/thrown and left $Sha256 unset.
      If ($Null -ne $Sha256) {
        $Sha256.Dispose()
      }
    }

    # It's always desirable to explicitly set the Result object with its desired class as close
    #   to the soft return to ensure the output is predictable and easily traceable.
    [System.String]$Result = $HashString

    # Do a  'soft'  return by outputting the result to the pipe without using the return function
    #   which would immediately end the function,  this enables us to have the very last
    #   executing item be write-debug giving us a valuable breakpoint & enabling better
    #   debugging functionality and output.
    $Result

    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting Process'
  } End {
    Write-Debug -Message '[Get-CertificateRawDataSha256] Entering End'
    Write-Debug -Message '[Get-CertificateRawDataSha256] Exiting End'
  }
}

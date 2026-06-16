#Requires -Version 5.1

Function ConvertTo-PemCertificate {
  <#
    .SYNOPSIS
        Converts a certificate into a PEM block.

    .DESCRIPTION
        Converts the certificate DER RawData into an RFC 7468 PEM block and
        prefixes certifi-style metadata comments. Distinguished-name values are
        kept ASCII by escaping backslashes as \\ and non-ASCII UTF-8 bytes as
        \xHH.

    .PARAMETER Certificate
        Certificate to convert.

    .PARAMETER StoreName
        Source store name written to the PEM header.

    .EXAMPLE
        ConvertTo-PemCertificate -Certificate $Certificate -StoreName Root

    .OUTPUTS
        [System.String]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#convertto-pemcertificate',
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
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNull()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2]
    $Certificate,

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

  Begin {
    Write-Debug -Message:'[ConvertTo-PemCertificate] Entering Begin'

    # Initialize Variable(s)
    [System.String]$Private:Base64 = [System.String]::Empty
    [System.Byte[]]$Private:CharacterBytes = [System.Byte[]]@()
    [System.Int32]$Private:CharacterCode = 0
    [System.Text.StringBuilder]$Private:EscapedIssuerBuilder = $Null
    [System.Text.StringBuilder]$Private:EscapedSubjectBuilder = $Null
    [System.String]$Private:Issuer = [System.String]::Empty
    [System.Collections.Generic.List[System.String]]$Private:Lines = $Null
    [System.String]$Private:NotAfter = [System.String]::Empty
    [System.String]$Private:NotBefore = [System.String]::Empty
    [System.String]$Private:Result = [System.String]::Empty
    [System.String]$Private:Sha256 = [System.String]::Empty
    [System.String]$Private:Subject = [System.String]::Empty

    Write-Debug -Message:'[ConvertTo-PemCertificate] Exiting Begin'
  } Process {
    Write-Debug -Message:'[ConvertTo-PemCertificate] Entering Process'

    # Reset Variable(s)
    $Base64 = [System.String]::Empty
    $CharacterBytes = [System.Byte[]]@()
    $CharacterCode = 0
    $EscapedIssuerBuilder = $Null
    $EscapedSubjectBuilder = $Null
    $Issuer = [System.String]::Empty
    $Lines = $Null
    $NotAfter = [System.String]::Empty
    $NotBefore = [System.String]::Empty
    $Result = [System.String]::Empty
    $Sha256 = [System.String]::Empty
    $Subject = [System.String]::Empty

    # PEM metadata comments stay ASCII so bundle diffs and consumers do not depend on locale.
    $EscapedSubjectBuilder = [System.Text.StringBuilder]::new()
    ForEach ($Character In $Certificate.Subject.ToCharArray()) {
      $CharacterCode = [System.Int32]$Character

      If ($CharacterCode -eq 0x5C) {
        [void]$EscapedSubjectBuilder.Append('\\')
        Continue
      }

      If ($CharacterCode -ge 0x20 -and $CharacterCode -le 0x7E) {
        [void]$EscapedSubjectBuilder.Append($Character)
        Continue
      }

      $CharacterBytes = [System.Text.Encoding]::UTF8.GetBytes([System.String]$Character)
      ForEach ($CharacterByte In $CharacterBytes) {
        [void]$EscapedSubjectBuilder.Append(('\x{0:X2}' -f $CharacterByte))
      }
    }

    $EscapedIssuerBuilder = [System.Text.StringBuilder]::new()
    ForEach ($Character In $Certificate.Issuer.ToCharArray()) {
      $CharacterCode = [System.Int32]$Character

      If ($CharacterCode -eq 0x5C) {
        [void]$EscapedIssuerBuilder.Append('\\')
        Continue
      }

      If ($CharacterCode -ge 0x20 -and $CharacterCode -le 0x7E) {
        [void]$EscapedIssuerBuilder.Append($Character)
        Continue
      }

      $CharacterBytes = [System.Text.Encoding]::UTF8.GetBytes([System.String]$Character)
      ForEach ($CharacterByte In $CharacterBytes) {
        [void]$EscapedIssuerBuilder.Append(('\x{0:X2}' -f $CharacterByte))
      }
    }

    $Subject = $EscapedSubjectBuilder.ToString()
    $Issuer = $EscapedIssuerBuilder.ToString()
    $Sha256 = Get-CertificateRawDataSha256 -Certificate:$Certificate
    $NotBefore = $Certificate.NotBefore.ToUniversalTime().ToString(
      'yyyy-MM-ddTHH:mm:ssZ',
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    $NotAfter = $Certificate.NotAfter.ToUniversalTime().ToString(
      'yyyy-MM-ddTHH:mm:ssZ',
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    $Base64 = [System.Convert]::ToBase64String($Certificate.RawData)
    $Lines = [System.Collections.Generic.List[System.String]]::new()

    [void]$Lines.Add(('# Subject: {0}' -f $Subject))
    [void]$Lines.Add(('# Issuer: {0}' -f $Issuer))
    [void]$Lines.Add(('# Serial: {0}' -f $Certificate.SerialNumber))
    [void]$Lines.Add(('# SHA-256: {0}' -f $Sha256))
    [void]$Lines.Add(('# NotBefore: {0}' -f $NotBefore))
    [void]$Lines.Add(('# NotAfter: {0}' -f $NotAfter))
    [void]$Lines.Add(('# Source: {0}' -f $StoreName))
    [void]$Lines.Add('-----BEGIN CERTIFICATE-----')

    For ($Index = 0; $Index -lt $Base64.Length; $Index += 64) {
      [void]$Lines.Add(
        $Base64.Substring($Index, [System.Math]::Min(64, $Base64.Length - $Index))
      )
    }

    [void]$Lines.Add('-----END CERTIFICATE-----')

    # It's always desirable to explicitly set the Result object with its desired class as close
    #   to the soft return to ensure the output is predictable and easily traceable.
    [System.String]$Result = [System.String]($Lines.ToArray() -join "`n")

    # Do a  'soft'  return by outputting the result to the pipe without using the return function
    #   which would immediately end the function,  this enables us to have the very last
    #   executing item be write-debug giving us a valuable breakpoint & enabling better
    #   debugging functionality and output.
    $Result

    Write-Debug -Message:'[ConvertTo-PemCertificate] Exiting Process'
  } End {
    Write-Debug -Message:'[ConvertTo-PemCertificate] Entering End'
    Write-Debug -Message:'[ConvertTo-PemCertificate] Exiting End'
  }
}

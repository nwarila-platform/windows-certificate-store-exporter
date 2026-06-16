#Requires -Version 5.1

Function Select-ExportableCertificate {
  <#
    .SYNOPSIS
        Selects certificates eligible for export.

    .DESCRIPTION
        Filters certificates by validity, subtracts Disallowed SHA-256 DER
        identities, de-duplicates by the same identity, and returns the retained
        certificates sorted ascending by SHA-256 for deterministic bundle order.

    .PARAMETER Certificate
        Candidate certificates.

    .PARAMETER DisallowedThumbprint
        SHA-256 DER thumbprints to subtract.

    .PARAMETER IncludeExpired
        Includes expired and not-yet-valid certificates.

    .EXAMPLE
        Select-ExportableCertificate -Certificate $Certificates

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#select-exportablecertificate',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
  Param (
    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [AllowEmptyCollection()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    $Certificate = @(),

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [AllowEmptyCollection()]
    [System.String[]]
    $DisallowedThumbprint = @(),

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $IncludeExpired
  )

  Write-Debug -Message:'[Select-ExportableCertificate] Entering'

  # Initialize Variable(s)
  [System.String]$Private:CertificateHash = [System.String]::Empty
  [System.Collections.Generic.HashSet[System.String]]$Private:DisallowedSet = $Null
  [System.Boolean]$Private:IsCurrent = $False
  [System.DateTime]$Private:NotAfterUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NotBeforeUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NowUtc = [System.DateTime]::MinValue
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:Result = @()
  [System.Collections.Generic.SortedDictionary[
  System.String,
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]$Private:SelectedByHash = $Null

  $NowUtc = [System.DateTime]::UtcNow
  $DisallowedSet = [System.Collections.Generic.HashSet[System.String]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )
  $DisallowedThumbprint | ForEach-Object -Process:({
      If ([System.String]::IsNullOrWhiteSpace($PSItem) -eq $False) {
        [void]$DisallowedSet.Add($PSItem)
      }
    })
  # SHA-256 DER identity is the stable key for Disallowed subtraction, deduplication, and
  # deterministic bundle ordering.
  $SelectedByHash = [System.Collections.Generic.SortedDictionary[
  System.String,
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]::new([System.StringComparer]::Ordinal)

  ForEach ($CandidateCertificate In $Certificate) {
    If ($Null -eq $CandidateCertificate) {
      Continue
    }

    $IsCurrent = $True
    If ($IncludeExpired.IsPresent -eq $False) {
      # Export only currently valid certificates unless the caller explicitly requests otherwise.
      $NotBeforeUtc = $CandidateCertificate.NotBefore.ToUniversalTime()
      $NotAfterUtc = $CandidateCertificate.NotAfter.ToUniversalTime()
      $IsCurrent = [System.Boolean]($NotBeforeUtc -le $NowUtc -and $NotAfterUtc -ge $NowUtc)
    }

    If ($IsCurrent -eq $False) {
      Continue
    }

    $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$CandidateCertificate
    If ($DisallowedSet.Contains($CertificateHash) -eq $True) {
      Continue
    }

    If ($SelectedByHash.ContainsKey($CertificateHash) -eq $False) {
      $SelectedByHash.Add($CertificateHash, $CandidateCertificate)
    }
  }

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Result = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
    $SelectedByHash.GetEnumerator() | ForEach-Object -Process:({
        $PSItem.Value
      })
  )

  # Do a  'soft'  return by outputting the result to the pipe without using the return function
  #   which would immediately end the function,  this enables us to have the very last
  #   executing item be write-debug giving us a valuable breakpoint & enabling better
  #   debugging functionality and output.
  $Result
  Write-Debug -Message:'[Select-ExportableCertificate] Exiting'
}

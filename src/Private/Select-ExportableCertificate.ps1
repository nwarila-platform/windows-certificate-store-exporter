#Requires -Version 5.1

function Select-ExportableCertificate {
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
  param (
    [Parameter()]
    [AllowEmptyCollection()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    $Certificate = @(),

    [Parameter()]
    [AllowEmptyCollection()]
    [System.String[]]
    $DisallowedThumbprint = @(),

    [Parameter()]
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
      if ([System.String]::IsNullOrWhiteSpace($PSItem) -eq $False) {
        [void]$DisallowedSet.Add($PSItem)
      }
    })
  # SHA-256 DER identity is the stable key for Disallowed subtraction, deduplication, and
  # deterministic bundle ordering.
  $SelectedByHash = [System.Collections.Generic.SortedDictionary[
  System.String,
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]::new([System.StringComparer]::Ordinal)

  foreach ($CandidateCertificate in $Certificate) {
    if ($Null -eq $CandidateCertificate) {
      continue
    }

    $IsCurrent = $True
    if ($IncludeExpired.IsPresent -eq $False) {
      # Export only currently valid certificates unless the caller explicitly requests otherwise.
      $NotBeforeUtc = $CandidateCertificate.NotBefore.ToUniversalTime()
      $NotAfterUtc = $CandidateCertificate.NotAfter.ToUniversalTime()
      $IsCurrent = [System.Boolean]($NotBeforeUtc -le $NowUtc -and $NotAfterUtc -ge $NowUtc)
    }

    if ($IsCurrent -eq $False) {
      continue
    }

    $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$CandidateCertificate
    if ($DisallowedSet.Contains($CertificateHash) -eq $True) {
      continue
    }

    if ($SelectedByHash.ContainsKey($CertificateHash) -eq $False) {
      $SelectedByHash.Add($CertificateHash, $CandidateCertificate)
    }
  }

  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Result = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
    $SelectedByHash.GetEnumerator() | ForEach-Object -Process:({
        $PSItem.Value
      })
  )
  $Result
  Write-Debug -Message:'[Select-ExportableCertificate] Exiting'
}

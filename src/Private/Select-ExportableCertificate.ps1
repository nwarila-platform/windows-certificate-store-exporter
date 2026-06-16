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
        [System.Management.Automation.PSCustomObject]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#select-exportablecertificate',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([PSCustomObject])]
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
  [System.Int32]$Private:ExcludedDisallowed = 0
  [System.Int32]$Private:ExcludedDuplicate = 0
  [System.Int32]$Private:ExcludedExpired = 0
  [System.Int32]$Private:ExcludedNotYetValid = 0
  [System.DateTime]$Private:NotAfterUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NotBeforeUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NowUtc = [System.DateTime]::MinValue
  [PSCustomObject]$Private:Result = $Null
  [System.Collections.Generic.SortedDictionary[
  System.String,
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]$Private:SelectedByHash = $Null
  [System.Collections.Generic.List[
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]$Private:SelectedCertificates = $Null
  [System.Collections.Generic.List[System.String]]$Private:SelectedThumbprints = $Null

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

    If ($IncludeExpired.IsPresent -eq $False) {
      $NotBeforeUtc = $CandidateCertificate.NotBefore.ToUniversalTime()
      $NotAfterUtc = $CandidateCertificate.NotAfter.ToUniversalTime()

      If ($NotAfterUtc -lt $NowUtc) {
        $ExcludedExpired++
        Continue
      }

      If ($NotBeforeUtc -gt $NowUtc) {
        $ExcludedNotYetValid++
        Continue
      }
    }

    $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$CandidateCertificate
    If ($DisallowedSet.Contains($CertificateHash) -eq $True) {
      $ExcludedDisallowed++
      Continue
    }

    If ($SelectedByHash.ContainsKey($CertificateHash) -eq $False) {
      $SelectedByHash.Add($CertificateHash, $CandidateCertificate)
    } Else {
      $ExcludedDuplicate++
    }
  }

  $SelectedCertificates = [System.Collections.Generic.List[
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]::new()
  $SelectedThumbprints = [System.Collections.Generic.List[System.String]]::new()
  $SelectedByHash.GetEnumerator() | ForEach-Object -Process:({
      $SelectedThumbprints.Add($PSItem.Key)
      $SelectedCertificates.Add($PSItem.Value)
    })

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [PSCustomObject]$Result = [PSCustomObject]@{
    Selected            = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$SelectedCertificates.ToArray()
    SelectedThumbprint  = [System.String[]]$SelectedThumbprints.ToArray()
    ExcludedExpired     = [System.Int32]$ExcludedExpired
    ExcludedNotYetValid = [System.Int32]$ExcludedNotYetValid
    ExcludedDisallowed  = [System.Int32]$ExcludedDisallowed
    ExcludedDuplicate   = [System.Int32]$ExcludedDuplicate
  }

  # Do a  'soft'  return by outputting the result to the pipe without using the return function
  #   which would immediately end the function,  this enables us to have the very last
  #   executing item be write-debug giving us a valuable breakpoint & enabling better
  #   debugging functionality and output.
  $Result
  Write-Debug -Message:'[Select-ExportableCertificate] Exiting'
}

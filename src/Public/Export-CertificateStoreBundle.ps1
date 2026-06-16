#Requires -Version 5.1

Function Export-CertificateStoreBundle {
  <#
    .SYNOPSIS
        Exports a Windows certificate store bundle.

    .DESCRIPTION
        Reads the requested certificate stores, subtracts Disallowed, filters and
        de-duplicates exportable certificates, writes the deterministic PEM
        bundle, and emits the success result contract.

    .PARAMETER Path
        Destination bundle path. This parameter is mandatory.

    .PARAMETER StoreLocation
        Logical certificate store location: LocalMachine or CurrentUser.

    .PARAMETER StoreName
        Logical certificate store names to export: Root, CA, or both.
        Disallowed is always read separately and subtracted.

    .PARAMETER IncludeExpired
        Includes expired and not-yet-valid certificates in the candidate set.

    .PARAMETER MinimumCertificateCount
        Minimum surviving certificate count required before writing.

    .PARAMETER WriteManifest
        Writes a sha256sum-style manifest sidecar.

    .EXAMPLE
        Export-CertificateStoreBundle -Path .\bundle.pem -WriteManifest -WhatIf

    .OUTPUTS
        CertificateStoreExporter.Result
    #>
  [CmdletBinding(
    ConfirmImpact = 'Medium',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#export-certificatestorebundle',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $True
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
    [System.Management.Automation.SwitchParameter]
    $IncludeExpired,

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $MinimumCertificateCount = 1,

    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

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
    [ValidateSet('Root', 'CA')]
    [System.String[]]
    $StoreName = @('Root', 'CA'),

    [Parameter(
      DontShow = $False,
      Mandatory = $False,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [System.Management.Automation.SwitchParameter]
    $WriteManifest
  )

  Write-Debug -Message:'[Export-CertificateStoreBundle] Entering'

  # Initialize Variable(s)
  [System.String]$Private:BundleSha256 = [System.String]::Empty
  [System.Collections.Generic.List[
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]$Private:CandidateCertificates = $Null
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:CandidateCertificateArray = @()
  [System.String]$Private:CertificateHash = [System.String]::Empty
  [System.String]$Private:DefaultSourceStore = [System.String]::Empty
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:DisallowedCertificates = @()
  [System.Collections.Generic.HashSet[System.String]]$Private:DisallowedThumbprintSet = $Null
  [System.Collections.Generic.List[System.String]]$Private:DisallowedThumbprints = $Null
  [System.Int32]$Private:ExcludedDisallowed = 0
  [System.Int32]$Private:ExcludedDuplicate = 0
  [System.Int32]$Private:ExcludedExpired = 0
  [System.Int32]$Private:ExcludedNotYetValid = 0
  [System.Collections.Generic.Dictionary[System.String, System.String]]$Private:FirstSourceStoreByHash = $Null
  [System.String]$Private:ManifestPath = $Null
  [System.DateTime]$Private:NotAfterUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NotBeforeUtc = [System.DateTime]::MinValue
  [System.DateTime]$Private:NowUtc = [System.DateTime]::MinValue
  [System.Collections.Generic.List[System.String]]$Private:PemBlocks = $Null
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:SelectedCertificates = @()
  [System.Collections.Generic.HashSet[System.String]]$Private:SeenEligibleThumbprints = $Null
  [System.String]$Private:SourceStore = [System.String]::Empty
  [System.String]$Private:Status = [System.String]::Empty
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:StoreCertificates = @()
  [PSCustomObject]$Private:Result = $Null
  [System.Object]$Private:WriteResult = $Null

  $NowUtc = [System.DateTime]::UtcNow
  $CandidateCertificates = [System.Collections.Generic.List[
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]::new()
  $DisallowedThumbprints = [System.Collections.Generic.List[System.String]]::new()
  $DisallowedThumbprintSet = [System.Collections.Generic.HashSet[System.String]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )
  # Track the first source store for each certificate identity so PEM blocks can be labelled with
  # the store that originally contributed the certificate.
  $FirstSourceStoreByHash = [System.Collections.Generic.Dictionary[
  System.String,
  System.String
  ]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $SeenEligibleThumbprints = [System.Collections.Generic.HashSet[System.String]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
  )

  ForEach ($RequestedStoreName In $StoreName) {
    $StoreCertificates = Get-StoreCertificate `
      -StoreLocation:$StoreLocation `
      -StoreName:$RequestedStoreName

    ForEach ($StoreCertificate In $StoreCertificates) {
      If ($Null -eq $StoreCertificate) {
        Continue
      }

      $CandidateCertificates.Add($StoreCertificate)
      $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$StoreCertificate

      If ($FirstSourceStoreByHash.ContainsKey($CertificateHash) -eq $False) {
        $FirstSourceStoreByHash.Add($CertificateHash, $RequestedStoreName)
      }
    }
  }

  # Disallowed is a distrust list, not an export source, so read it separately and subtract matches
  # from the requested store candidates.
  $DisallowedCertificates = Get-StoreCertificate `
    -StoreLocation:$StoreLocation `
    -StoreName:'Disallowed'

  ForEach ($DisallowedCertificate In $DisallowedCertificates) {
    If ($Null -eq $DisallowedCertificate) {
      Continue
    }

    $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$DisallowedCertificate
    $DisallowedThumbprints.Add($CertificateHash)
    [void]$DisallowedThumbprintSet.Add($CertificateHash)
  }

  # Count every candidate exclusion class here because the result contract reports these Excluded
  # totals separately from the selected certificate list.
  ForEach ($CandidateCertificate In $CandidateCertificates) {
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

    If ($DisallowedThumbprintSet.Contains($CertificateHash) -eq $True) {
      $ExcludedDisallowed++
      Continue
    }

    If ($SeenEligibleThumbprints.Contains($CertificateHash) -eq $True) {
      $ExcludedDuplicate++
      Continue
    }

    [void]$SeenEligibleThumbprints.Add($CertificateHash)
  }

  $CandidateCertificateArray = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$CandidateCertificates.ToArray()
  $SelectedCertificates = @(
    Select-ExportableCertificate `
      -Certificate:$CandidateCertificateArray `
      -DisallowedThumbprint:([System.String[]]$DisallowedThumbprints.ToArray()) `
      -IncludeExpired:$IncludeExpired.IsPresent
  )

  $PemBlocks = [System.Collections.Generic.List[System.String]]::new()
  # Fall back to the first requested store when a selected certificate has no tracked source entry,
  # preserving the caller's store preference in PEM labels.
  $DefaultSourceStore = 'Root'
  If ($StoreName.Count -gt 0) {
    $DefaultSourceStore = [System.String]$StoreName[0]
  }

  ForEach ($SelectedCertificate In $SelectedCertificates) {
    $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$SelectedCertificate
    $SourceStore = $DefaultSourceStore

    If ($FirstSourceStoreByHash.ContainsKey($CertificateHash) -eq $True) {
      $SourceStore = [System.String]$FirstSourceStoreByHash[$CertificateHash]
    }

    $PemBlocks.Add(
      (
        ConvertTo-PemCertificate `
          -Certificate:$SelectedCertificate `
          -StoreName:$SourceStore
      )
    )
  }

  $WriteResult = Write-CertificateBundle `
    -Path:$Path `
    -PemBlock:([System.String[]]$PemBlocks.ToArray()) `
    -MinimumCertificateCount:$MinimumCertificateCount `
    -WriteManifest:$WriteManifest.IsPresent

  $Status = [System.String]$WriteResult.Status
  $BundleSha256 = [System.String]$WriteResult.BundleSha256
  $ManifestPath = $WriteResult.ManifestPath

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [PSCustomObject]$Result = New-CertificateStoreExporterResult `
    -Path:$Path `
    -Status:$Status `
    -Certificate:$SelectedCertificates `
    -BundleSha256:$BundleSha256 `
    -Examined:($CandidateCertificates.Count) `
    -ExcludedExpired:$ExcludedExpired `
    -ExcludedNotYetValid:$ExcludedNotYetValid `
    -ExcludedDisallowed:$ExcludedDisallowed `
    -ExcludedDuplicate:$ExcludedDuplicate `
    -StoreLocation:$StoreLocation `
    -StoreName:$StoreName `
    -ManifestPath:$ManifestPath

  # Do a  'soft'  return by outputting the result to the pipe without using the return function
  #   which would immediately end the function,  this enables us to have the very last
  #   executing item be write-debug giving us a valuable breakpoint & enabling better
  #   debugging functionality and output.
  $Result

  Write-Debug -Message:'[Export-CertificateStoreBundle] Exiting'
}

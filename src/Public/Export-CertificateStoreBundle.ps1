#Requires -Version 5.1
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

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
    [ValidateRange(1, [System.Int32]::MaxValue)]
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
  [System.Collections.Generic.List[System.String]]$Private:CandidateThumbprints = $Null
  [System.Int32]$Private:CertificateIndex = 0
  [System.String]$Private:CertificateHash = [System.String]::Empty
  [System.String]$Private:DefaultSourceStore = [System.String]::Empty
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:DisallowedCertificates = @()
  [System.String[]]$Private:DisallowedThumbprints = @()
  [System.Collections.Generic.Dictionary[System.String, System.String]]$Private:FirstSourceStoreByHash = $Null
  [System.String]$Private:ManifestPath = $Null
  [System.Collections.Generic.List[System.String]]$Private:PemBlocks = $Null
  [PSCustomObject]$Private:SelectionResult = $Null
  [System.Security.Cryptography.X509Certificates.X509Certificate2]$Private:SelectedCertificate = $Null
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:SelectedCertificates = @()
  [System.String[]]$Private:SelectedThumbprints = @()
  [System.String]$Private:SourceStore = [System.String]::Empty
  [System.String]$Private:Status = [System.String]::Empty
  [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:StoreCertificates = @()
  [PSCustomObject]$Private:Result = $Null
  [System.Object]$Private:WriteResult = $Null

  $CandidateCertificates = [System.Collections.Generic.List[
  System.Security.Cryptography.X509Certificates.X509Certificate2
  ]]::new()
  $CandidateThumbprints = [System.Collections.Generic.List[System.String]]::new()
  # Track the first source store for each certificate identity so PEM blocks can be labelled with
  # the store that originally contributed the certificate.
  $FirstSourceStoreByHash = [System.Collections.Generic.Dictionary[
  System.String,
  System.String
  ]]::new([System.StringComparer]::OrdinalIgnoreCase)

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
      $CandidateThumbprints.Add($CertificateHash)

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

  $DisallowedThumbprints = [System.String[]]@(
    ForEach ($DisallowedCertificate In $DisallowedCertificates) {
      If ($Null -eq $DisallowedCertificate) {
        Continue
      }

      $CertificateHash = Get-CertificateRawDataSha256 -Certificate:$DisallowedCertificate
      $CertificateHash
    }
  )

  $CandidateCertificateArray = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$CandidateCertificates.ToArray()
  $SelectionResult = Select-ExportableCertificate `
    -Certificate:$CandidateCertificateArray `
    -CertificateThumbprint:([System.String[]]$CandidateThumbprints.ToArray()) `
    -DisallowedThumbprint:$DisallowedThumbprints `
    -IncludeExpired:$IncludeExpired.IsPresent
  $SelectedCertificates = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$SelectionResult.Selected
  $SelectedThumbprints = [System.String[]]$SelectionResult.SelectedThumbprint

  $PemBlocks = [System.Collections.Generic.List[System.String]]::new()
  # Fall back to the first requested store when a selected certificate has no tracked source entry,
  # preserving the caller's store preference in PEM labels.
  $DefaultSourceStore = 'Root'
  If ($StoreName.Count -gt 0) {
    $DefaultSourceStore = [System.String]$StoreName[0]
  }

  For ($CertificateIndex = 0; $CertificateIndex -lt $SelectedCertificates.Count; $CertificateIndex++) {
    $SelectedCertificate = $SelectedCertificates[$CertificateIndex]
    $CertificateHash = [System.String]$SelectedThumbprints[$CertificateIndex]
    $SourceStore = $DefaultSourceStore

    If ($FirstSourceStoreByHash.ContainsKey($CertificateHash) -eq $True) {
      $SourceStore = [System.String]$FirstSourceStoreByHash[$CertificateHash]
    }

    $PemBlocks.Add(
      (
        ConvertTo-PemCertificate `
          -Certificate:$SelectedCertificate `
          -Sha256:$CertificateHash `
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
    -CertificateThumbprint:$SelectedThumbprints `
    -BundleSha256:$BundleSha256 `
    -Examined:($CandidateCertificates.Count) `
    -ExcludedExpired:([System.Int32]$SelectionResult.ExcludedExpired) `
    -ExcludedNotYetValid:([System.Int32]$SelectionResult.ExcludedNotYetValid) `
    -ExcludedDisallowed:([System.Int32]$SelectionResult.ExcludedDisallowed) `
    -ExcludedDuplicate:([System.Int32]$SelectionResult.ExcludedDuplicate) `
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

#Requires -Version 5.1

function Export-CertificateStoreBundle {
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
    [CmdletBinding(SupportsShouldProcess = $True)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $StoreLocation = 'LocalMachine',

        [Parameter()]
        [ValidateSet('Root', 'CA')]
        [System.String[]]
        $StoreName = @('Root', 'CA'),

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeExpired,

        [Parameter()]
        [ValidateRange(0, [System.Int32]::MaxValue)]
        [System.Int32]
        $MinimumCertificateCount = 1,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $WriteManifest
    )

    begin {
        Write-Debug -Message '[Export-CertificateStoreBundle] Entering Begin'

        # Initalize Variable(s)
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
        [System.Object]$Private:WriteResult = $Null

        Write-Debug -Message '[Export-CertificateStoreBundle] Exiting Begin'
    }

    process {
        $BundleSha256 = [System.String]::Empty
        $CandidateCertificates = $Null
        $CandidateCertificateArray = @()
        $CertificateHash = [System.String]::Empty
        $DefaultSourceStore = [System.String]::Empty
        $DisallowedCertificates = @()
        $DisallowedThumbprintSet = $Null
        $DisallowedThumbprints = $Null
        $ExcludedDisallowed = 0
        $ExcludedDuplicate = 0
        $ExcludedExpired = 0
        $ExcludedNotYetValid = 0
        $FirstSourceStoreByHash = $Null
        $ManifestPath = $Null
        $NotAfterUtc = [System.DateTime]::MinValue
        $NotBeforeUtc = [System.DateTime]::MinValue
        $NowUtc = [System.DateTime]::MinValue
        $PemBlocks = $Null
        $SelectedCertificates = @()
        $SeenEligibleThumbprints = $Null
        $SourceStore = [System.String]::Empty
        $Status = [System.String]::Empty
        $StoreCertificates = @()
        $WriteResult = $Null
        Write-Debug -Message '[Export-CertificateStoreBundle] Entering Process'

        $NowUtc = [System.DateTime]::UtcNow
        $CandidateCertificates = [System.Collections.Generic.List[
        System.Security.Cryptography.X509Certificates.X509Certificate2
        ]]::new()
        $DisallowedThumbprints = [System.Collections.Generic.List[System.String]]::new()
        $DisallowedThumbprintSet = [System.Collections.Generic.HashSet[System.String]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $FirstSourceStoreByHash = [System.Collections.Generic.Dictionary[
        System.String,
        System.String
        ]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $SeenEligibleThumbprints = [System.Collections.Generic.HashSet[System.String]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        foreach ($RequestedStoreName in $StoreName) {
            $StoreCertificates = Get-StoreCertificate `
                -StoreLocation $StoreLocation `
                -StoreName $RequestedStoreName

            foreach ($StoreCertificate in $StoreCertificates) {
                if ($Null -eq $StoreCertificate) {
                    continue
                }

                $CandidateCertificates.Add($StoreCertificate)
                $CertificateHash = Get-CertificateRawDataSha256 -Certificate $StoreCertificate

                if ($FirstSourceStoreByHash.ContainsKey($CertificateHash) -eq $False) {
                    $FirstSourceStoreByHash.Add($CertificateHash, $RequestedStoreName)
                }
            }
        }

        $DisallowedCertificates = Get-StoreCertificate `
            -StoreLocation $StoreLocation `
            -StoreName Disallowed

        foreach ($DisallowedCertificate in $DisallowedCertificates) {
            if ($Null -eq $DisallowedCertificate) {
                continue
            }

            $CertificateHash = Get-CertificateRawDataSha256 -Certificate $DisallowedCertificate
            $DisallowedThumbprints.Add($CertificateHash)
            [void]$DisallowedThumbprintSet.Add($CertificateHash)
        }

        foreach ($CandidateCertificate in $CandidateCertificates) {
            if ($IncludeExpired.IsPresent -eq $False) {
                $NotBeforeUtc = $CandidateCertificate.NotBefore.ToUniversalTime()
                $NotAfterUtc = $CandidateCertificate.NotAfter.ToUniversalTime()

                if ($NotAfterUtc -lt $NowUtc) {
                    $ExcludedExpired++
                    continue
                }

                if ($NotBeforeUtc -gt $NowUtc) {
                    $ExcludedNotYetValid++
                    continue
                }
            }

            $CertificateHash = Get-CertificateRawDataSha256 -Certificate $CandidateCertificate

            if ($DisallowedThumbprintSet.Contains($CertificateHash) -eq $True) {
                $ExcludedDisallowed++
                continue
            }

            if ($SeenEligibleThumbprints.Contains($CertificateHash) -eq $True) {
                $ExcludedDuplicate++
                continue
            }

            [void]$SeenEligibleThumbprints.Add($CertificateHash)
        }

        $CandidateCertificateArray = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$CandidateCertificates.ToArray()
        $SelectedCertificates = @(
            Select-ExportableCertificate `
                -Certificate $CandidateCertificateArray `
                -DisallowedThumbprint ([System.String[]]$DisallowedThumbprints.ToArray()) `
                -IncludeExpired:$IncludeExpired.IsPresent
        )

        $PemBlocks = [System.Collections.Generic.List[System.String]]::new()
        $DefaultSourceStore = 'Root'
        if ($StoreName.Count -gt 0) {
            $DefaultSourceStore = [System.String]$StoreName[0]
        }

        foreach ($SelectedCertificate in $SelectedCertificates) {
            $CertificateHash = Get-CertificateRawDataSha256 -Certificate $SelectedCertificate
            $SourceStore = $DefaultSourceStore

            if ($FirstSourceStoreByHash.ContainsKey($CertificateHash) -eq $True) {
                $SourceStore = [System.String]$FirstSourceStoreByHash[$CertificateHash]
            }

            $PemBlocks.Add(
                (
                    ConvertTo-PemCertificate `
                        -Certificate $SelectedCertificate `
                        -StoreName $SourceStore
                )
            )
        }

        $WriteResult = Write-CertificateBundle `
            -Path $Path `
            -PemBlock ([System.String[]]$PemBlocks.ToArray()) `
            -MinimumCertificateCount $MinimumCertificateCount `
            -WriteManifest:$WriteManifest.IsPresent

        $Status = [System.String]$WriteResult.Status
        $BundleSha256 = [System.String]$WriteResult.BundleSha256
        $ManifestPath = $WriteResult.ManifestPath

        New-CertificateStoreExporterResult `
            -Path $Path `
            -Status $Status `
            -Certificate $SelectedCertificates `
            -BundleSha256 $BundleSha256 `
            -Examined $CandidateCertificates.Count `
            -ExcludedExpired $ExcludedExpired `
            -ExcludedNotYetValid $ExcludedNotYetValid `
            -ExcludedDisallowed $ExcludedDisallowed `
            -ExcludedDuplicate $ExcludedDuplicate `
            -StoreLocation $StoreLocation `
            -StoreName $StoreName `
            -ManifestPath $ManifestPath

        Write-Debug -Message '[Export-CertificateStoreBundle] Exiting Process'
    }

    end {
        Write-Debug -Message '[Export-CertificateStoreBundle] Entering End'
        Write-Debug -Message '[Export-CertificateStoreBundle] Exiting End'
    }
}

#Requires -Version 5.1

function New-CertificateStoreExporterResult {
  <#
    .SYNOPSIS
        Creates the exporter success result object.

    .DESCRIPTION
        Creates the contract result object emitted only by successful exports.
        Certificate identity fields are computed as SHA-256 over each
        certificate's DER RawData bytes.

    .PARAMETER Path
        Destination bundle path.

    .PARAMETER Status
        Successful write status: Written, Unchanged, or WhatIf.

    .PARAMETER Certificate
        Certificates included in bundle order.

    .PARAMETER BundleSha256
        SHA-256 hash of the candidate or written bundle body.

    .PARAMETER Examined
        Number of certificates examined before filtering.

    .PARAMETER ExcludedExpired
        Count excluded because they were expired.

    .PARAMETER ExcludedNotYetValid
        Count excluded because they were not yet valid.

    .PARAMETER ExcludedDisallowed
        Count excluded because they appeared in Disallowed.

    .PARAMETER ExcludedDuplicate
        Count excluded because another certificate had the same identity.

    .PARAMETER StoreLocation
        Logical certificate store location.

    .PARAMETER StoreName
        Logical certificate store names used for the export.

    .PARAMETER ManifestPath
        Optional manifest sidecar path.

    .PARAMETER GeneratedAtUtc
        UTC generation timestamp for the object only.

    .EXAMPLE
        New-CertificateStoreExporterResult -Path .\bundle.pem -Status WhatIf -BundleSha256 $Hash

    .OUTPUTS
        [System.Management.Automation.PSCustomObject]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#new-certificatestoreexporterresult',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $True)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [System.String]
    $BundleSha256,

    [Parameter()]
    [AllowEmptyCollection()]
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    $Certificate = @(),

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $Examined = 0,

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $ExcludedDisallowed = 0,

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $ExcludedDuplicate = 0,

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $ExcludedExpired = 0,

    [Parameter()]
    [ValidateRange(0, [System.Int32]::MaxValue)]
    [System.Int32]
    $ExcludedNotYetValid = 0,

    [Parameter()]
    [System.DateTime]
    $GeneratedAtUtc = [System.DateTime]::UtcNow,

    [Parameter()]
    [AllowNull()]
    [System.String]
    $ManifestPath = $Null,

    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path,

    [Parameter(Mandatory = $True)]
    [ValidateSet('Written', 'Unchanged', 'WhatIf')]
    [System.String]
    $Status,

    [Parameter()]
    [ValidateSet('LocalMachine', 'CurrentUser')]
    [System.String]
    $StoreLocation = 'LocalMachine',

    [Parameter()]
    [ValidateSet('Root', 'CA')]
    [System.String[]]
    $StoreName = @('Root', 'CA')
  )

  Write-Debug -Message:'[New-CertificateStoreExporterResult] Entering'

  # Initialize Variable(s)
  [PSCustomObject]$Private:Excluded = $Null
  [PSCustomObject]$Private:Result = $Null
  [System.Collections.Generic.List[System.String]]$Private:Thumbprints = $Null

  $Thumbprints = [System.Collections.Generic.List[System.String]]::new()
  # Result identities are SHA-256 over RawData; X509Certificate2.Thumbprint is SHA-1.
  $Certificate | ForEach-Object -Process: {
    $Thumbprints.Add((Get-CertificateRawDataSha256 -Certificate:$PSItem))
  }

  $Excluded = [PSCustomObject]@{
    Expired     = [System.Int32]$ExcludedExpired
    NotYetValid = [System.Int32]$ExcludedNotYetValid
    Disallowed  = [System.Int32]$ExcludedDisallowed
    Duplicate   = [System.Int32]$ExcludedDuplicate
  }

  # It's always desirable to explicitly set the Result object with its desired class as close
  #   to the soft return to ensure the output is predictable and easily traceable.
  [PSCustomObject]$Result = [PSCustomObject]@{
    Path             = [System.String]$Path
    Status           = [System.String]$Status
    CertificateCount = [System.Int32]$Thumbprints.Count
    Thumbprints      = [System.String[]]$Thumbprints.ToArray()
    BundleSha256     = ([System.String]$BundleSha256).ToUpperInvariant()
    Examined         = [System.Int32]$Examined
    Excluded         = $Excluded
    StoreLocation    = [System.String]$StoreLocation
    StoreNames       = [System.String[]]$StoreName
    ManifestPath     = $ManifestPath
    # Normalize caller-supplied timestamps to UTC even though the default is already UTC.
    GeneratedAtUtc   = $GeneratedAtUtc.ToUniversalTime()
  }

  # Stamp the object so formatters and downstream consumers can identify the exporter contract.
  $Result.PSTypeNames.Insert(0, 'CertificateStoreExporter.Result')

  # Do a 'soft' return by outputting the result to the pipe without using the return keyword
  #   which would immediately end the function, this enables us to have the very last
  #   executing item be Write-Debug giving us a valuable breakpoint and better debugging output.
  $Result

  Write-Debug -Message:'[New-CertificateStoreExporterResult] Exiting'
}

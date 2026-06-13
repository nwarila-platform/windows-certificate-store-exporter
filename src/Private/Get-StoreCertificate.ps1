#Requires -Version 5.1

function Get-StoreCertificate {
    <#
    .SYNOPSIS
        Reads certificates from a Windows certificate store.

    .DESCRIPTION
        Opens one Windows X509Store read-only and returns its certificates. This
        is the only live certificate-store I/O seam in the exporter.

    .PARAMETER StoreLocation
        Logical certificate store location.

    .PARAMETER StoreName
        Logical certificate store name.

    .PARAMETER StoreFactory
        Internal factory used by tests to force store-open failures.

    .EXAMPLE
        Get-StoreCertificate -StoreLocation LocalMachine -StoreName Root

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
    param (
        [Parameter()]
        [ValidateSet('LocalMachine', 'CurrentUser')]
        [System.String]
        $StoreLocation = 'LocalMachine',

        [Parameter()]
        [ValidateSet('Root', 'CA', 'Disallowed')]
        [System.String]
        $StoreName = 'Root',

        [Parameter(DontShow = $True)]
        [ValidateNotNull()]
        [System.Management.Automation.ScriptBlock]
        $StoreFactory = {
            param (
                [Parameter(Mandatory = $True)]
                [System.String]
                $Name,

                [Parameter(Mandatory = $True)]
                [System.Security.Cryptography.X509Certificates.StoreLocation]
                $Location
            )

            [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, $Location)
        }
    )

    # Initalize Variable(s)
    [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]$Private:CertificateCollection = $Null
    [System.String]$Private:FailureMessage = [System.String]::Empty
    [System.Security.Cryptography.X509Certificates.OpenFlags]$Private:OpenFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly
    [System.Security.Cryptography.X509Certificates.X509Store]$Private:Store = $Null
    [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Private:StoreCertificates = @()
    [System.Security.Cryptography.X509Certificates.StoreLocation]$Private:TypedStoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine

    if ((Test-CertificateStoreExporterWindows) -eq $False) {
        New-ErrorRecord `
            -Message 'Windows certificate stores are only available on Windows.' `
            -ErrorId ([ExporterExitCode]::NotWindows) `
            -Category ([System.Management.Automation.ErrorCategory]::InvalidOperation) `
            -TargetObject ('{0}\{1}' -f $StoreLocation, $StoreName) `
            -IsFatal
    }

    $TypedStoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::$StoreLocation
    $OpenFlags = [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor [System.Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly

    try {
        $Store = & $StoreFactory $StoreName $TypedStoreLocation
        $Store.Open($OpenFlags)
        $CertificateCollection = $Store.Certificates
        $StoreCertificates = [System.Security.Cryptography.X509Certificates.X509Certificate2[]]@(
            $CertificateCollection | ForEach-Object -Process {
                $PSItem
            }
        )
    } catch {
        $FailureMessage = 'Failed to read Windows certificate store {0}\{1}: {2}' -f $StoreLocation, $StoreName, $PSItem.Exception.Message

        New-ErrorRecord `
            -Message $FailureMessage `
            -ErrorId ([ExporterExitCode]::StoreReadFailure) `
            -Category ([System.Management.Automation.ErrorCategory]::ReadError) `
            -TargetObject ('{0}\{1}' -f $StoreLocation, $StoreName) `
            -IsFatal
    } finally {
        if ($Null -ne $Store) {
            $Store.Dispose()
        }
    }

    $StoreCertificates
}

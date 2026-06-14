# Certificate Bundle Operations

Use these recipes after you have built or downloaded
`Export-CertificateStoreBundle.ps1`.

## Verify a Release Artifact

Download both release assets into the same directory:

- `Export-CertificateStoreBundle.ps1`
- `Export-CertificateStoreBundle.ps1.sha256`

Then verify the script hash:

```powershell
$ScriptPath = '.\Export-CertificateStoreBundle.ps1'
$SidecarPath = '.\Export-CertificateStoreBundle.ps1.sha256'

$Expected = ((Get-Content -Raw $SidecarPath) -split '\s+')[0]
$Actual = (Get-FileHash -Algorithm SHA256 -Path $ScriptPath).Hash

if ($Actual -ne $Expected) {
    throw "SHA-256 mismatch: expected $Expected but got $Actual"
}
```

The project does not publish Authenticode signatures yet. The `.sha256` sidecar
is the integrity check for release assets.

## Include Expired Certificates

Expired and not-yet-valid certificates are excluded by default. Include them
when you intentionally need historical or migration cross-signing material:

```powershell
.\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\ca-bundle.pem `
    -IncludeExpired
```

`Disallowed` subtraction and duplicate removal still apply.

## Write a Manifest

Use `-WriteManifest` to write a sidecar next to the bundle:

```powershell
$Result = .\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\ca-bundle.pem `
    -WriteManifest

Get-Content -Path $Result.ManifestPath
```

The sidecar is named `<bundle>.sha256` and contains:

```text
<64-character SHA-256>  <bundle file name>
```

## Use the Bundle with TLS Clients

The exporter is produce-only. It does not persist environment variables and does
not edit consumer configuration.

- AWS CLI:

```powershell
$env:AWS_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'
aws configure set ca_bundle C:\ProgramData\NWarila\ca-bundle.pem
```

- curl:

```powershell
$env:CURL_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'
curl.exe --cacert C:\ProgramData\NWarila\ca-bundle.pem https://example.com
```

- OpenSSL:

```powershell
$env:SSL_CERT_FILE = 'C:\ProgramData\NWarila\ca-bundle.pem'
openssl s_client -connect example.com:443 -CAfile C:\ProgramData\NWarila\ca-bundle.pem
```

- Python requests:

```powershell
$env:REQUESTS_CA_BUNDLE = 'C:\ProgramData\NWarila\ca-bundle.pem'
```

- git:

```powershell
git config --global http.sslCAInfo C:\ProgramData\NWarila\ca-bundle.pem
```

## Raise the Fail-Closed Floor

The default `-MinimumCertificateCount` is `1`. Raise it when automation expects
a known lower bound and should refuse to overwrite a good bundle if fewer
certificates survive filtering:

```powershell
.\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\ca-bundle.pem `
    -MinimumCertificateCount 25
```

If the surviving count is below the floor, the script throws
`BelowMinimumCertificateCount`, exits with code `2` through the entry script, and
writes nothing.

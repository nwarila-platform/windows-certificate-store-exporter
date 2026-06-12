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
    -Path C:\ProgramData\NWarila\aws-ca-bundle.pem `
    -IncludeExpired
```

`Disallowed` subtraction and duplicate removal still apply.

## Write a Manifest

Use `-WriteManifest` to write a sidecar next to the bundle:

```powershell
$Result = .\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\aws-ca-bundle.pem `
    -WriteManifest

Get-Content -Path $Result.ManifestPath
```

The sidecar is named `<bundle>.sha256` and contains:

```text
<64-character SHA-256>  <bundle file name>
```

## Wire the Bundle into the AWS CLI

The exporter is produce-only. It does not persist environment variables and does
not edit AWS CLI configuration.

Set the bundle for the current PowerShell process:

```powershell
$env:AWS_CA_BUNDLE = 'C:\ProgramData\NWarila\aws-ca-bundle.pem'
```

Or persist the path in an AWS CLI profile:

```powershell
aws configure set ca_bundle C:\ProgramData\NWarila\aws-ca-bundle.pem
```

Run an AWS command after setting one of those values:

```powershell
aws sts get-caller-identity
```

## Raise the Fail-Closed Floor

The default `-MinimumCertificateCount` is `1`. Raise it when automation expects
a known lower bound and should refuse to overwrite a good bundle if fewer
certificates survive filtering:

```powershell
.\Export-CertificateStoreBundle.ps1 `
    -Path C:\ProgramData\NWarila\aws-ca-bundle.pem `
    -MinimumCertificateCount 25
```

If the surviving count is below the floor, the script throws
`BelowMinimumCertificateCount`, exits with code `2` through the entry script, and
writes nothing.

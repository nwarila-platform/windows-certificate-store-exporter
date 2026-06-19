#Requires -Version 5.1
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Function New-X509Store {
  <#
    .SYNOPSIS
        Creates a Windows X509 certificate store object.

    .DESCRIPTION
        Wraps the X509Store constructor behind a mockable private function.

    .PARAMETER Location
        Logical certificate store location.

    .PARAMETER Name
        Logical certificate store name.

    .EXAMPLE
        New-X509Store -Name Root -Location LocalMachine

    .OUTPUTS
        [System.Security.Cryptography.X509Certificates.X509Store]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#new-x509store',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Security.Cryptography.X509Certificates.X509Store])]
  Param (
    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [System.Security.Cryptography.X509Certificates.StoreLocation]
    $Location,

    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Name
  )

  Write-Debug -Message:'[New-X509Store] Entering'

  # Initialize Variable(s)
  [System.Security.Cryptography.X509Certificates.X509Store]$Private:Result = $Null

  $Result = [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, $Location)

  $Result
  Write-Debug -Message:'[New-X509Store] Exiting'
}

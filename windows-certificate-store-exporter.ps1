#Requires -Version 5.1

<#
.SYNOPSIS
    Scaffold for the Windows certificate store exporter script.

.DESCRIPTION
    This repository currently consumes the repo conventions from
    NWarila/powershell-template while remaining a single-script project.
    Export behavior is intentionally not implemented yet.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

throw 'windows-certificate-store-exporter.ps1 is scaffolded only; export behavior is not implemented yet.'

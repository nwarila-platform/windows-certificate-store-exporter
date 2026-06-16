#Requires -Version 5.1

Function Resolve-ExitCode {
  <#
    .SYNOPSIS
        Resolves exporter error records to process exit codes.

    .DESCRIPTION
        Maps known short exporter ErrorId values to their process exit codes.
        Unknown errors intentionally produce no output so the EntryPoint trap can
        handle them as unhandled failures.

    .PARAMETER ErrorRecord
        Error record to inspect.

    .EXAMPLE
        Resolve-ExitCode -ErrorRecord $ErrorRecord

    .OUTPUTS
        [System.Int32]
    #>
  [CmdletBinding(
    ConfirmImpact = 'None',
    DefaultParameterSetName = 'default',
    HelpUri = 'https://github.com/nwarila-platform/windows-certificate-store-exporter/blob/main/docs/reference/functions.md#resolve-exitcode',
    PositionalBinding = $False,
    SupportsPaging = $False,
    SupportsShouldProcess = $False
  )]
  [OutputType([System.Int32])]
  Param (
    [Parameter(
      DontShow = $False,
      Mandatory = $True,
      ParameterSetName = 'default',
      ValueFromPipeline = $False,
      ValueFromPipelineByPropertyName = $False
    )]
    [ValidateNotNull()]
    [System.Management.Automation.ErrorRecord]
    $ErrorRecord
  )

  Write-Debug -Message:'[Resolve-ExitCode] Entering'

  # Initialize Variable(s)
  [ExporterExitCode]$Private:ExitCode = [ExporterExitCode]::Unhandled
  [System.String]$Private:FullyQualifiedErrorId = [System.String]::Empty
  [System.Int32]$Private:Result = 0
  [System.String]$Private:ShortErrorId = [System.String]::Empty

  $FullyQualifiedErrorId = [System.String]$ErrorRecord.FullyQualifiedErrorId
  # The short ErrorId is the leading segment before the first comma (ThrowTerminatingError appends
  #   ",<FunctionName>"); only that leading id maps to an exit code.
  $ShortErrorId = [System.String]($FullyQualifiedErrorId -split ',', 2)[0]

  # Only a KNOWN exporter ErrorId that is NOT Success/Unhandled maps to an explicit process exit
  #   code. Unknown ids and Success/Unhandled intentionally emit NOTHING, so the EntryPoint trap
  #   treats them as an unhandled failure (exit 1).
  If ([System.Enum]::IsDefined([ExporterExitCode], $ShortErrorId) -eq $True) {
    $ExitCode = [ExporterExitCode]$ShortErrorId

    If ($ExitCode -notin @([ExporterExitCode]::Success, [ExporterExitCode]::Unhandled)) {
      [System.Int32]$Result = [System.Int32]$ExitCode
      $Result
    }
  }

  Write-Debug -Message:'[Resolve-ExitCode] Exiting'
}

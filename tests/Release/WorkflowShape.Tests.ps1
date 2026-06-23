#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Describe 'release workflow shape' {
  BeforeAll {
    $script:ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:WorkflowPath = Join-Path -Path $script:ProjectRoot -ChildPath '.github\workflows\release.yaml'
    $script:WorkflowText = Get-Content -LiteralPath $script:WorkflowPath -Raw
    $script:JobNames = [System.String[]]@('seal', 'validate', 'publish', 'provenance', 'finalize')

    Function script:Get-WorkflowJobBlock {
      Param (
        [Parameter(Mandatory = $True)]
        [System.String]
        $Name
      )

      $EscapedName = [System.Text.RegularExpressions.Regex]::Escape($Name)
      $Pattern = '(?ms)^  ' + $EscapedName + ':\r?\n.*?(?=^  [A-Za-z0-9_-]+:\r?\n|\z)'
      $Match = [System.Text.RegularExpressions.Regex]::Match($script:WorkflowText, $Pattern)
      if (-not $Match.Success) {
        throw ('Workflow job not found: {0}' -f $Name)
      }

      $Match.Value
    }
  }

  It 'keeps seal read-only and module-free' {
    $Seal = Get-WorkflowJobBlock -Name 'seal'

    $Seal | Should -Match '(?ms)permissions:\s*\r?\n\s+contents:\s+read'
    $Seal | Should -Not -Match 'Install-Module'
    $Seal | Should -Match 'build\.ps1 -Task Build'
  }

  It 'keeps validate as the only module-installing job' {
    $JobsWithInstall = foreach ($JobName in $script:JobNames) {
      if ((Get-WorkflowJobBlock -Name $JobName) -match 'Install-Module') {
        $JobName
      }
    }

    $JobsWithInstall = [System.String[]]@($JobsWithInstall)
    $JobsWithInstall | Should -HaveCount 1
    $JobsWithInstall[0] | Should -Be 'validate'
  }

  It 'keeps validation and publication on downloaded release candidates' {
    $Validate = Get-WorkflowJobBlock -Name 'validate'
    $Publish = Get-WorkflowJobBlock -Name 'publish'

    $Validate | Should -Match 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093'
    $Validate | Should -Match 'name:\s+release-candidate'
    $Publish | Should -Match 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093'
    $Publish | Should -Match 'name:\s+release-candidate'
  }

  It 'keeps publish bound to the sealed digest output' {
    $Publish = Get-WorkflowJobBlock -Name 'publish'

    $Publish | Should -Match 'Assert-SealedDigest\.ps1'
    $Publish | Should -Match 'needs\.seal\.outputs\.digest'
    $Publish | Should -Not -Match '(?m)^\s*run:\s+powershell .*build\.ps1'
  }

  It 'keeps byte equality checks out of nondeterministic provenance finalization' {
    $Publish = Get-WorkflowJobBlock -Name 'publish'
    $Finalize = Get-WorkflowJobBlock -Name 'finalize'

    $Publish | Should -Match 'Release asset already exists with different bytes'
    $Finalize | Should -Not -Match 'Release asset already exists with different bytes'
  }

  It 'uploads release candidates only from seal' {
    $Seal = Get-WorkflowJobBlock -Name 'seal'

    $Seal | Should -Match 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02'
    $Seal | Should -Match 'name:\s+release-candidate'

    foreach ($JobName in @('validate', 'publish', 'finalize')) {
      (Get-WorkflowJobBlock -Name $JobName) | Should -Not -Match 'actions/upload-artifact@'
    }
  }

  It 'keeps the load-bearing job graph' {
    (Get-WorkflowJobBlock -Name 'validate') | Should -Match 'needs:\s+seal'
    (Get-WorkflowJobBlock -Name 'publish') | Should -Match 'needs:\s+\[seal,\s*validate\]'
    (Get-WorkflowJobBlock -Name 'provenance') | Should -Match 'needs:\s+\[seal,\s*publish\]'
    (Get-WorkflowJobBlock -Name 'finalize') | Should -Match 'needs:\s+\[publish,\s*provenance\]'
  }

  It 'keeps provenance in artifact mode with the generator-required startup permission' {
    # The SLSA generator (generator_generic_slsa3.yml) declares contents read/write across its
    # internal jobs, and GitHub validates reusable-workflow caller permissions AT STARTUP, so the
    # provenance caller MUST grant contents: write or the whole run is a startup_failure. With
    # upload-assets: false the generator's release-attaching job is if-skipped, so the grant stays
    # unused and finalize remains the sole asset attacher + draft->public flip (AUD-08 Option A).
    $Provenance = Get-WorkflowJobBlock -Name 'provenance'

    $Provenance | Should -Match 'generator_generic_slsa3\.yml@v2\.1\.0'
    $Provenance | Should -Match 'base64-subjects:\s+\$\{\{\s*needs\.seal\.outputs\.hashes\s*\}\}'
    $Provenance | Should -Match 'upload-assets:\s+false'
    $Provenance | Should -Not -Match 'upload-tag-name'
    $Provenance | Should -Match 'contents:\s+write'
  }

  It 'keeps the public release flip in finalize after provenance' {
    $Finalize = Get-WorkflowJobBlock -Name 'finalize'

    $Finalize | Should -Match 'needs:\s+\[publish,\s*provenance\]'
    $Finalize | Should -Match 'needs\.provenance\.outputs\.provenance-name'
    $Finalize | Should -Match 'draft\s*=\s*\$False'

    foreach ($JobName in @('seal', 'validate', 'publish', 'provenance')) {
      (Get-WorkflowJobBlock -Name $JobName) | Should -Not -Match 'draft\s*=\s*\$False'
    }
  }
}
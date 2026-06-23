#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Describe 'Write-CertificateBundle' {
  BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1')

    $Script:FirstPemBlock = "-----BEGIN CERTIFICATE-----`nQUJD`n-----END CERTIFICATE-----"
    $Script:SecondPemBlock = "-----BEGIN CERTIFICATE-----`nREVG`n-----END CERTIFICATE-----"

    function Get-TestSha256Hex {
      param (
        [Parameter(Mandatory = $True)]
        [System.Byte[]]
        $Bytes
      )

      $Sha256 = [System.Security.Cryptography.SHA256]::Create()

      try {
        [System.BitConverter]::ToString($Sha256.ComputeHash($Bytes)).Replace('-', '')
      } finally {
        $Sha256.Dispose()
      }
    }

    function Assert-TestBundleByte {
      param (
        [Parameter(Mandatory = $True)]
        [System.Byte[]]
        $Bytes
      )

      $Bytes[0..2] | Should -Not -Be ([System.Byte[]]@(0xEF, 0xBB, 0xBF))
      ($Bytes | Where-Object -FilterScript { $PSItem -gt 0x7F }) | Should -HaveCount 0
      [System.Text.Encoding]::ASCII.GetString($Bytes).Contains("`r") | Should -BeFalse
    }

    function Get-TestAtomicArtifact {
      param (
        [Parameter(Mandatory = $True)]
        [System.String]
        $Path
      )

      @(
        Get-ChildItem -LiteralPath $Path -Force -File |
          Where-Object -FilterScript {
            $PSItem.Name -like '*.tmp' -or
            $PSItem.Name -like '*.bak'
          }
      )
    }

    function Get-TestLockedStream {
      param (
        [Parameter(Mandatory = $True)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $True)]
        [System.IO.FileShare]
        $Share
      )

      # A held open handle is the deterministic fault-injection primitive: File.Replace throws while
      #   the share mode denies it the delete/rename access it needs, and FileShare.Read still lets
      #   the writer take its pre-swap ReadAllBytes snapshot.
      [System.IO.FileStream]::new(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        $Share
      )
    }
  }

  BeforeEach {
    $TestRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    $Null = New-Item -Path $TestRoot -ItemType Directory
  }

  AfterEach {
    if (Test-Path -LiteralPath $TestRoot) {
      Remove-Item -LiteralPath $TestRoot -Recurse -Force
    }
  }

  It 'creates a first bundle with ASCII LF bytes and no leftover temp files' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ExpectedText = '{0}{1}{2}' -f $Script:FirstPemBlock, "`n", $Script:SecondPemBlock

    $Result = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock, $Script:SecondPemBlock) `
      -MinimumCertificateCount 2

    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    $Result.Path | Should -Be $Path
    $Result.Status | Should -Be 'Written'
    $Result.CertificateCount | Should -Be 2
    $Result.BundleSha256 | Should -Be (Get-TestSha256Hex -Bytes $Bytes)
    $Result.ManifestPath | Should -BeNullOrEmpty
    [System.Text.Encoding]::ASCII.GetString($Bytes) | Should -Be $ExpectedText
    Assert-TestBundleByte -Bytes $Bytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'resolves PSDrive paths before writing bundle and manifest files' {
    $DriveName = 'BundleDrive{0}' -f ([System.Guid]::NewGuid().ToString('N').Substring(0, 8))
    $DriveRoot = Join-Path -Path $TestRoot -ChildPath 'drive-root'
    $Null = New-Item -Path $DriveRoot -ItemType Directory
    $Null = New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $DriveRoot
    $Path = '{0}:\bundle.pem' -f $DriveName
    $ExpectedPath = Join-Path -Path $DriveRoot -ChildPath 'bundle.pem'
    $ExpectedManifestPath = '{0}.sha256' -f $ExpectedPath

    try {
      $Result = Write-CertificateBundle `
        -Path $Path `
        -PemBlock @($Script:FirstPemBlock) `
        -WriteManifest

      $Result.Path | Should -Be $Path
      $Result.Status | Should -Be 'Written'
      $Result.ManifestPath | Should -Be ('{0}.sha256' -f $Path)
      Test-Path -LiteralPath $ExpectedPath | Should -BeTrue
      Test-Path -LiteralPath $ExpectedManifestPath | Should -BeTrue
      [System.IO.File]::ReadAllText($ExpectedPath) | Should -Be $Script:FirstPemBlock
      Get-ChildItem -LiteralPath $DriveRoot -Filter '*.tmp' | Should -HaveCount 0
    } finally {
      Remove-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
    }
  }

  It 'follows a junctioned output directory and keeps atomic artifacts on the resolved target' {
    $TargetDirectory = Join-Path -Path $TestRoot -ChildPath 'target'
    $JunctionPath = Join-Path -Path $TestRoot -ChildPath 'junction'
    $Null = New-Item -Path $TargetDirectory -ItemType Directory

    try {
      $Null = New-Item -Path $JunctionPath -ItemType Junction -Target $TargetDirectory -ErrorAction Stop
    } catch {
      Set-ItResult -Skipped -Because ('Unable to create a junction for the reparse-point test: {0}' -f $PSItem.Exception.Message)
      return
    }

    $Path = Join-Path -Path $JunctionPath -ChildPath 'bundle.pem'
    $TargetPath = Join-Path -Path $TargetDirectory -ChildPath 'bundle.pem'
    $FixedTime = [System.DateTime]::SpecifyKind(
      [System.DateTime]::Parse('2026-01-01T00:00:00Z'),
      [System.DateTimeKind]::Utc
    )

    $FirstResult = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    [System.IO.File]::SetLastWriteTimeUtc($TargetPath, $FixedTime)
    $SecondResult = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    $UnchangedWriteTime = [System.IO.File]::GetLastWriteTimeUtc($TargetPath)
    $ThirdResult = Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)
    $Bytes = [System.IO.File]::ReadAllBytes($TargetPath)

    $FirstResult.Path | Should -Be $Path
    $FirstResult.Status | Should -Be 'Written'
    $SecondResult.Status | Should -Be 'Unchanged'
    $UnchangedWriteTime | Should -Be $FixedTime
    $ThirdResult.Status | Should -Be 'Written'
    [System.IO.File]::GetLastWriteTimeUtc($TargetPath) | Should -Not -Be $FixedTime
    [System.Text.Encoding]::ASCII.GetString($Bytes) | Should -Be $Script:SecondPemBlock
    Assert-TestBundleByte -Bytes $Bytes
    Get-TestAtomicArtifact -Path $TargetDirectory | Should -HaveCount 0
  }

  It 'returns Unchanged and preserves bytes and mtime for identical content' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $FixedTime = [System.DateTime]::SpecifyKind(
      [System.DateTime]::Parse('2026-01-01T00:00:00Z'),
      [System.DateTimeKind]::Utc
    )

    $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    [System.IO.File]::SetLastWriteTimeUtc($Path, $FixedTime)
    $OriginalBytes = [System.IO.File]::ReadAllBytes($Path)

    $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)

    $Result.Status | Should -Be 'Unchanged'
    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBytes
    [System.IO.File]::GetLastWriteTimeUtc($Path) | Should -Be $FixedTime
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'replaces an existing bundle when the content changes' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

    $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)

    $Result.Status | Should -Be 'Written'
    [System.IO.File]::ReadAllText($Path) | Should -Be $Script:SecondPemBlock
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'leaves one complete bundle after concurrent replacements' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $GatePath = Join-Path -Path $TestRoot -ChildPath 'start.gate'
    $InitialPemBlock = "-----BEGIN CERTIFICATE-----`nR0hJ`n-----END CERTIFICATE-----"
    $FunctionPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\build\Export-CertificateStoreBundle.Functions.ps1'
    $ExpectedText = @($Script:FirstPemBlock, $Script:SecondPemBlock)
    $Jobs = @()

    $Null = Write-CertificateBundle -Path $Path -PemBlock @($InitialPemBlock)

    try {
      $Writer = {
        param (
          [Parameter(Mandatory = $True)]
          [System.String]
          $FunctionPath,

          [Parameter(Mandatory = $True)]
          [System.String]
          $Path,

          [Parameter(Mandatory = $True)]
          [System.String]
          $PemBlock,

          [Parameter(Mandatory = $True)]
          [System.String]
          $GatePath,

          [Parameter(Mandatory = $True)]
          [System.Int32]
          $DelayMilliseconds
        )

        $ErrorActionPreference = 'Stop'
        . $FunctionPath

        $Deadline = [System.DateTime]::UtcNow.AddSeconds(10)
        while ([System.IO.File]::Exists($GatePath) -eq $False) {
          if ([System.DateTime]::UtcNow -gt $Deadline) {
            throw 'Timed out waiting for the concurrent writer gate.'
          }

          Start-Sleep -Milliseconds 10
        }

        if ($DelayMilliseconds -gt 0) {
          Start-Sleep -Milliseconds $DelayMilliseconds
        }

        try {
          $Result = Write-CertificateBundle -Path $Path -PemBlock @($PemBlock)

          [PSCustomObject]@{
            ErrorId      = $Null
            Status       = $Result.Status
            Succeeded    = $True
            BundleSha256 = $Result.BundleSha256
          }
        } catch {
          [PSCustomObject]@{
            ErrorId      = $PSItem.FullyQualifiedErrorId
            Status       = 'Failed'
            Succeeded    = $False
            BundleSha256 = $Null
          }
        }
      }

      $Jobs += Start-Job -ScriptBlock $Writer -ArgumentList $FunctionPath, $Path, $Script:FirstPemBlock, $GatePath, 0
      $Jobs += Start-Job -ScriptBlock $Writer -ArgumentList $FunctionPath, $Path, $Script:SecondPemBlock, $GatePath, 250

      Start-Sleep -Milliseconds 500
      [System.IO.File]::WriteAllText($GatePath, 'go', [System.Text.UTF8Encoding]::new($False))

      $CompletedJobs = Wait-Job -Job $Jobs -Timeout 30
      $CompletedJobs | Should -HaveCount 2
      $JobResults = @($Jobs | Receive-Job -ErrorAction Stop)
    } finally {
      $Jobs | Remove-Job -Force
    }

    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    $FinalText = [System.Text.Encoding]::ASCII.GetString($Bytes)

    $JobResults | Should -HaveCount 2
    ($JobResults | Where-Object -FilterScript { $PSItem.Succeeded -ne $True }) | Should -HaveCount 0
    ($JobResults | Where-Object -FilterScript { $PSItem.Status -ne 'Written' }) | Should -HaveCount 0
    $ExpectedText | Should -Contain $FinalText
    Assert-TestBundleByte -Bytes $Bytes
    Get-TestAtomicArtifact -Path $TestRoot | Should -HaveCount 0
  }

  It 'fails closed instead of leaving a stale sidecar when changed content omits WriteManifest' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $OriginalManifestBytes = [System.IO.File]::ReadAllBytes($ManifestPath)

    {
      Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord' -ExpectedMessage '*existing .sha256 sidecar would become stale*'

    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    [System.IO.File]::ReadAllBytes($ManifestPath) | Should -Be $OriginalManifestBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'fails closed when the first bundle write would orphan an existing sidecar' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path
    $ManifestText = 'stale sidecar'
    [System.IO.File]::WriteAllText($ManifestPath, $ManifestText, [System.Text.UTF8Encoding]::new($False))
    $OriginalManifestBytes = [System.IO.File]::ReadAllBytes($ManifestPath)

    {
      Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord' -ExpectedMessage '*existing .sha256 sidecar would become stale*'

    Test-Path -LiteralPath $Path | Should -BeFalse
    [System.IO.File]::ReadAllBytes($ManifestPath) | Should -Be $OriginalManifestBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'fails closed under WhatIf when changed content would leave a stale sidecar' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $OriginalManifestBytes = [System.IO.File]::ReadAllBytes($ManifestPath)

    {
      Write-CertificateBundle `
        -Path $Path `
        -PemBlock @($Script:SecondPemBlock) `
        -WhatIf
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord' -ExpectedMessage '*existing .sha256 sidecar would become stale*'

    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    [System.IO.File]::ReadAllBytes($ManifestPath) | Should -Be $OriginalManifestBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'keeps the unchanged no-manifest path valid when a sidecar already exists' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $OriginalManifestBytes = [System.IO.File]::ReadAllBytes($ManifestPath)

    $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)

    $Result.Status | Should -Be 'Unchanged'
    $Result.ManifestPath | Should -BeNullOrEmpty
    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    [System.IO.File]::ReadAllBytes($ManifestPath) | Should -Be $OriginalManifestBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'writes changed content without a manifest when no sidecar exists' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    $Result = Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)

    $Result.Status | Should -Be 'Written'
    $Result.ManifestPath | Should -BeNullOrEmpty
    [System.IO.File]::ReadAllText($Path) | Should -Be $Script:SecondPemBlock
    Test-Path -LiteralPath $ManifestPath | Should -BeFalse
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'throws below the minimum count and leaves an existing bundle intact' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ExistingText = 'existing bundle'
    [System.IO.File]::WriteAllText($Path, $ExistingText, [System.Text.UTF8Encoding]::new($False))

    {
      Write-CertificateBundle `
        -Path $Path `
        -PemBlock @($Script:FirstPemBlock) `
        -MinimumCertificateCount 2
    } | Should -Throw -ErrorId 'BelowMinimumCertificateCount,New-ErrorRecord'

    [System.IO.File]::ReadAllText($Path) | Should -Be $ExistingText
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'rejects non-ASCII bundle content before writing' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $InvalidBlock = '-----BEGIN CERTIFICATE-----' + [System.Char]0x00E9

    {
      Write-CertificateBundle -Path $Path -PemBlock @($InvalidBlock)
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

    Test-Path -LiteralPath $Path | Should -BeFalse
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'wraps filesystem write failures with the write-failure ErrorId' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'missing\bundle.pem'

    {
      Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

    Test-Path -LiteralPath $Path | Should -BeFalse
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'rejects non-FileSystem provider paths before writing' {
    {
      Write-CertificateBundle `
        -Path 'Variable:\CertificateStoreExporterBundle' `
        -PemBlock @($Script:FirstPemBlock)
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'honors WhatIf without writing bundle or manifest bytes' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

    $Result = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest `
      -WhatIf

    $Result.Status | Should -Be 'WhatIf'
    $Result.CertificateCount | Should -Be 1
    $Result.ManifestPath | Should -Be ('{0}.sha256' -f $Path)
    Test-Path -LiteralPath $Path | Should -BeFalse
    Test-Path -LiteralPath $Result.ManifestPath | Should -BeFalse
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'writes an opt-in sha256sum manifest consistently and idempotently' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

    $Result = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest

    $ManifestPath = '{0}.sha256' -f $Path
    $BundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $ExpectedManifest = '{0}  {1}{2}' -f
    (Get-TestSha256Hex -Bytes $BundleBytes),
    [System.IO.Path]::GetFileName($Path),
    "`n"

    $Result.Status | Should -Be 'Written'
    $Result.ManifestPath | Should -Be $ManifestPath
    [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ExpectedManifest
    Assert-TestBundleByte -Bytes ([System.IO.File]::ReadAllBytes($ManifestPath))

    $SecondResult = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest

    $SecondResult.Status | Should -Be 'Unchanged'
    [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ExpectedManifest

    $ThirdResult = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:SecondPemBlock) `
      -WriteManifest
    $ChangedBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $ChangedManifest = '{0}  {1}{2}' -f
    (Get-TestSha256Hex -Bytes $ChangedBundleBytes),
    [System.IO.Path]::GetFileName($Path),
    "`n"

    $ThirdResult.Status | Should -Be 'Written'
    [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ChangedManifest
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
  }

  It 'rolls the prior pair back to disk when the manifest swap fails after the bundle swap' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $OriginalManifestBytes = [System.IO.File]::ReadAllBytes($ManifestPath)

    # Lock only the existing manifest: the bundle swap commits, then the manifest swap File.Replace
    #   throws, forcing the bundle rollback to run (and succeed) back to the prior pair.
    $ManifestHandle = Get-TestLockedStream -Path $ManifestPath -Share ([System.IO.FileShare]::Read)

    try {
      {
        Write-CertificateBundle `
          -Path $Path `
          -PemBlock @($Script:SecondPemBlock) `
          -WriteManifest
      } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'
    } finally {
      $ManifestHandle.Dispose()
    }

    # Fault fired: the new bytes are NOT on disk; the exact prior pair survives.
    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    [System.IO.File]::ReadAllBytes($ManifestPath) | Should -Be $OriginalManifestBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'leaves the bundle present (never missing) when the rollback itself fails' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest

    # Lock the bundle Read+Delete so its swap commits (the prior bundle is renamed to the retained
    #   backup, carrying this handle) but the rollback File.Replace on that backup throws; lock the
    #   manifest Read so its swap throws and forces the rollback to run.
    $BundleHandle = Get-TestLockedStream `
      -Path $Path `
      -Share ([System.IO.FileShare]::Read -bor [System.IO.FileShare]::Delete)
    $ManifestHandle = Get-TestLockedStream -Path $ManifestPath -Share ([System.IO.FileShare]::Read)

    try {
      {
        Write-CertificateBundle `
          -Path $Path `
          -PemBlock @($Script:SecondPemBlock) `
          -WriteManifest
      } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

      # Fault fired: the rollback failed, so the bundle is present but holds the NEW bytes (the
      #   documented mismatched-but-never-missing residual) rather than the prior bytes or nothing.
      Test-Path -LiteralPath $Path | Should -BeTrue
      [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($Path)) |
        Should -Be $Script:SecondPemBlock
    } finally {
      $BundleHandle.Dispose()
      $ManifestHandle.Dispose()
    }

    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'deletes a first-written bundle when the manifest swap fails so no orphan remains' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    # A directory at the manifest path keeps File.Exists False (the writer takes the first-write
    #   Move branch) while the Move itself throws, orphaning the just-written bundle.
    $Null = New-Item -Path $ManifestPath -ItemType Directory

    {
      Write-CertificateBundle `
        -Path $Path `
        -PemBlock @($Script:FirstPemBlock) `
        -WriteManifest
    } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'

    # Fault fired: the orphaned first-write bundle is deleted and no manifest file is left behind.
    Test-Path -LiteralPath $Path | Should -BeFalse
    Test-Path -LiteralPath $ManifestPath -PathType Leaf | Should -BeFalse
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'leaves the existing bundle untouched when the bundle swap fails' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'

    $Null = Write-CertificateBundle -Path $Path -PemBlock @($Script:FirstPemBlock)
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)

    # Lock the existing bundle Read so its swap File.Replace throws before any backup is taken.
    $BundleHandle = Get-TestLockedStream -Path $Path -Share ([System.IO.FileShare]::Read)

    try {
      {
        Write-CertificateBundle -Path $Path -PemBlock @($Script:SecondPemBlock)
      } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'
    } finally {
      $BundleHandle.Dispose()
    }

    # Fault fired: the new bytes never reached the bundle; the original is intact.
    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'never touches an unchanged bundle when only the manifest swap fails' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path
    $FixedTime = [System.DateTime]::SpecifyKind(
      [System.DateTime]::Parse('2026-01-01T00:00:00Z'),
      [System.DateTimeKind]::Utc
    )

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest
    $OriginalBundleBytes = [System.IO.File]::ReadAllBytes($Path)
    [System.IO.File]::SetLastWriteTimeUtc($Path, $FixedTime)

    # Corrupt the sidecar so the bundle stays byte-identical (its swap is skipped) but the manifest
    #   must be rewritten, then lock the manifest so that lone swap throws.
    [System.IO.File]::WriteAllText($ManifestPath, 'stale sidecar', [System.Text.UTF8Encoding]::new($False))
    $ManifestHandle = Get-TestLockedStream -Path $ManifestPath -Share ([System.IO.FileShare]::Read)

    try {
      {
        Write-CertificateBundle `
          -Path $Path `
          -PemBlock @($Script:FirstPemBlock) `
          -WriteManifest
      } | Should -Throw -ErrorId 'WriteFailure,New-ErrorRecord'
    } finally {
      $ManifestHandle.Dispose()
    }

    # Fault fired: the unchanged bundle's bytes and mtime are untouched (no swap, no rollback).
    [System.IO.File]::ReadAllBytes($Path) | Should -Be $OriginalBundleBytes
    [System.IO.File]::GetLastWriteTimeUtc($Path) | Should -Be $FixedTime
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }

  It 'writes a new bundle and manifest and deletes both backups at commit' {
    $Path = Join-Path -Path $TestRoot -ChildPath 'bundle.pem'
    $ManifestPath = '{0}.sha256' -f $Path

    $Null = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:FirstPemBlock) `
      -WriteManifest

    $Result = Write-CertificateBundle `
      -Path $Path `
      -PemBlock @($Script:SecondPemBlock) `
      -WriteManifest
    $BundleBytes = [System.IO.File]::ReadAllBytes($Path)
    $ExpectedManifest = '{0}  {1}{2}' -f
    (Get-TestSha256Hex -Bytes $BundleBytes),
    [System.IO.Path]::GetFileName($Path),
    "`n"

    $Result.Status | Should -Be 'Written'
    [System.IO.File]::ReadAllText($Path) | Should -Be $Script:SecondPemBlock
    [System.IO.File]::ReadAllText($ManifestPath) | Should -Be $ExpectedManifest
    # 0 leftover .bak proves both retained backups are discarded at the commit point.
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.tmp' | Should -HaveCount 0
    Get-ChildItem -LiteralPath $TestRoot -Filter '*.bak' | Should -HaveCount 0
  }
}

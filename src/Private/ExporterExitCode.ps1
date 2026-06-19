#Requires -Version 5.1
# SPDX-FileCopyrightText: 2026 Nicholas Warila
# SPDX-License-Identifier: MIT

Enum ExporterExitCode {
  Success = 0
  Unhandled = 1
  BelowMinimumCertificateCount = 2
  NotWindows = 3
  StoreReadFailure = 4
  WriteFailure = 5
}

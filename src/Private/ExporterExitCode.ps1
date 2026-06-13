#Requires -Version 5.1

enum ExporterExitCode {
    Success                      = 0
    Unhandled                    = 1
    BelowMinimumCertificateCount = 2
    NotWindows                   = 3
    StoreReadFailure             = 4
    WriteFailure                 = 5
}

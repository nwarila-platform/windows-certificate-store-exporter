#Requires -Version 5.1

Set-Variable `
    -Name 'CertificateStoreExporterErrorIdNotWindows' `
    -Value 'NotWindows' `
    -Option ReadOnly `
    -Scope Script `
    -Force `
    -WhatIf:$False

Set-Variable `
    -Name 'CertificateStoreExporterErrorIdStoreReadFailure' `
    -Value 'StoreReadFailure' `
    -Option ReadOnly `
    -Scope Script `
    -Force `
    -WhatIf:$False

Set-Variable `
    -Name 'CertificateStoreExporterErrorIdBelowMinimumCertificateCount' `
    -Value 'BelowMinimumCertificateCount' `
    -Option ReadOnly `
    -Scope Script `
    -Force `
    -WhatIf:$False

Set-Variable `
    -Name 'CertificateStoreExporterErrorIdWriteFailure' `
    -Value 'WriteFailure' `
    -Option ReadOnly `
    -Scope Script `
    -Force `
    -WhatIf:$False

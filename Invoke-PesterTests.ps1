"current location: $(Get-Location)"
"script root: $PSScriptRoot"

Install-Module -Name Pester -RequiredVersion "4.10.1" -SkipPublisherCheck
    
Invoke-Pester -Script "./win_scripts/*.Tests.ps1" -OutputFile "./pester_test_results.XML" -OutputFormat 'NUnitXML' -CodeCoverage "./win_scripts/*.ps1"
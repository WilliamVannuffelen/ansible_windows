    "current location: $(Get-Location)"
    "script root: $PSScriptRoot"
    "retrieve available modules"
    $modules = Get-Module -list
    if($modules.Name -notcontains 'pester'){
        Install-Module -Name Pester -Force -SkipPublisherCheck
    }
    Invoke-Pester -Script "./win_scripts/*.Tests.ps1" -OutputFile "./pester_test_results.XML" -OutputFormat 'NUnitXML' -CodeCoverage "./win_scripts/*.ps1"
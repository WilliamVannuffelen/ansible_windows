Write-Output "Installing Pester v4.10.1 on build agent"
Install-Module -Name Pester -RequiredVersion "4.10.1" -SkipPublisherCheck -Force -Confirm:$false

Write-Output "Running Pester tests"
Invoke-Pester -Script "./win_scripts/*.Tests.ps1" -OutputFile "./pester_test_results.XML" -OutputFormat 'NUnitXML' -CodeCoverage "./win_scripts/*.ps1"
Write-Output "Installing Pester v4.10.1 on build agent"
Install-Module -Name Pester -RequiredVersion "4.10.1" -SkipPublisherCheck -Force -Confirm:$false

Write-Output "Running Pester tests"

$params = @{
    script = "./win_scripts/*.Tests.ps1"
    outputFile = "./pester_test_results.xml"
    outputFormat = "NUnitXML"
    codeCoverage = "./win_scripts/*.ps1"
    codeCoverageOutputFile = "./pester_coverage_results.xml"
    codeCoverageOutputFileFormat = "JaCoCo"
}
Invoke-Pester @params 

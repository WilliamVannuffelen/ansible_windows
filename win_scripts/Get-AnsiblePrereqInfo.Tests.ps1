$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe 'Get-AnsiblePrereqInfo'{
    Context 'Get-PSVersionInfo'{
        $testCases = @(
            @{
                psVersion = ([version]'5.3.17763.1007')
                expected = $true
            }
            @{
                psVersion = ([version]'3.0.5094.45')
                expected = $true
            }
            @{
                psVersion = ([version]'2.0.103.03')
                expected = $false
            }
            @{
                psVersion = $null
                expected = $null
            }
        )

        It 'ensures compatibility is <expected> for version <psVersion>' -TestCases $testCases {
            param ($psVersion, $expected)

            $psVersionInfo = Get-PSVersionInfo $psVersion
            $psVersionInfo.ps_compatible | Should -Be $expected
        }

    }
    Context 'Get-DotNetVersionInfo'{
        $testCases = @(
            @{
                dotNetRegPathExists = $false
                dotNetVersionInfo = $null
                expected = $false
            }
            @{
                dotNetRegPathExists = $true
                dotNetVersionInfo = [PSCustomObject]@{
                    version = ([version]"4.7.03190")
                    release = 461814
                }
                expected = $true
            }
        )

        It 'ensures compatibility is <expected> for version <dotNetVersionInfo>' -TestCases $testCases {
           param ($dotNetRegPathExists, $dotNetVersionInfo, $expected)

            Mock Test-Path{
                return $dotNetRegPathExists
            }
            Mock Get-ItemProperty{
                return $dotNetVersionInfo
            }
           $dotNetVersionInfo = Get-DotNetVersionInfo
           $dotNetVersionInfo.dotnet_compatible | Should -Be $expected
        }
    }
    Context 'Get-WinRMHotfixStatus'{
        function Get-Hotfix {
            return $winRmHotfix
        }
        $testCases = @(
            @{
                psVersionInfo = [PSCustomObject]@{ps_version_major = 3}
                winRmHotfix = $true
                expected = $true
            }
            @{
                psVersionInfo = [PSCustomObject]@{ps_version_major = 3}
                winRmHotfix = $null
                expected = $false
            }
            @{
                psVersionInfo =[PSCustomObject]@{ps_version_major = 5}
                winRmHotfix = $false
                expected = $true
            }
        )
        
        It 'ensures WinRM hotfix status is <expected> for <psVersionInfo> and hotfix object is <winRmHotfix>' -TestCases $testCases {
            param ($psVersionInfo, $winRmHotfix, $expected)

            $hotfixId = "KB2842230"
            Mock Get-Hotfix{
                return $winRmHotfix
            }
            $winRmHotfixStatus = Get-WinRMHotfixStatus $psVersionInfo
            $winRmHotfixStatus.hotfix_status_ok | Should -Be $expected
        }
    }
}
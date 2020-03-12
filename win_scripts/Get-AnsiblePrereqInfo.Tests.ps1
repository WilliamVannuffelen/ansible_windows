$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe 'Get-AnsiblePrereqInfo'{
    Context 'Get-PSVersionInfo'{
        $testCases = @(
            @{
                psVersion = ([version]"5.3.17763.1007")
                expected = $true
            }
            @{
                psVersion = ([version]"3.0.5094.45")
                expected = $true
            }
            @{
                psVersion = ([version]"2.0.103.03")
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
}
<#
    Context 'Get-WinRMHotfixStatus'{
        Mock 'Get-PSVersionInfo'{
            [PSCustomObject]@{
                "ps_version_simple" = "5.1"
                "ps_version_major" = "5"
                "ps_compatible" = $true
            }
        }
        Get-PSVersionInfo
        Get-WinRMHotfixStatus $psVersionInfo
        It 'should not be null'{

            $winRmHotfixInfo | Should -Not -Be $null
        }
        It 'bool should match expected value'{
            $winRmHotfixInfo.hotfix_required | Should -Be $false
            $winRmHotfixInfo.hotfix_installed | Should -Be $false
            $winRmHotfixInfo.hotfix_status_ok | Should -Be $true
        }
    }
}
#>

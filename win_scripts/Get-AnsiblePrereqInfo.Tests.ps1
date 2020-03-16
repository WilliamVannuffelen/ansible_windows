$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe 'Get-AnsiblePrereqInfo'{
    Context 'Get-OSVersionInfo'{
        $testCases = @(
            @{
                osWmiObject = [PSCustomObject]@{
                    caption = 'Microsoft Windows Server 2012 Standard'
                    version = '6.2.9200'
                    servicePackMajorVersion = 0
                }
                expected = $true
            }
            @{
                osWmiObject = [PSCustomObject]@{
                    caption = 'Microsoft Windows Server 2008 R2 Standard'
                    version = '6.1.7601'
                    servicePackMajorVersion = 1
                }
                expected = $true
            }
            @{
                osWmiObject = [PSCustomObject]@{
                    caption = 'Windows Server 2008 Standard without Hyper-V'
                    version = '6.0.0001'
                    servicePackMajorVersion = 1
                }
                expected = $false
            }
        )

        It 'ensures OS compatibility is <expected> for OS <osWmiObject>' -TestCases $testCases {
            param ($osWmiObject, $expected)

            Mock Get-WMIObject {
                return $osWmiObject
            }

            $osVersionInfo = Get-OSVersionInfo
            $osVersionInfo.os_compatible | Should -Be $expected
        }
    }
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

        It 'ensures PS compatibility is <expected> for version <psVersion>' -TestCases $testCases {
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
    Context 'Get-WinRMHotfixInfo'{
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

            Mock Get-Hotfix{
                return $winRmHotfix
            }
            $winRmHotfixInfo = Get-WinRMHotfixStatus $psVersionInfo
            $winRmHotfixInfo.hotfix_status_ok | Should -Be $expected
        }
    }


}
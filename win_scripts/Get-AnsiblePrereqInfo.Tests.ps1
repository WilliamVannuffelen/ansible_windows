$modulePath = $myInvocation.myCommand.path -replace '.Tests.ps1$'
$moduleName = $modulePath | Split-Path -Leaf

Get-Module -Name $moduleName | Remove-Module -Force -ErrorAction Ignore
Import-Module -Name "$modulePath.psm1" -Force -ErrorAction Stop

InModuleScope $moduleName {
    Describe 'Get-AnsiblePrereqInfo'{
        Context 'Get-OSVersionInfo'{
            function Invoke-Command {
                return $osVersionInfo
            }
            $testCases = @(
                @{
                    osWmiObject = [PSCustomObject]@{
                        caption = 'Microsoft Windows Server 2012 Standard'
                        version = '6.2.9200'
                        servicePackMajorVersion = 0
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    osWmiObject = [PSCustomObject]@{
                        caption = 'Microsoft Windows Server 2008 R2 Standard'
                        version = '6.1.7601'
                        servicePackMajorVersion = 1
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    osWmiObject = [PSCustomObject]@{
                        caption = 'Windows Server 2008 Standard without Hyper-V'
                        version = '6.0.0001'
                        servicePackMajorVersion = 1
                    }
                    invocationError = $false
                    expected = $false
                }
                @{
                    osWmiObject = $null
                    invocationError = $true
                    expected = 'unknown'
                }
            )

            It 'ensures OS compatibility is <expected> for OS <osWmiObject> and invocation error state is <invocationError>' -TestCases $testCases {
                param ($osWmiObject, $invocationError, $expected)

                if($invocationError -eq $true){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $osWmiObject
                    }
                }

                $osVersionInfo, $logData = Get-OSVersionInfo -psSession "test" -ComputerName "test"
                $osversioninfo | select os_version_name,os_version,os_sp_version,os_compatible | out-file '/home/wvannuffelen/ansible/development/ansible_windows/win_scripts/temp.txt' -append
                $logData | out-file '/home/wvannuffelen/ansible/development/ansible_windows/win_scripts/temp.txt' -append
                $osVersionInfo.os_compatible | Should -Be $expected
            }

            It 'ensures logData is an arrayList of strings when invocation error state is <invocationError>' -TestCases $testCases[0,3] {
                param ($osWmiObject, $invocationError)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $osWmiObject
                    }
                }
                
                $osVersionInfo, $logData = Get-OSVersionInfo
                ,$logData | Should -BeOfType [System.Collections.ArrayList]
                $logData | Should -BeOfType [string]
            }
        }

        Context 'Get-PSVersionInfo'{
            function Invoke-Command {
                return $psVersion
            }
            $testCases = @(
                @{
                    psVersion = ([version]'5.3.17763.1007')
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersion = ([version]'3.0.5094.45')
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersion = ([version]'2.0.103.03')
                    invocationError = $false
                    expected = $false
                }
                @{
                    psVersion = $null
                    invocationError = $false
                    expected = $false
                }
                @{
                    psVersion = $null
                    invocationError = $true
                    expected = 'unknown'
                }
            )

            It 'ensures PS compatibility is <expected> for version <psVersion> and invocation error state is <invocationError>' -TestCases $testCases {
                param ($psVersion, $invocationError, $expected)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $psVersion
                    }
                }

                $psVersionInfo, $logData = Get-PSVersionInfo
                $psVersionInfo.ps_compatible | Should -Be $expected
            }

            It 'ensures logData is an arrayList of strings when invocation error state is <invocationError>' -TestCases $testCases[0,3,4] {
                param ($psVersion, $invocationError)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $psVersion
                    }
                }

                $psVersionInfo, $logData = Get-PSVersionInfo
                ,$logData | Should -BeOfType [System.Collections.ArrayList]
                $logData | Should -BeOfType [string]
            }
        }
        Context 'Get-DotNetVersionInfo'{
            function Invoke-Command {
                return $dotNetVersion
            }
            $testCases = @(
                @{
                    dotNetVersion = $null
                    invocationError = $false
                    expected = $false
                }
                @{
                    dotNetVersion = [PSCustomObject]@{
                        version = ([version]"4.7.03190")
                        release = 461814
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    dotNetVersion = [PSCustomObject]@{
                        version = ([version]"4.7.03190")
                        release = 461814
                    }
                    invocationError = $true
                    expected = 'unknown'
                }
            )

            It 'ensures compatibility is <expected> for version <dotNetVersion> and invocation error state is <invocationError>' -TestCases $testCases {
            param ($dotNetVersion, $invocationError, $expected)

            if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                elseif($null -eq $dotNetVersion){
                    $exception = New-Object System.Management.Automation.ItemNotFoundException
                    Mock Invoke-Command {
                        throw $exception
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $dotNetVersion
                    }
                }
            $dotNetVersionInfo, $logData = Get-DotNetVersionInfo
            $dotNetVersionInfo.dotnet_compatible | Should -Be $expected
            }

            It 'ensures logData is an arrayList of strings when invocation error state is <invocationError>' -TestCases $testCases {
                param ($dotNetVersionInfo, $invocationError)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                elseif($null -eq $dotNetVersion){
                    $exception = New-Object System.Management.Automation.ItemNotFoundException
                    Mock Invoke-Command {
                        throw $exception
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $dotNetVersion
                    }
                }

                $dotNetVersionInfo, $logData = Get-DotNetVersionInfo
                ,$logData | Should -BeOfType [System.Collections.ArrayList]
                $logData | Should -BeOfType [string]
            }
        }
        Context 'Get-WinRMHotfixInfo'{
            function Invoke-Command {
                return $hotFixList
            }
            $testCases = @(
                @{
                    psVersionInfo = [PSCustomObject]@{ps_version_major = 3}
                    hotfixList = @(
                        [PSCustomObject]@{hotfixId = 'KB0000001'},
                        [PSCustomObject]@{hotfixId = 'KB0000002'},
                        [PSCustomObject]@{hotfixId = 'KB2842230'}
                        )
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersionInfo = [PSCustomObject]@{ps_version_major = 3}
                    hotfixList = @(
                        [PSCustomObject]@{hotfixId = 'KB0000001'},
                        [PSCustomObject]@{hotfixId = 'KB0000002'}
                        )
                    invocationError = $false
                    expected = $false
                }
                @{
                    psVersionInfo =[PSCustomObject]@{ps_version_major = 5}
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersionInfo = [PSCustomObject]@{ps_version_major = 3}
                    hotfixList = @(
                        [PSCustomObject]@{hotfixId = 'KB0000001'},
                        [PSCustomObject]@{hotfixId = 'KB0000002'},
                        [PSCustomObject]@{hotfixId = 'KB2842230'}
                        )
                    invocationError = $true
                    expected = 'unknown'
                }
            )
            
            It 'ensures WinRM hotfix status is <expected> for <psVersionInfo>, hotfix list <hotfixList> and invocation error is <invocationError>' -TestCases $testCases {
                param ($psVersionInfo, $hotfixList, $invocationError, $expected)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        $hotFixList
                    }
                }
                $winRmHotfixInfo = Get-WinRMHotfixInfo -psVersionInfo $psVersionInfo
                $winRmHotfixInfo.hotfix_status_ok | Should -Be $expected
            }

            It 'ensures logData is an arrayList of strings when invocation error state is <invocationError>' -TestCases $testCases {
                param ($psVersionInfo, $hotfixList, $invocationError)

                if($invocationError){
                    Mock Invoke-Command {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        $hotFixList
                    }
                }

                $winRmHotfixInfo, $logData = Get-WinRmHotfixInfo -psVersionInfo $psVersionInfo
                ,$logData | Should -BeOfType [System.Collections.ArrayList]
                $logData | Should -BeOfType [string]
            }
        }
    }
}
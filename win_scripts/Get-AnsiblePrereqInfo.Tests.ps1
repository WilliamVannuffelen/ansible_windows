$modulePath = $myInvocation.myCommand.path -replace '.Tests.ps1$'
$moduleName = $modulePath | Split-Path -Leaf

Get-Module -Name $moduleName | Remove-Module -Force -ErrorAction Ignore
Import-Module -Name "$modulePath.psm1" -Force -ErrorAction Stop

InModuleScope $moduleName {
    Describe 'Get-AnsiblePrereqInfo'{
        Context 'Get-ServerIpAddress' {
            function DotNet-GetHostByName {
                return $ipHostEntry
            }

            $testCases = @(
                @{
                    ipHostEntry = [psCustomObject]@{
                        hostName = 'exists in DNS'
                        addressList = @('2607:f8b0:4000:804::2003', '172.217.6.163')
                    }
                    invocationError = $false
                    expected = [string]'2607:f8b0:4000:804::2003, 172.217.6.163'
                }
                @{
                    ipHostEntry = [psCustomObject]@{
                        hostName = "doesn't exist in DNS"
                        addressList = $null
                    }
                    invocationError = $false
                    expected = [string]'unknown'
                }
                @{
                    ipHostEntry = [psCustomObject]@{
                        hostname = "exists in DNS"
                        addressList = @('2607:f8b0:4000:804::2003', '172.217.6.163')
                    }
                    invocationError = $true
                    expected = [string]'unknown'
                }
            )

            It 'ensures ipAddress is <expected> for <ipHostEntry> and invocation error is <invocationError>' -TestCases $testCases {
                param($ipHostEntry, $invocationError, $expected)

                if($ipHostEntry.hostName -like "doesn*"){
                    $exception = New-Object System.Management.Automation.MethodInvocationException
                    Mock DotNet-GetHostByName {
                        throw $exception
                    }
                }
                elseif($invocationError -eq $true){
                    Mock DotNet-GetHostByName {
                        throw
                    }
                }
                else{
                    Mock DotNet-GetHostByName {
                        return $ipHostEntry
                    }
                }

                $ipAddress, $logData = Get-ServerIpAddress
                $ipAddress | Should -Be $expected
            }
        }

        Context 'Connect-PsSessionCustom' {
            function New-PsSession {
                return $psSession
            }
            $testCases = @(
                @{
                    psSession = $null
                    invocationError = $true
                    expected = $false
                }
                @{
                    psSession = [psCustomObject]@{
                        id = 1
                    }
                    invocationError = $false
                    expected = $true
                }
            )

            It 'ensures PS session status is <expected> for invocation error is <invocationError>' -TestCases $testCases {
                param($psSession, $invocationError, $expected)

                if($invocationError -eq $true){
                    Mock New-PsSession {
                        throw
                    }
                }
                else{
                    Mock New-PsSession {
                        return $psSession
                    }
                }
                
                $psSessionObject, $logData = Connect-PsSessionCustom -ComputerName "test"
                $psSessionObject.psSessionOk | Should -Be $expected
            }

            It 'ensures logData is an arrayList of strings when invocation error state is <invocationError>' -TestCases $testCases[0,3] {
                param ($psSession, $invocationError)

                if($invocationError){
                    Mock New-PsSession {
                        throw
                    }
                }
                else{
                    Mock Invoke-Command {
                        return $psSession
                    }
                }
                
                $psSessionObject, $logData = Get-OSVersionInfo
                ,$logData | Should -BeOfType [System.Collections.ArrayList]
                $logData | Should -BeOfType [string]
            }
        }

        Context 'Get-OSVersionInfo'{
            function Invoke-Command {
                return $osVersionInfo
            }
            $testCases = @(
                @{
                    osWmiObject = [psCustomObject]@{
                        caption = 'Microsoft Windows Server 2012 Standard'
                        version = '6.2.9200'
                        servicePackMajorVersion = 0
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    osWmiObject = [psCustomObject]@{
                        caption = 'Microsoft Windows Server 2008 R2 Standard'
                        version = '6.1.7601'
                        servicePackMajorVersion = 1
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    osWmiObject = [psCustomObject]@{
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
                $osVersionInfo.osCompatible | Should -Be $expected
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
                $psVersionInfo.psCompatible | Should -Be $expected
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
                    dotNetVersion = [psCustomObject]@{
                        version = ([version]"4.7.03190")
                        release = 461814
                    }
                    invocationError = $false
                    expected = $true
                }
                @{
                    dotNetVersion = [psCustomObject]@{
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
            $dotNetVersionInfo.dotNetCompatible | Should -Be $expected
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
                    psVersionInfo = [psCustomObject]@{psVersionMajor = 3}
                    hotfixList = @(
                        [psCustomObject]@{hotfixId = 'KB0000001'},
                        [psCustomObject]@{hotfixId = 'KB0000002'},
                        [psCustomObject]@{hotfixId = 'KB2842230'}
                        )
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersionInfo = [psCustomObject]@{psVersionMajor = 3}
                    hotfixList = @(
                        [psCustomObject]@{hotfixId = 'KB0000001'},
                        [psCustomObject]@{hotfixId = 'KB0000002'}
                        )
                    invocationError = $false
                    expected = $false
                }
                @{
                    psVersionInfo =[psCustomObject]@{psVersionMajor = 5}
                    invocationError = $false
                    expected = $true
                }
                @{
                    psVersionInfo = [psCustomObject]@{psVersionMajor = 3}
                    hotfixList = @(
                        [psCustomObject]@{hotfixId = 'KB0000001'},
                        [psCustomObject]@{hotfixId = 'KB0000002'},
                        [psCustomObject]@{hotfixId = 'KB2842230'}
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
                $winRmHotfixInfo.hotfixStatusOk | Should -Be $expected
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
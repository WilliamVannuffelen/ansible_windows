<#
.SYNOPSIS
Invokes the Ansible prereq checks on target machines. Uses multiple threads.
.DESCRIPTION
Invokes the Ansible prereq checks on target machines. Uses multiple threads.
.PARAMETER serverListFile
A string of the full path of the plain text file containing all target servers to run the checks on.
Default: "$psSscriptRoot\serverListFile.txt"
.PARAMETER logFile
stuff
.PARAMETER domainCredentials
A psCredential object containing the domain credentials to be used for authentication.
.EXAMPLE
#>
[cmdletBinding()]
param(
    [parameter(mandatory=$false)]
    [validateScript({
        if(Test-Path -Path $_ -PathType Leaf){
            return $true
        }
        else{
            throw "The specified serverListFile cannot be found. Please provide a valid path."
        }
    })]
    [string] $serverListFile = "$psScriptRoot/serverListFile.txt",

    [parameter(mandatory=$true)]
    [psCredential] $domainCredentials,

    [parameter(mandatory=$false)]
    [string] $logFile = "$psScriptRoot/logs_$(Get-Date -Format 'yyyy-MM-dd_HHmm').txt"
)

# generate timestamp for logging
function Get-TimeStamp {
    return Get-Date -f "yyyy-MM-dd HH:mm:ss -"
}

# test presence of custom module containing functions to be run on target systems
function Import-AnsibleChecksModule {
    try{
        Import-Module -Name "$psScriptRoot\Get-AnsiblePrereqInfo.psm1"
        "$(Get-Timestamp) INFO: Imported module containing all checks." | Tee-Object -FilePath $logFile -Append | Out-Host
    }
    catch{
        "$(Get-Timestamp) ERROR: Failed to import module containing all checks. Please ensure this file is present in the same location as Invoke-AnsiblePrereqChecks.ps1. The script will now terminate." | Tee-Object -FilePath $logFile -Append | Out-Host
        $_.Exception.Message | Tee-Object -FilePath $logFile -Append | Out-Host
        exit
    }
}

function Import-ServerList {
    try{
        $serverList = Get-Content -Path $serverListFile
        "$(Get-Timestamp) INFO: Imported list of $(($serverList | Measure-Object).count) servers." | Tee-Object -FilePath $logFile -Append | Out-Host
    }
    catch{
        "$(Get-Timestamp) ERROR: Import list of servers. Please provide the correct path or a file exists on the default path. The script will now terminate." | Tee-Object -FilePath $logFile -Append | Out-Host
        $_.Exception.Message | Tee-Object -FilePath $logFile -Append | Out-Host
        exit
    }

    return $serverList
}

function Invoke-Checks {
    [cmdletBinding()]
    param(
        [object[]] $serverList,
        [psCredential] $domainCredentials

    )
    $resultsDict = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::New()
    
    $serverList | ForEach-Object -Parallel {
        Import-Module ".\Get-AnsiblePrereqInfo.psm1"
        function Get-TimeStamp {
            return Get-Date -f "yyyy-MM-dd HH:mm:ss -"
        }

        $startTime = Get-Date
        $computerName = $_
        $domainCredentials = $using:domainCredentials
        $resultsDict = $using:resultsDict

        $logData = [System.Collections.ArrayList]::New()

        # get IP address
        $ipAddress, $logDataEntry = Get-ServerIpAddress -computerName $computerName
        [void]$logData.AddRange($logDataEntry)

        # initiate PS session
        $psSessionObject, $logDataEntry = Connect-PsSessionCustom -computerName $computerName -domainCredentials $domainCredentials
        $psSession = $psSessionObject.psSession
        [void]$logData.AddRange($logDataEntry)

        if($psSession.GetType().name -eq 'psSession'){
            [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Successfully initiated PS session. Proceeding with checks.")
            # get operating system and service pack info
            $osVersionInfo, $logDataEntry = Get-OsVersionInfo -psSession $psSession -computerName $computerName
            [void]$logData.AddRange($logDataEntry)

            # get powershell version info
            $psVersionInfo, $logDataEntry = Get-PsVersionInfo -psSession $psSession -computerName $computerName
            [void]$logData.AddRange($logDataEntry)

            # if powershell 3: check if WinRM memory leak hotfix KB2842230 is installed
            if($psVersionInfo.psVersionMajor -eq 3){
                $winRmHotFixInfo, $logDataEntry = Get-WinRmHotFixInfo -psSession $psSession -computerName $computerName -psVersionInfo $psVersionInfo
                [void]$logData.AddRange($logDataEntry)
            }
            else{
                $winRmHotFixInfo = [psCustomObject]@{
                    hotfixStatusOk = $true
                }
                [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Not PS 3.0 - WinRM hotfix check can be skipped.")
            }

            # get dotnet version info
            $dotNetVersionInfo, $logDataEntry = Get-DotNetVersionInfo -psSession $psSession -computerName $computerName
            [void]$logData.AddRange($logDataEntry)

            $resultObj = [psCustomObject]@{
                computerName = $computerName
                ipAddress = $ipAddress
                psSessionOk = $psSessionObject.psSessionOk
                osVersion = $osVersionInfo.osVersionName
                osSpVersion = $osVersionInfo.osSpVersion
                osCompatible = $osVersionInfo.osCompatible
                psVersion = $psVersionInfo.psVersionSimple
                psCompatible = $psVersionInfo.psCompatible
                winRmHotFixStatusOk = $winRmHotFixInfo.hotfixStatusOk
                dotNetRelease = $dotNetVersionInfo.dotNetRelease
                dotNetCompatible = $dotNetVersionInfo.dotNetCompatible
                logData = $logData
            }
            Remove-PsSession -id $psSession.id
        }
        else{
            [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Unable to establish a PS session. All checks will be skipped.")

            $resultObj = [psCustomObject]@{
                computerName = $computerName
                ipAddress = $ipAddress
                psSessionOk = $false
                osVersion = 'unknown'
                osSpVersion = 'unknown'
                osCompatible = 'unknown'
                psVersion = 'unknown'
                psCompatible = 'unknown'
                winRmHotFixStatusOk = 'unknown'
                dotNetRelease = 'unknown'
                dotNetCompatible = 'unknown'
                logData = $logData
            }
        }
        $endTime = Get-Date
        $timeDelta = $endTime - $startTime
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Checks took $($timeDelta.totalSeconds) seconds to complete.")

        $resultsDict.TryAdd($_, $resultObj)

    }

    return $resultsDict
}


Import-AnsibleChecksModule
$serverList = Import-ServerList
$results = Invoke-Checks -serverList $serverList -domainCredentials $domainCredentials
$results.values.logData | Out-File $logFile -Append
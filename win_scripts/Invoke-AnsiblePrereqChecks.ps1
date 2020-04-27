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
        "$(Get-Timestamp) INFO: Successfully imported module containing all checks." | Tee-Object -FilePath $logFile -Append | Out-Host
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
        class resultObject {
            [string] $computerName
            [string] $ipAddress
            [boolean] $psSessionOk
            [string] $osVersion
            [string] $osSpVersion
            [boolean] $osCompatible
            [string] $psVersion
            [boolean] $psCompatible
            [boolean] $winRmHotfixStatusOk
            [string] $dotNetRelease
            [boolean] $dotNetCompatible
            [system.collections.arrayList] $logData
        }

        function Get-TimeStamp {
            return Get-Date -f "yyyy-MM-dd HH:mm:ss -"
        }

        $startTime = Get-Date
        $computerName = $_
        $domainCredentials = $using:domainCredentials
        $resultsDict = $using:resultsDict

        $logData = [System.Collections.ArrayList]::New()

        try{
            Import-Module ".\Get-AnsiblePrereqInfo.psm1" -ErrorAction Stop
            [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Successfully imported module in runspace.")
        }
        catch{
            [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to import module in runspace. All checks will be skipped.")
            
            $resultObj = New-Object -TypeName resultObject -Property @{
                computerName = $computerName
                logData = $logData
            }
            # populate empty properties with 'unknown' for report formatting
            [void]($resultObj.psObject.properties | Where-Object {$null -eq $_.value}).foreach{$_.value = 'unknown'}

            [void]$resultsDict.TryAdd($computerName, $resultObj)
            continue
        }

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

            $resultObj = New-Object -TypeName resultObject -Property @{
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

            $resultObj = New-Object -TypeName resultObject -Property @{
                computerName = $computerName
                ipAddress = $ipAddress
                psSessionOk = $false
                logData = $logData
            }
            # populate empty properties with 'unknown' for report formatting
            [void]($resultObj.psObject.properties | Where-Object {$null -eq $_.value}).foreach{$_.value = 'unknown'}
        }
        $endTime = Get-Date
        $timeDelta = $endTime - $startTime
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Checks took $($timeDelta.totalSeconds) seconds to complete.")

        [void]$resultsDict.TryAdd($computerName, $resultObj)

    }

    return $resultsDict
}

function New-HtmlReport{
    param(
        $resultObj,
        $reportFile
    )
    "$(Get-Timestamp) INFO: Building HTML report of results." | Tee-Object -FilePath $logFile -Append | Out-Host
    # calculated properties to keep useful data and output in human-readable-friendly format
    $results = $resultObj | 
        Select-Object   @{Name='computerName';          Expression={$_.computerName}},
                        @{Name='ipAddress';             Expression={$_.ipAddress}},
                        @{Name='psSessionOk';           Expression={$_.psSessionOk}},
                        @{Name='osVersion';             Expression={$_.osVersion}},
                        @{Name='servicePackVersion';    Expression={$_.osSpVersion}},
                        @{Name='osCompatible';          Expression={$_.osCompatible}},
                        @{Name='psVersion';             Expression={$_.psVersion}},
                        @{Name='psCompatible';          Expression={$_.psCompatible}},
                        @{Name='winRmHotfixStatusOk';   Expression={$_.winRmHotfixStatusOk}},
                        @{Name='dotNetRelease';         Expression={$_.dotNetRelease}},
                        @{Name='dotNetCompatible';      Expression={$_.dotNetCompatible}}
    
    # HTML framework and CSS for report output
    $htmlParams = @{
        PostContent = "<p class='footer'>Generated on $(get-date -format 'yyyy-MM-dd HH:mm:ss')</p>"
        head = @"
 <Title>Ansible - Windows target system prerequisite checks - $(get-date -format 'yyyy-MM-dd')</Title>
<style>
body { background-color:#E5E4E2;
       font-family:Monospace;
       font-size:11pt; }
table { border-collapse: collapse;}
td, th { padding: 1px 1;
         border:1px solid black; 
         border-collapse:collapse;
         white-space:pre; }
th { font-weight: bold;
     color:white;
     background-color:black; }
table, tr, td, th { padding: 5px; margin: 0px ;white-space:pre; }
tr {
 border: solid;
 border-width: 3px 0;
 }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
h2 {
 font-family:Tahoma;
 color:#6D7B8D;
}
.error {
 background-color: red; 
 }
.success {
 color: green;
 }
.footer 
{ color:green; 
  margin-left:10px; 
  font-family:Tahoma;
  font-size:8pt;
  font-style:italic;
}
</style>
"@
    }

    # convert results array to HTML fragment, cast to XML to dynamically add HTML classes used by CSS
    [xml]$htmlData = $results | ConvertTo-Html -Fragment
    # loop over rows
    for($i=1; $i -le $htmlData.table.tr.count -1; $i++){
        # loop over columns
        for($y = 0; $y -le $htmlData.table.tr[$i].td.count -1; $y++){
            # if column value is $false or 'unknown', append error class for CSS
            if($htmlData.table.tr[$i].td[$y] -eq $false -or $htmlData.table.tr[$i].td[$y] -eq 'unknown'){
                $class = $htmlData.createAttribute("class")
                $class.value = 'error'
                [void]$htmlData.table.tr[$i].childNodes[$y].attributes.append($class)
            }
            # if column value is $true, append success class for CSS
            elseif($htmlData.table.tr[$i].td[$y] -eq $true){
                $class = $htmlData.createAttribute("class")
                $class.value = 'success'
                [void]$htmlData.table.tr[$i].childNodes[$y].attributes.append($class)
            }
        }
    }
    $htmlParams.Add('body', $htmlData.innerXml)
    
    try{
        ConvertTo-Html @htmlParams | Out-File $reportFile -ErrorAction Stop
        "$(Get-Timestamp) INFO: Saved HTML report to $($reportFile)." | Tee-Object -FilePath $logFile -Append | Out-Host
    }
    catch{
        "$(Get-Timestamp) ERROR: Failed to save HTML report." | Tee-Object -FilePath $logFile -Append | Out-Host
        $_.Exception.Message | Tee-Object -FilePath $logFile -Append | Out-Host
    }
}


Import-AnsibleChecksModule
$serverList = Import-ServerList
$results = Invoke-Checks -serverList $serverList -domainCredentials $domainCredentials
$results.values.logData | Out-File $logFile -Append
$results.values | Out-File $logFile -Append

#$reportFile = "$psScriptRoot/Get-AnsiblePrereqInfo_$(Get-Date -Format 'yyyy-MM-dd_HHmm').html"
$reportFile = "/var/www/html/index.nginx-debian.html"

New-HtmlReport -resultObj $results.values -reportFile $reportFile
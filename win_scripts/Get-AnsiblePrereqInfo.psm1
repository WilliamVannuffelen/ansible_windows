function Get-TimeStamp {
    return Get-Date -f "yyyy-MM-dd HH:mm:ss -"
}

function Get-ServerIpAddress{
    [cmdletBinding()]
    param(
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList

    # wrap method in function for unit testing
    function DotNet-GetHostByName ($computerName){
        return [System.Net.Dns]::GetHostByName($computerName)
    }

    try{
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Querying DNS for IP address.")
        $ipHostEntry = DotNet-GetHostByName $computerName
        $ipAddress = ($ipHostEntry.addressList -join ', ')
        [void]$logData.Add("$(Get-TimeStamp) INFO: $computername - Queried DNS for IP address.")
    }
    catch [System.Management.Automation.MethodInvocationException]{
        if($_.exception.errorRecord -match 'Name or service not known"$'){
            $ipAddress = 'unknown'
            [void]$logData.Add("$(Get-TimeStamp) INFO: $computername - Failed to get IP address. FQDN not known in DNS.")
        }
        else{
            $ipAddress = 'unknown'
            [void]$logData.Add("$(Get-TimeStamp) ERROR: $computername - Failed to get IP address")
            [void]$logData.Add($_.exception.message)
        }
    }
    catch{
        $ipAddress = 'unknown'
        [void]$logData.Add("$(Get-TimeStamp) ERROR: $computername - Failed to get IP address")
        [void]$logData.Add($_.exception.message)
    }
    return $ipAddress, $logData
}

function Connect-PsSessionCustom{
    [cmdletBinding()]
    param(
        [string] $computerName,
        [psCredential] $domainCredentials
    )
    $logData = New-Object System.Collections.ArrayList

    try{
        $psSession = New-PsSession -computerName $computerName -Authentication Kerberos -Credential $domainCredentials -ErrorAction Stop
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Started PS session (Kerberos).")
    }
    catch{
        [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to start PS session (Kerberos).")
        [void]$logData.Add($_.Exception.Message)

        $psSessionObject = [psCustomObject]@{
            psSessionOk = $false
            psSession = $false
        }

        return $psSessionObject, $logData
    }

    $psSessionObject = [psCustomObject]@{
        psSessionOk = $true
        psSession = $psSession
    }

    return $psSessionObject, $logData
}

function Get-OSVersionInfo{
    [cmdletBinding()]
    param(
        [object] $psSession,
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList

    try{
        $osWmiObject = Invoke-Command -Session $psSession -ScriptBlock {Get-WMIObject -Class Win32_OperatingSystem -ErrorAction Stop} -ErrorAction Stop
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Queried Win32_OperatingSystem.")
    }
    catch{
        [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to query Win32_OperatingSystem.")
        [void]$logData.Add($_.Exception.Message)

        $osVersionInfo = [psCustomObject]@{
            osVersionName = 'unknown'
            osVersion = 'unknown'
            osSpVersion = 'unknown'
            osCompatible = 'unknown'
        }
        return $osVersionInfo, $logData
    }
    
    $osVersionInfo = $osWmiObject |
        Select-Object   @{Name="osVersionName";       Expression={$_.caption}},
                        @{Name="osVersion";           Expression={$_.version}},
                        @{Name="osSpVersion";         Expression={$_.servicePackMajorVersion}},
                        @{Name="osCompatible";        Expression={
                            # windows server 2008 --> needs SP 2
                            if($_.version.StartsWith('6.0')){
                                switch ($_.servicePackMajorVersion){
                                    {$_ -eq 2} {$true}
                                    default {$false}
                                    }
                                }
                            # windows 7 or server 2008 r2 --> needs SP 1
                            elseif($_.version.StartsWith('6.1')){
                                switch ($_.servicePackMajorVersion){
                                    {$_ -eq 1} {$true}
                                    default {$false}
                                    }
                                }
                            # everything newer: meets requirements
                            else{
                                $true
                                }
                            }}
    return $osVersionInfo, $logData
}

function Get-PSVersionInfo{
    [cmdletBinding()]
    param(
        [object] $psSession,
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList

    try{
        $psVersion = Invoke-Command -Session $psSession -ScriptBlock {$psVersionTable.psVersion} -ErrorAction Stop
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Queried PS version table.")
    }
    catch{
        [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to query PS version table.")
        [void]$logData.Add($_.Exception.Message)

        # if error in query, report
        $psVersionInfo = [psCustomObject]@{
            psVersionSimple = 'unknown'
            psVersionMajor = 'unknown'
            psCompatible = 'unknown'
            }
        return $psVersionInfo, $logData
    }

    # if no error in query, but nothing returned -> PS is outdated
    if($null -eq $psVersion){
        $psVersionInfo = [psCustomObject]@{
            psVersionSimple = '1.0'
            psVersionMajor = 1
            psCompatible = $false
        }
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - psVersionTable does not exist. Outdated Powershell version.")

        return $psVersionInfo, $logData
    }

    $psVersionInfo = $psVersion |
        Select-Object   @{Name="psVersionSimple";     Expression={"$($_.major).$($_.minor)"}},
                        @{Name="psVersionMajor";      Expression={$_.major}},
                        @{Name="psCompatible";         Expression={
                            switch ($_.major){
                                {@(3,4,5) -contains $_} {$true}
                                default {$false}
                            }
                        }}
    [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - psVersionTable exists. Performed standard version check.")
    
    return $psVersionInfo, $logData
}

# check .NET version
function Get-DotNetVersionInfo{
    [cmdletBinding()]
    param(
        [object] $psSession,
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList


    $dotNetRegPath = "HKLM:\Software\Microsoft\Net Framework Setup\NDP\v4\Full"
    $dotNetMinRelease = 379893 # 4.5.2
    try{
        $dotNetVersion = Invoke-Command -Session $psSession -ScriptBlock {Get-ItemProperty -Path $using:dotNetRegPath -ErrorAction Stop} -ErrorAction Stop
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Queried registry for .NET version info.")
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Registry path does not exist, missing or outdated .NET version.")

        $dotNetVersionInfo = [psCustomObject]@{
            dotNetVersion = 'n/a'
            dotNetRelease = 'n/a'
            dotNetCompatible = $false
        }
        return $dotNetVersionInfo, $logData
    }
    catch{
        [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to query registry for .NET version info.")
        [void]$logData.Add($_.Exception.Message)

        $dotNetVersionInfo = [psCustomObject]@{
            dotNetVersion = 'unknown'
            dotNetRelease = 'unknown'
            dotNetCompatible = 'unknown'
        }
        return $dotNetVersionInfo, $logData
    }

    $dotNetVersionInfo = $dotNetVersion |
        Select-Object   @{Name="dotNetVersion";    Expression={$_.version}},
                        @{Name="dotNetRelease";    Expression={$_.release}},
                        @{Name="dotNetCompatible"; Expression={
                            switch ($_.release){
                                {$_ -ge $dotNetMinRelease} {$true}
                                default {$false}
                            }
                        }}

    return $dotNetVersionInfo, $logData
}

# if PS 3.0, check that WinRM memory hotfix KB2842230 is installed
function Get-WinRmHotfixInfo{
    [cmdletBinding()]
    param(
        [object] $psSession,
        [object] $psVersionInfo,
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList
    
    # skip KB check if PS version > 3
    if($psVersionInfo.psVersionMajor -ne 3){
        $winRmHotfixInfo = [psCustomObject]@{
            hotfixRequired   = $false
            hotfixInstalled  = $false
            hotfixStatusOk  = $true
        }
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - PS version is not 3 - skipping KB check.")

        return $winRmHotfixInfo, $logData
    }
    else{
        try{
            $hotfixList = Invoke-Command -Session $psSession -ScriptBlock {Get-CimInstance -ClassName Win32_QuickFixEngineering -ErrorAction Stop} -ErrorAction Stop
            [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - Queried Win32_QuickFixEngineering.")
        }
        catch{
            [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to query Win32_QuickFixEngineering.")
            [void]$logData.Add($_.Exception.Message)

            $winRmHotfixInfo = [psCustomObject]@{
                hotfixRequired = $true
                hotfixInstalled = 'unknown'
                hotfixStatusOk = 'unknown'
            }

            return $winRmHotfixInfo, $logData
        }

        if($hotfixList.hotfixId -contains 'KB2842230'){
            $winRmHotfixInstalled = $true
            $winRmHotfixOk = $true
        }
        else{
            $winRmHotfixInstalled = $false
            $winRmHotfixOk = $false
        }

        $winRmHotfixInfo = [psCustomObject]@{
            hotfixRequired   = $true
            hotfixInstalled  = $winRmHotfixInstalled
            hotfixStatusOk  = $winRmHotfixOk
        }
    }

    return $winRmHotfixInfo, $logData
}

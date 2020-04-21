function Get-TimeStamp {
    return Get-Date -f "yyyy-MM-dd HH:mm:ss -"
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

        $osVersionInfo = [PSCustomObject]@{
            os_version_name = 'unknown'
            os_version = 'unknown'
            os_sp_version = 'unknown'
            os_compatible = 'unknown'
        }
        return $osVersionInfo, $logData
    }
    
    $osVersionInfo = $osWmiObject |
        Select-Object   @{Name="os_version_name";       Expression={$_.caption}},
                        @{Name="os_version";            Expression={$_.version}},
                        @{Name="os_sp_version";         Expression={$_.servicePackMajorVersion}},
                        @{Name="os_compatible";         Expression={
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
        $psVersionInfo = [PSCustomObject]@{
            ps_version_simple = 'unknown'
            ps_version_major = 'unknown'
            ps_compatible = 'unknown'
            }
        return $psVersionInfo, $logData
    }

    # if no error in query, but nothing returned -> PS is outdated
    if($null -eq $psVersion){
        $psVersionInfo = [PSCustomObject]@{
            ps_version_simple = '1.0'
            ps_version_major = 1
            ps_compatible = $false
        }
        [void]$logData.Add("$(Get-Timestamp) INFO: $computerName - psVersionTable does not exist. Outdated Powershell version.")

        return $psVersionInfo, $logData
    }

    $psVersionInfo = $psVersion |
        Select-Object   @{Name="ps_version_simple";     Expression={"$($_.major).$($_.minor)"}},
                        @{Name="ps_version_major";      Expression={$_.major}},
                        @{Name="ps_compatible";         Expression={
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

        $dotNetVersionInfo = [PSCustomObject]@{
            dotnet_version = 'n/a'
            dotnet_release = 'n/a'
            dotnet_compatible = $false
        }
        return $dotNetVersionInfo, $logData
    }
    catch{
        [void]$logData.Add("$(Get-Timestamp) ERROR: $computerName - Failed to query registry for .NET version info.")
        [void]$logData.Add($_.Exception.Message)

        $dotNetVersionInfo = [PSCustomObject]@{
            dotnet_version = 'unknown'
            dotnet_release = 'unknown'
            dotnet_compatible = 'unknown'
        }
        return $dotNetVersionInfo, $logData
    }

    $dotNetVersionInfo = $dotNetVersion |
        Select-Object   @{Name="dotnet_version";    Expression={$_.version}},
                        @{Name="dotnet_release";    Expression={$_.release}},
                        @{Name="dotnet_compatible"; Expression={
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
    if($psVersionInfo.ps_version_major -ne 3){
        $winRmHotfixInfo = [PSCustomObject]@{
            hotfix_required   = $false
            hotfix_installed  = $false
            hotfix_status_ok  = $true
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

            $winRmHotfixInfo = [PSCustomObject]@{
                hotfix_required = $true
                hotfix_installed = 'unknown'
                hotfix_status_ok = 'unknown'
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

        $winRmHotfixInfo = [PSCustomObject]@{
            hotfix_required   = $true
            hotfix_installed  = $winRmHotfixInstalled
            hotfix_status_ok  = $winRmHotfixOk
        }
    }

    return $winRmHotfixInfo, $logData
}

$osVersionInfo, $logData = Get-OSVersionInfo
$psVersionInfo, $logData = Get-PSVersionInfo $psVersion
$dotNetVersionInfo, $logData = Get-DotNetVersionInfo
$winRmHotfixInfo, $logData = Get-WinRMHotfixInfo $psVersionInfo

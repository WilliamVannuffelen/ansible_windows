

function Get-OSVersionInfo{
    [cmdletBinding()]
    param(
        [psSession] $psSession,
        [string] $computerName
    )
    $logData = New-Object System.Collections.ArrayList

    try{
        $osVersionInfo = Invoke-Command -Session $psSession -ScriptBlock {Get-WMIObject -Class Win32_OperatingSystem} -ErrorAction Stop
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
    
    $osVersionInfo = $osVersionInfo |
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



function Get-PSVersion{
    $psVersion = $psVersionTable.psVersion
    return $psVersion
}
# check PS version
function Get-PSVersionInfo($psVersion){
    $psVersionInfo = $psVersion |
    Select-Object   @{Name="ps_version_simple";     Expression={"$($_.major).$($_.minor)"}},
                    @{Name="ps_version_major";      Expression={$_.major}},
                    @{Name="ps_compatible";         Expression={
                        switch ($_.major){
                            {@(3,4,5) -contains $_} {$true}
                            default {$false}
                        }
                    }}
    return $psVersionInfo
}

# check .NET version
function Get-DotNetVersionInfo{
    $dotNetRegPath = "HKLM:\Software\Microsoft\Net Framework Setup\NDP\v4\Full"
    $dotNetMinRelease = 379893 # 4.5.2
    $dotNetRegPathExists = Test-Path -Path $dotNetRegPath

    if(-not $dotNetRegPathExists){
        $dotNetVersionInfo = [PSCustomObject]@{
            "dotnet_version" = "n/a"
            "dotnet_release" = "n/a"
            "dotnet_compatible" = $false
        }
    }
    else{
        $dotNetVersionInfo = Get-ItemProperty -Path $dotNetRegPath

        $dotNetVersionInfo = $dotNetVersionInfo |
            Select-Object   @{Name="dotnet_version";    Expression={$_.version}},
                            @{Name="dotnet_release";    Expression={$_.release}},
                            @{Name="dotnet_compatible"; Expression={
                                switch ($_.release){
                                    {$_ -ge $dotNetMinRelease} {$true}
                                    default {$false}
                                }
                            }}
    }
    return $dotNetVersionInfo
}

# if PS 3.0, check that WinRM memory hotfix KB2842230 is installed
function Get-WinRMHotfixInfo($psVersionInfo){
    # skip KB check if PS version > 3
    if($psVersionInfo.ps_version_major -ne 3){
        $winRmHotfixInfo = [PSCustomObject]@{
            'hotfix_required'   = $false
            'hotfix_installed'  = $false
            'hotfix_status_ok'  = $true
        }
    }
    else{
        $winRmHotfix = Get-Hotfix -HotfixId "KB2842230" -ErrorAction SilentlyContinue

        if($null -eq $winRmHotfix){
            $winRmHotfixInstalled = $false
            $winRmHotfixStatus = $false
        }
        else{
            $winRmHotfixInstalled = $true
            $winRmHotfixStatus = $true
        }

        $winRmHotfixInfo = [PSCustomObject]@{
            'hotfix_required'   = $true
            'hotfix_installed'  = $winRmHotfixInstalled
            'hotfix_status_ok'  = $winRmHotfixStatus
        }
    }

    return $winRmHotfixInfo
}

$osVersionInfo, $logData = Get-OSVersionInfo
$psVersion = Get-PSVersion
$psVersionInfo = Get-PSVersionInfo $psVersion
$dotNetVersionInfo = Get-DotNetVersionInfo
$winRmHotfixInfo = Get-WinRMHotfixInfo $psVersionInfo

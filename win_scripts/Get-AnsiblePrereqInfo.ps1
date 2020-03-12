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

# if PS 3.0, check WinRM memory hotfix KB2842230
function Get-WinRMHotfixStatus($psVersionInfo){
    # skip if PS version > 3
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

$psVersion = Get-PSVersion
$psVersionInfo = Get-PSVersionInfo $psVersion
$dotNetVersionInfo = Get-DotNetVersionInfo
#$winrmhotfixinfo = get-winrmhotfixstatus $psversioninfo

write-host "test"
# check PS version
function Get-PSVersionInfo{
    $psVersionInfo = $psVersionTable |
    Select-Object   @{Name="ps_version_simple";     Expression={"$($_.psVersion.major).$($_.psVersion.minor)"}},
                    @{Name="ps_version_major";      Expression={$_.psVersion.major}},
                    @{Name="ps_compatible";         Expression={
                        switch ($_.psVersion.major){
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
    if(-not (Test-Path -Path $dotNetRegPath)){
        $dotNetVersionInfo = [PSCustomObject]@{
            "dotnet_version" = "n/a"
            "dotnet_release" = "n/a"
            "dotnet_compatible" = $false
        }
    }
    else{
        $dotNetVersionInfo = Get-ItemProperty -Path $dotNetRegPath | 
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

# if PS 3.0, check WinRM memory hotfix
function Get-WinRMHotfixStatus($psVersionInfo){
    
}
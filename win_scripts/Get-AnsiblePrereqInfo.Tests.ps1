$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe 'Get-AnsiblePrereqInfo'{
    Context 'Get-PSVersionInfo'{
        It 'should not be null'{
            $psVersionInfo | Should -Not -Be $null
        }
        It 'should contain major version'{
            $psVersionInfo.ps_version_major | Should -BeOfType [Int32]
        }
        It 'should be assessed for compatibility'{
            $psVersionInfo.ps_compatible | Should -BeOfType [Bool]
        }
    }
    Context 'Get-DotNetVersionInfo'{
        It 'should not be null'{
            $dotNetVersionInfo | Should -Not -Be $null
        }
        It 'should contain .NET release number'{
            $dotNetVersionInfo.dotnet_release | Should -Not -Be $null
        }
        It 'should be assessed for compatibility'{
            $dotNetVersionInfo.dotnet_compatible | Should -BeOfType [Bool]
        }
    }
    #Context 'Get-WinRMHotfixStatus'{
    #}
}
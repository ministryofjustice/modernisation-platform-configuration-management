# Configure the PowerShell DSC Local Configuration Manager
# See https://learn.microsoft.com/en-us/powershell/dsc/managing-nodes/metaconfig?view=dsc-1.1
[DSCLocalConfigurationManager()]
configuration LCMConfig
{
    Node localhost
    {
        Settings
        {
            RefreshMode = 'Push'
            ActionAfterReboot = 'StopConfiguration'
            RebootNodeIfNeeded = $true
        }
    }
}

if (! (Test-Path "C:\temp")) {
    mkdir C:\temp
}
cd C:\temp
LCMConfig -OutputPath mofs

Set-DscLocalConfigurationManager -Path .\mofs 

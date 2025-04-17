function Add-PermanentPSModulePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )
  
    # Get current Machine PSModulePath from the registry
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    $currentValue = (Get-ItemProperty -Path $regKey -Name PSModulePath).PSModulePath
  
    # Check if the path already exists
    if ($currentValue -split ';' -notcontains $NewPath) {
        # Add the new path
        $newValue = $currentValue + ";" + $NewPath
  
        # Update the registry
        Set-ItemProperty -Path $regKey -Name PSModulePath -Value $newValue
  
        Write-Host "Added $NewPath to system PSModulePath. Changes will take effect after restart or refreshing environment variables."
    }
    else {
        Write-Host "$NewPath is already in PSModulePath"
    }
}

# Add modules permanently to PSModulePath
$ModulesPath = Join-Path $PSScriptRoot "..\..\Modules"
Add-PermanentPSModulePath -NewPath $ModulesPath
# Add to system environment (persistent)
[Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath + ";" + $ModulesPath, "Machine")
# Also add to current session
$env:PSModulePath = $env:PSModulePath + ";" + $ModulesPath

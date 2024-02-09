<#
.SYNOPSIS
    Wrapper script for creating module manifest 

.DESCRIPTION
    Automatically detect files and exported functions and create
    associated manifest file.

.PARAMETER ModuleName
    String

.PARAMETER ModuleVersion
    String

.PARAMETER Description
    String

.EXAMPLE
    Create-ModPlatformModuleManifest.ps1 "ModPlatformAD" 
#>

param (
  [Parameter(Mandatory=$true)][string]$ModuleName,
  $ModuleVersion,
  $Description
)

$ManifestParameters = @{
  "GUID" = New-Guid
  "ModuleVersion" = "1.0.0.0"
  "Author" = "Ministry of Justice"
  "CompanyName" = "Ministry of Justice"
  "Copyright" = "(c) 2024 Crown Copyright (Ministry of Justice)"
  "Description" = "Modernisation Platform ${ModuleName} module"
  "PowerShellVersion" = $PSVersionTable.PSVersion.ToString()
}

$ErrorActionPreference = "Stop"

$ManifestPath = "${ModuleName}/${ModuleName}.psd1"

# Overwrite default manifest parameters with existing values with incremented version
if ((Get-ChildItem $ManifestPath -ErrorAction SilentlyContinue) -ne $null) {
  $ManifestParameters.Keys.Clone() | ForEach-Object {
    $ExistingValue = (Select-String -Path $ManifestPath -Pattern "${_} = '" -Raw).Split("'")[1]
    if ($ExistingValue -ne $null) {
      if ($_ -eq "ModuleVersion") {
        # increment existing version number 
        $Version = [version]$ExistingValue
        $Number = $Version.Major*1000+$Version.Minor*100+$Version.Build*10+$Version.Revision+1
        $Revision = $Number % 10
        $Build = (($Number-$Revision)/10)%10
        $Minor = (($Number-$Revision-$Build*10)/100)%10
        $Major = ($Number-$Revision-$Build*10-$Minor*100)/1000
        $ManifestParameters[$_] = "${Major}.${Minor}.${Build}.${Revision}"    
      } else {
        $ManifestParameters[$_] = $ExistingValue
      }
    }
  } 
}

if ($ModuleVersion -ne $null) {
  $Version = [version]$ModuleVersion
  if ($Version.Revision -gt 9 -or $Version.Build -gt 9 -or $Version.Minor -gt 9) {
    Write-Error "Invalid version - revision/build/minor must not exceed 9"
  }
  $ManifestParameters["ModuleVersion"] = $ModuleVersion
} 
if ($Description -ne $null) {
  $ManifestParameters["Description"] = $Description
}

# Automatically detect functions to export
$ModuleFiles = Get-ChildItem "${ModuleName}/*.psm1" -Name
$FunctionsToExport = Select-String -Path "${ModuleName}/*.psm1" -Pattern 'Export-ModuleMember' | Select-String -Pattern "Function \w" -Raw | foreach { $_.Split(" ")[-1] }

$ManifestParameters["Path"] = $ManifestPath
$ManifestParameters["NestedModules"] = $ModuleFiles
$ManifestParameters["FunctionsToExport"] = $FunctionsToExport

Write-Output $ManifestParameters
New-ModuleManifest @ManifestParameters

function Get-ModPlatformRDLicensingCompanyInformation() {
<#
.SYNOPSIS
    Return hashtable with RD Licensing company information

.OUTPUTS
    hashtable
#>
  [CmdletBinding()]
  param ()

  $ErrorActionPreference = "Stop"

  $CompanyInformation = @{
    "FirstName" = "Modernisation"
    "LastName" = "Platform"
    "Company" = "Ministry of Justice"
    "CountryRegion" = "United Kingdom"
  }
  $CompanyInformation
}

function Add-ModPlatformRDLicensingActivation() {
<#
.SYNOPSIS
    Activate RDLicensing server if it isn't already activated

.PARAMETER CompanyInformation
    HashTable containing company information to set

.EXAMPLE
    Add-ModPlatformRDLicensingActivation (Get-ModPlatformRDLicensingCompanyInformation)
#>
  [CmdletBinding()]
  param (
    [hashtable]$CompanyInformation
  )

  $ErrorActionPreference = "Stop"
  $LicenseServerWMIObject = Get-WMIObject Win32_TSLicenseServer
  $LicenseServerWMIClass = [wmiclass]($LicenseServerWMIObject.__PATH.Split("=")[0])
  if ($LicenseServerWMIClass.GetActivationStatus().ActivationStatus -ne 0) {
    if ($CompanyInformation) {
      $CompanyInformation.Keys | ForEach-Object {
        $LicenseServerWMIObject[$_] = $CompanyInformation[$_]
      }
      $LicenseServerWMIObjectPut = $LicenseServerWMIObject.Put()
    }
    $Activated = $LicenseServerWMIClass.ActivateServerAutomatic()
  }
}

function Remove-ModPlatformRDLicensingActivation() {
<#
.SYNOPSIS
    De-activate RDLicensing server if it isn't already de-activated

.EXAMPLE
    Remove-ModPlatformRDLicensingActivation
#>
  [CmdletBinding()]
  param ()

  $ErrorActionPreference = "Stop"
  $LicenseServerWMIObject = Get-WMIObject Win32_TSLicenseServer
  $LicenseServerWMIClass = [wmiclass]($LicenseServerWMIObject.__PATH.Split("=")[0])
  if ($LicenseServerWMIClass.GetActivationStatus().ActivationStatus -eq 0) {
    $Deactivated = $LicenseServerWMIClass.DeactivateServerAutomatic()
  }
}

Export-ModuleMember -Function Get-ModPlatformRDLicensingCompanyInformation
Export-ModuleMember -Function Add-ModPlatformRDLicensingActivation
Export-ModuleMember -Function Remove-ModPlatformRDLicensingActivation

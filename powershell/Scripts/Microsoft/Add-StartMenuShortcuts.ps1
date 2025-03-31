<#
.SYNOPSIS
    Configure StartMenu short cuts

.DESCRIPTION
    Add and/or remove short cuts from the common start menu

    All environment specific configurations must be defined in the
    below $Configs variable. This is a hashtable where the
    key is the ConfigName and the value is a hashtable of options:
    - Remove -> CommonStartMenu: list of items to remove
    - Add    -> CommonStartMenu: hashtable of items to add where
                the key is the name of the item and the value is
                the URL.
                Don't use more than 1 directory in the item name
                as Windows doesn't support.

.PARAMETER ConfigName
    Optionally provide the name of the config to apply instead
    of deriving from the EC2's environment-name tag value.

.EXAMPLE
    Add-StartMenuShortcuts.ps1
    Add-StartMenuShortcuts.ps1 -ConfigName hmpps-domain-services-test
#>

[CmdletBinding()]
param (
  [string]$ConfigName
)

$Configs = @{
  "hmpps-domain-services-development" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
        "Prison-Nomis"
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "Prison-Nomis/DEV"      = "https://c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/QA11G"    = "https://c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/QA11R"    = "https://c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/WEB19C-B" = "https://dev-nomis-web19c-b.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      }
    }
  }
  "hmpps-domain-services-test" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
        "OASys",
        "OASys-National-Reporting",
        "OASys National Reporting",
        "Prison-Nomis",
        "Prison-Nomis-AB-Testing",
        "Prison-Nomis AB Testing",
        "Prison-Nomis-Reporting",
        "Prison-Nomis Reporting"
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "OASys/T1" = "https://t1-int.oasys.service.justice.gov.uk"
        "OASys/T2" = "https://t2-int.oasys.service.justice.gov.uk"
        "OASys National Reporting/T2 Reporting CMC"        = "https://t2.test.reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/T2 Reporting BI"         = "https://t2.test.reporting.oasys.service.justice.gov.uk/BOE/BI"
        "OASys National Reporting/T2 Reporting AdminTools" = "https://t2.test.reporting.oasys.service.justice.gov.uk/AdminTools"
        "OASys National Reporting/T2 BODS CMC"             = "https://t2-bods.test.reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/T2 BODS DataServices"    = "https://t2-bods.test.reporting.oasys.service.justice.gov.uk/DataServices/"
        "Prison-Nomis/T1" = "https://c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/T2" = "https://c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/T3" = "https://c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t1-nomis-web-a" = "https://t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t1-nomis-web-b" = "https://t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t2-nomis-web-a" = "https://t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t2-nomis-web-b" = "https://t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t3-nomis-web-a" = "https://t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t3-nomis-web-b" = "https://t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis Reporting/T1 Reporting CMC"        = "https://t1.test.reporting.nomis.service.justice.gov.uk/BOE/CMC"
        "Prison-Nomis Reporting/T1 Reporting BI"         = "https://t1.test.reporting.nomis.service.justice.gov.uk/BOE/BI"
        "Prison-Nomis Reporting/T1 Reporting AdminTools" = "https://t1.test.reporting.nomis.service.justice.gov.uk/AdminTools"
      }
    }
  }
  "hmpps-domain-services-preproduction" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
        "CSR",
        "OASys",
        "OASys-National-Reporting",
        "OASys National Reporting",
        "Prison-Nomis",
        "Prison-Nomis-AB-Testing",
        "Prison-Nomis AB Testing",
        "Prison-Nomis-Reporting",
        "Prison-Nomis Reporting"
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "CSR/PreProd Region 1 2" = "http://r1.pp.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "CSR/PreProd Region 3 4" = "http://r3.pp.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "CSR/PreProd Region 5 6" = "http://r5.pp.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "CSR/Prod Training A B"  = "http://traina.csr.service.justice.gov.uk/isps/index.html?2057"
        "OASys/PreProd"          = "https://pp-int.oasys.service.justice.gov.uk"
        "OASys National Reporting/PreProd Reporting CMC"        = "https://preproduction.reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/PreProd Reporting BI"         = "https://preproduction.reporting.oasys.service.justice.gov.uk/BOE/BI"
        "OASys National Reporting/PreProd Reporting AdminTools" = "https://preproduction.reporting.oasys.service.justice.gov.uk/AdminTools"
        "OASys National Reporting/PreProd BODS CMC"             = "https://pp-bods.test.reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/PreProd BODS DataServices"    = "https://pp-bods.test.reporting.oasys.service.justice.gov.uk/DataServices/"
        "PlanetFM/PreProd Web Portal"                           = "https://cafmwebx.pp.planetfm.service.justice.gov.uk/PlanetPortal"
        "PlanetFM/PreProd Remote Desktop"                       = "https://cafmtx.pp.planetfm.service.justice.gov.uk/RDWeb"
        "Prison-Nomis/LSAST"                          = "https://c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/PreProd"                        = "https://c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/lsast-nomis-web-a"   = "https://lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/lsast-nomis-web-b"   = "https://lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/preprod-nomis-web-a" = "https://preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/preprod-nomis-web-b" = "https://preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis Reporting/PreProd Reporting CMC"        = "https://admin.preproduction.reporting.nomis.service.justice.gov.uk/BOE/CMC"
        "Prison-Nomis Reporting/PreProd Reporting BI"         = "https://preproduction.reporting.nomis.service.justice.gov.uk/BOE/BI"
        "Prison-Nomis Reporting/PreProd Reporting AdminTools" = "https://admin.preproduction.reporting.nomis.service.justice.gov.uk/AdminTools"
      }
    }
  }
  "hmpps-domain-services-production" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
        "CSR",
        "OASys",
        "OASys-National-Reporting",
        "OASys National Reporting",
        "Prison-Nomis",
        "Prison-Nomis-AB-Testing",
        "Prison-Nomis AB Testing",
        "Prison-Nomis-Reporting",
        "Prison-Nomis Reporting"
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "CSR/Prod Region 1 2" = "http://r1.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "CSR/Prod Region 3 4" = "http://r3.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "CSR/Prod Region 5 6" = "http://r5.csr.service.justice.gov.uk:7770/isps/index.html?2057"
        "OASys/Prod"     = "https://int.oasys.service.justice.gov.uk/eor/f?p=100"
        "OASys/Practice" = "https://practice.int.oasys.service.justice.gov.uk/eor/f?p=100"
        "OASys/Training" = "https://training.int.oasys.service.justice.gov.uk/eor/f?p=100"
        "OASys National Reporting/Prod Reporting CMC"        = "https://reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/Prod Reporting BI"         = "https://reporting.oasys.service.justice.gov.uk/BOE/BI"
        "OASys National Reporting/Prod Reporting AdminTools" = "https://reporting.oasys.service.justice.gov.uk/AdminTools"
        "OASys National Reporting/Prod BODS CMC"             = "https://bods.reporting.oasys.service.justice.gov.uk/BOE/CMC"
        "OASys National Reporting/Prod BODS DataServices"    = "https://bods.reporting.oasys.service.justice.gov.uk/DataServices/"
        "PlanetFM/Prod Web Portal"     = "https://cafmwebx2.planetfm.service.justice.gov.uk/PlanetPortal"
        "PlanetFM/Prod Remote Desktop" = "https://cafmtx.planetfm.service.justice.gov.uk/RDWeb"
        "PlanetFM/Training Web Portal" = "https://cafmtrainweb.planetfm.service.justice.gov.uk/PlanetPortal"
        "Prison-Nomis/Prod" = "https://c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/prod-nomis-web-a" = "https://prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/prod-nomis-web-b" = "https://prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis Reporting/Prod Reporting CMC"        = "https://admin.reporting.nomis.service.justice.gov.uk/BOE/CMC"
        "Prison-Nomis Reporting/Prod Reporting BI"         = "https://reporting.nomis.service.justice.gov.uk/BOE/BI"
        "Prison-Nomis Reporting/Prod Reporting AdminTools" = "https://admin.reporting.nomis.service.justice.gov.uk/AdminTools"
      }
    }
  }
  "nomis-development" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "Prison-Nomis/DEV"      = "https://c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/QA11G"    = "https://c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/QA11R"    = "https://c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/WEB19C-B" = "https://dev-nomis-web19c-b.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      }
    }
  }
  "nomis-test" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "Prison-Nomis/T1" = "https://c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/T2" = "https://c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/T3" = "https://c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t1-nomis-web-a" = "https://t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t1-nomis-web-b" = "https://t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t2-nomis-web-a" = "https://t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t2-nomis-web-b" = "https://t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t3-nomis-web-a" = "https://t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/t3-nomis-web-b" = "https://t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      }
    }
  }
  "nomis-preproduction" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "Prison-Nomis/LSAST"                          = "https://c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis/PreProd"                        = "https://c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/lsast-nomis-web-a"   = "https://lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/lsast-nomis-web-b"   = "https://lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/preprod-nomis-web-a" = "https://preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/preprod-nomis-web-b" = "https://preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      }
    }
  }
  "nomis-production" = @{
    "Remove" = @{
      "CommonStartMenu" = @(
      )
    }
    "Add" = @{
      "CommonStartMenu" = @{
        "Prison-Nomis/Prod" = "https://c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/prod-nomis-web-a" = "https://prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
        "Prison-Nomis AB Testing/prod-nomis-web-b" = "https://prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      }
    }
  }
}

function Get-ConfigNameByEnvironmentNameTag {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  if ($Configs.Contains($EnvironmentNameTag)) {
    Return $EnvironmentNameTag
  } else {
    Write-Error "Unsupported environment-name tag value $EnvironmentNameTag"
    Return $null
  }
}


$ErrorActionPreference = "Stop"

if (-not $ConfigName) {
  $ConfigName = Get-ConfigNameByEnvironmentNameTag
}
if (-not $Configs.Contains($ConfigName)) {
  Write-Error "Unsupported ConfigName $ConfigName"
}
$Config = $Configs[$ConfigName]

if ($Config.Contains("Remove")) {
  foreach ($Folder in $Config["Remove"].GetEnumerator()) {
    $BasePath = [environment]::GetFolderPath($Folder.Key)
    foreach ($ShortcutName in $Folder.Value) {
      $ShortcutPath = Join-Path -Path $BasePath -ChildPath $ShortcutName
      Remove-Item -Path $ShortcutPath -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
      #foreach ($Item in (Get-ChildItem "${ShortcutPath}*" -Recurse)) {
      #  Write-Output "Removing $Item"
      #  Remove-Item $Item -Force -Recurse | Out-Null
      #}
      #foreach ($Item in (Get-ChildItem "${ShortcutPath}*" -Directory)) {
      #  Write-Output "Removing $Item"
      #  Remove-Item $Item -Force -Recurse | Out-Null
      #}
    }
  }
}

if ($Config.Contains("Add")) {
  foreach ($Folder in $Config["Add"].GetEnumerator()) {
    $BasePath = [environment]::GetFolderPath($Folder.Key)
    foreach ($Item in $Folder.Value.GetEnumerator()) {
      $ShortcutName = $Item.Key
      $ShortcutUrl  = $Item.Value
      $ShortcutPath = Join-Path -Path $BasePath -ChildPath ($ShortcutName + ".url")
      $ShortcutDir = Split-Path -Path $ShortcutPath -Parent
      if (!(Test-Path -Path $ShortcutDir)) {
        Write-Output "Creating $ShortcutDir"
        New-Item -Path $ShortcutDir -ItemType Directory -Force | Out-Null
      }
      Write-Output "Setting $ShortcutPath = $ShortcutUrl"
      $Shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath)
      $Shortcut.TargetPath = $ShortcutUrl
      $Shortcut.Save()
    }
  }
}

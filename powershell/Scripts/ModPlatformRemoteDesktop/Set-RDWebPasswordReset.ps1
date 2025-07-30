<#
.SYNOPSIS
    Enable password reset and login page link for Remote Desktop Web

.DESCRIPTION
    Enable password reset page on RDWeb
    Add link to password reset page from login page
#>

function Set-RDWebPasswordChangeEnabled {
  $WebConfigPath = 'C:\Windows\Web\RDWeb\Pages\Web.config'
  if (!(Test-Path $WebConfigPath)) {
    Write-Error "RDWeb not installed: $WebConfigPath"
  } else {
    $WebConfig = Get-Content -Path $WebConfigPath

    if ($WebConfig -match '("PasswordChangeEnabled".*value=)"true"') {
      Write-Verbose "PasswordChangeEnabled already set to true in $WebConfigPath"
    } elseif ($WebConfig -match '("PasswordChangeEnabled".*value=)"false"') {
      Write-Output "Setting PasswordChangeEnabled=true in $WebConfigPath and restarting Site"
      $WebConfig -replace '("PasswordChangeEnabled".*value=)"false"', '$1"true"' | Set-Content -Path $WebConfigPath
      Import-Module IISAdministration
      $site = Get-IISSite "Default Web Site"
      if ($WhatIfPreference) {
        Write-Output "What-If: Restarting IIS Default Web Site"
      } else {
        $site.Stop()
        $site.Start()
      }
    } else {
      Write-Error "Cannot find PasswordChangeEnabled option in $WebConfigPath"
    }
  }
}

function Set-RDWebPasswordChangeLoginLink {
  $LoginAspxPath = 'C:\Windows\Web\RDWeb\Pages\en-US\login.aspx'
  if (!(Test-Path $LoginAspxPath)) {
    Write-Error "RDWeb not installed: $LoginAspxPath"
  } else {
    $LoginAspx = Get-Content -Raw -Path $LoginAspxPath
    $LoginAspxMatch = '(<label><input id="UserPass".*name="UserPass".*type="password".*/>.*</label>.*\r\n.*</td>.*\r\n.*</tr>.*\r\n.*</table>.*\r\n.*</td>.*\r\n.*</tr>.*\r\n)'
    $LoginAspxWhitespace = '            '
    $LoginAspxAdd='<tr><td align="right">Click <a href="password.aspx">here</a> to reset your password.</td></tr>'
    if ($LoginAspx -match $LoginAspxAdd) {
      Write-Verbose "Password link already added to $LoginAspxPath"
    } elseif ($LoginAspx -match $LoginAspxMatch) {
      Write-Output "Adding password link to $LoginAspxPath"
      $LoginAspx -replace $LoginAspxMatch, ('$1'+$LoginAspxWhitespace+$LoginAspxAdd) | Set-Content -Path $LoginAspxPath
    } else {
      Write-Error "Cannot find where to add password link in $LoginAspxPath"
    }
  }
}

Set-RDWebPasswordChangeEnabled
Set-RDWebPasswordChangeLoginLink

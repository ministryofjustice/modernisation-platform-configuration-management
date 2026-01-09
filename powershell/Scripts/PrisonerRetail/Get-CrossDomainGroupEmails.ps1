<#
.SYNOPSIS
    Lists UPNs for members of domain local security groups where those users are in a trusted accounts domain

.PARAMETER Groups (optional, does a full run of ~117 groups by default, see example for limited, quicker testing)
    An array of group objects or group names, we build a default using name filters to serve our use case

.PARAMETER ResourceDomain
    The resource domain name, the group(s) being the resource (optional, uses local domain if not specified)

.PARAMETER AccountsDomain (optional, uses dom1.infra.int domain if not specified)
    The accounts domain name where the native user accounts reside

.PARAMETER Credential
    Credentials for querying the accounts domain (optional, will prompt if not provided)

.EXAMPLE 1
    # Save your creds to a parameter to avoid multiple prompts when performing multiple runs
    $DomainUsername = "wyc76d" #your dom1 username
    $DomainPasswordSecureString = ConvertTo-SecureString -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ($DomainUsername, $DomainPasswordSecureString)

    # To Test Credentials
    Get-ADUser -Filter {UserPrincipalName -like "Dave.Kent@justice.gov.uk"} -Server "dom1.infra.int" -ResultSetSize 1 -Credential $Cred

    #To test with 3 matching groups
    $groups = (Get-ADGroup -Filter "Name -like 'PRWe*' -and Name -notlike 'Print*' -and Name -notlike 'Pre-*' -and Name -notlike 'PROD*' -and Name -ne 'PRSupportAdmins'-and Name -ne 'PrisonNOMISDistri' -and Name -ne 'Protected Users'" -Properties Members)
    Write-Host "Number of groups matching filter: $($groups.count)"
    .\Get-CrossDomainGroupEmails.ps1 -Groups $groups -AccountsDomain "dom1.infra.int" -Credential $Cred

.EXAMPLE 2
    # Run with no parameters for a full defualt run (takes a few mins ~117 groups in scope)

    .\Get-CrossDomainGroupEmails.ps1
    
#>

param(
    [Parameter(Mandatory=$false)]
    [object[]]$Groups = (Get-ADGroup -Filter "Name -like 'PRWe*' -and Name -notlike 'Print*' -and Name -notlike 'Pre-*' -and Name -notlike 'PROD*' -and Name -ne 'PRSupportAdmins'-and Name -ne 'PrisonNOMISDistri' -and Name -ne 'Protected Users'" -Properties Members),
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceDomain,
    
    [Parameter(Mandatory=$false)]
    [string]$AccountsDomain = "dom1.infra.int",
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not $ResourceDomain) {
    $ResourceDomain = (Get-ADDomain).DNSRoot
}

if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter credentials for $AccountsDomain"
}

$allUpns = @()

foreach ($groupItem in $Groups) {
    try {
        # Handle both group objects and group names
        if ($groupItem -is [string]) {
            $groupName = $groupItem
            $group = Get-ADObject -Filter {Name -eq $groupName} -Server $ResourceDomain -Properties member -ErrorAction Stop
        } else {
            $groupName = $groupItem.Name
            $group = Get-ADObject -Identity $groupItem.DistinguishedName -Server $ResourceDomain -Properties member -ErrorAction Stop
        }
        
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host "Processing group: $groupName"    -ForegroundColor Cyan
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host "Members in group: $($group.member.Count)" -ForegroundColor Gray
        Write-Host ""
        
        if ($group.member.Count -eq 0) {
            Write-Warning "No members found in group: $groupName"
            Write-Host ""
            continue
        }
        
        foreach ($memberDN in $group.member) {
            Write-Host "Processing DN: $memberDN" -ForegroundColor Gray
            
            try {
                $member = Get-ADObject -Identity $memberDN -Server $ResourceDomain -Properties Name -ErrorAction Stop
                
                $sidString = $member.Name
                #Write-Host "  SID: $sidString" -ForegroundColor Gray
                
                $sid = New-Object System.Security.Principal.SecurityIdentifier($sidString)
                $ntAccount = $sid.Translate([System.Security.Principal.NTAccount])
                $accountName = $ntAccount.Value
                
                Write-Host "  Translated to: $accountName" -ForegroundColor Gray
                
                $parts = $accountName.Split([char]92)
                $username = $parts[1]
                
                #Write-Host "  Username: $username" -ForegroundColor Gray
                #Write-Host "  Querying accounts domain..." -ForegroundColor Gray
                $filterScript = [ScriptBlock]::Create("SamAccountName -eq `"$username`"")
                $user = Get-ADUser -Filter $filterScript -Server $AccountsDomain -Credential $Credential -Properties UserPrincipalName -ErrorAction Stop
                
                #Write-Host "  User object returned: $($user -ne $null)" -ForegroundColor Gray
                if ($user) {
                    #Write-Host "  User SamAccountName: $($user.SamAccountName)" -ForegroundColor Gray
                    #Write-Host "  User UPN: $($user.UserPrincipalName)" -ForegroundColor Gray
                }
                
                if ($user -and $user.UserPrincipalName) {
                    $allUpns += $user.UserPrincipalName
                    Write-Host "  [OK] UPN: $($user.UserPrincipalName)" -ForegroundColor Green
                } else {
                    Write-Warning "  No user found or no UPN for: $username"
                }
            }
            catch {
                Write-Warning "  Error: $($_.Exception.Message)"
            }
        }
        
        Write-Host ""
        
    }
    catch {
        Write-Error "Error processing group ${groupName}: $($_.Exception.Message)"
        Write-Host ""
    }
}

Write-Host "================================" -ForegroundColor Green
Write-Host "Combined UPN List (All Groups)"   -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

$uniqueUpns = $allUpns | Select-Object -Unique | Sort-Object
#$uniqueUpns | ForEach-Object { Write-Output $_ }

Write-Host ""
Write-Host "Total unique UPNs found: $($uniqueUpns.Count)" -ForegroundColor Cyan

# Export to file
$filePath = "GroupUPNs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
#$uniqueUpns | ForEach-Object { [PSCustomObject]@{ UserPrincipalName = $_ } } | Export-Csv -Path $filePath -NoTypeInformation
$uniqueUpns | Out-File -FilePath $filePath -Encoding UTF8
Write-Host ""
Write-Host "Exported to: $filePath" -ForegroundColor Green
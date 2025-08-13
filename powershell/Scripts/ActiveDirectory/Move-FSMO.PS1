# FSMO Role Transfer Script with Error Handling and Sequential Processing

# FSMO Role Descriptions
# Role                    Scope           Function
# PDC Emulator            Domain          Time sync, password changes, account lockouts
# RID Master              Domain          Allocates RID pools to domain controllers
# Infrastructure Master   Domain          Updates cross-domain object references
# Domain Naming Master    Forest          Controls domain additions/removals
# Schema Master           Forest          Controls schema modifications


# Check replication status
# repadmin /showrepl
# repadmin /showrepl * /csv | convertfrom-csv | out-gridview
# repadmin /replsummary


# Display where the roles are currently located (PS truncates the output so just use netdom!)
# netdom query fsmo

# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole PDCEmulator
# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole RIDMaster
# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole InfrastructureMaster
# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole DomainNamingMaster
# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole SchemaMaster

# Move all FSMO roles to one server in one go with a Force (not your best first option!)
# Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole PDCEmulator,RIDMaster,InfrastructureMaster,DomainNamingMaster,SchemaMaster -Force


$NewDCName = "ad-azure-dc-a"  # Replace with your target DC name

$FSMORoles = @(
    "PDCEmulator",
    "RIDMaster",
    "InfrastructureMaster",
    "DomainNamingMaster",
    "SchemaMaster"
)

function Verify-FSMORole {
    param (
        [string]$DCName,
        [string]$RoleName
    )
    
    try {
        Start-Sleep -Seconds 5  # Allow time for replication
        $currentHolder = Get-ADDomainController -Filter * | Where-Object { $_.OperationMasterRoles -contains $RoleName }
        
        if ($currentHolder.Name -eq $DCName) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-Error "Failed to verify role $RoleName : $($_.Exception.Message)"
        return $false
    }
}

# Pre-transfer checks
Write-Host "Pre-Transfer Checks" -ForegroundColor Cyan
Write-Host "Target DC: $NewDCName" -ForegroundColor Green

# Verify target DC exists and is reachable
try {
    $targetDC = Get-ADDomainController -Identity $NewDCName -ErrorAction Stop
    Write-Host "[+] Target DC found: $($targetDC.Name)" -ForegroundColor Green
}
catch {
    Write-Error "[-] Cannot find target DC: $NewDCName"
    Write-Error $_.Exception.Message
    exit 1
}

# Check replication status - this command often gives a non-zero output even when all successful...
Write-Host "Checking replication status..." -ForegroundColor Yellow
try {
    $replStatus = repadmin /showrepl $NewDCName 2>&1
    if ($replStatus -match "ERROR|FAILED") {
        Write-Warning "[!] Replication status check found errors"
        Write-Host "Review the replication status manually if needed" -ForegroundColor Yellow
    } else {
        Write-Host "[+] Replication status checked successfully" -ForegroundColor Green
    }
}
catch {
    Write-Warning "[!] Could not verify replication status: $($_.Exception.Message)"
}

# Display current FSMO role holders
Write-Host "`nCurrent FSMO Role Holders" -ForegroundColor Cyan
try {
    $currentRoles = Get-ADDomainController -Filter * | Select-Object Name, OperationMasterRoles | Where-Object { $_.OperationMasterRoles.Count -gt 0 }
    foreach ($dc in $currentRoles) {
        Write-Host "$($dc.Name): $($dc.OperationMasterRoles -join ', ')" -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Could not retrieve current FSMO roles: $($_.Exception.Message)"
}

# Confirm before proceeding
Write-Host "`nTransfer Confirmation" -ForegroundColor Cyan
$confirmation = Read-Host "Do you want to proceed with transferring all FSMO roles to $NewDCName? (Y/N)"
if ($confirmation -notmatch '^[Yy]$') {
    Write-Host "Operation cancelled by user." -ForegroundColor Red
    exit 0
}

# Transfer roles sequentially with error handling
Write-Host "`nStarting FSMO Role Transfer" -ForegroundColor Cyan
$successCount = 0
$failedRoles = @()

foreach ($role in $FSMORoles) {
    Write-Host "`n--- Transferring $role ---" -ForegroundColor White
    
    try {
        # Attempt to transfer the role
        Write-Host "Attempting to transfer $role to $NewDCName..." -ForegroundColor Yellow
        
        Move-ADDirectoryServerOperationMasterRole -Identity $NewDCName -OperationMasterRole $role -ErrorAction Stop -Confirm:$false
        
        Write-Host "[+] Transfer command executed successfully" -ForegroundColor Green
        
        # Verify the transfer was successful
        Write-Host "Verifying transfer..." -ForegroundColor Yellow
        if (Verify-FSMORole -DCName $NewDCName -RoleName $role) {
            Write-Host "[+] $role successfully transferred to $NewDCName" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Error "[-] Transfer verification failed for $role"
            $failedRoles += $role
            
            # Ask if user wants to continue with remaining roles
            $continueChoice = Read-Host "Continue with remaining roles? (Y/N)"
            if ($continueChoice -notmatch '^[Yy]$') {
                Write-Host "Operation halted by user." -ForegroundColor Red
                break
            }
        }
        
    }
    catch {
        Write-Error "[-] Failed to transfer $role : $($_.Exception.Message)"
        $failedRoles += $role
        
        # Ask if user wants to continue with remaining roles
        $continueChoice = Read-Host "Continue with remaining roles? (Y/N)"
        if ($continueChoice -notmatch '^[Yy]$') {
            Write-Host "Operation halted by user." -ForegroundColor Red
            break
        }
    }
}

# Final summary
Write-Host "`nTransfer Summary" -ForegroundColor Cyan
Write-Host "Successfully transferred: $successCount out of $($FSMORoles.Count) roles" -ForegroundColor Green

if ($failedRoles.Count -gt 0) {
    Write-Host "Failed roles: $($failedRoles -join ', ')" -ForegroundColor Red
}
else {
    Write-Host "All roles transferred successfully! [+]" -ForegroundColor Green
}

# Display final FSMO role holders
Write-Host "`nFinal FSMO Role Holders" -ForegroundColor Cyan
try {
    $finalRoles = Get-ADDomainController -Filter * | Select-Object Name, OperationMasterRoles | Where-Object { $_.OperationMasterRoles.Count -gt 0 }
    foreach ($dc in $finalRoles) {
        Write-Host "$($dc.Name): $($dc.OperationMasterRoles -join ', ')" -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Could not retrieve final FSMO roles: $($_.Exception.Message)"
}

# Recommend post-transfer checks
Write-Host "`nRecommended Post-Transfer Checks" -ForegroundColor Cyan
Write-Host "1. Run: repadmin /showrepl" -ForegroundColor White
Write-Host "2. Run: dcdiag /v" -ForegroundColor White
Write-Host "3. Check Directory Service event logs on all DCs" -ForegroundColor White
Write-Host "4. Test domain authentication and services" -ForegroundColor White

Write-Host "`nFSMO transfer process completed." -ForegroundColor Green

# Verify roles moved successfully
netdom query fsmo

# Check event logs for errors
Get-WinEvent -FilterHashtable @{LogName = 'Directory Service'; Level = 2, 3 } -MaxEvents 10

# Additional testing commands if only Infrastructure Master was transferred
if ($FSMORoles.Count -eq 1 -and $FSMORoles[0] -eq "InfrastructureMaster") {
    Write-Host "`n=== Infrastructure Master Test Commands ===" -ForegroundColor Cyan
    Write-Host "Test cross-domain references (if multi-domain):" -ForegroundColor Yellow
    Write-Host "Get-ADUser -Filter * -Properties MemberOf | Select Name, MemberOf" -ForegroundColor White
    Write-Host "Get-ADGroup -Filter * -Properties Members | Select Name, Members" -ForegroundColor White
    Write-Host "`nIf testing was successful, you can proceed with remaining roles." -ForegroundColor Green
}
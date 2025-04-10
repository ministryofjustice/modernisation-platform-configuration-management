function Install-RDSSessionHostRole {
    if ((Get-WindowsFeature -Name 'RDS-RD-Server').Installed) {
        Write-Host "Remote Desktop Session Host role service already installed"
        return
    }
    else {
        Write-Host "Installing Remote Desktop Session Host role"
        Install-WindowsFeature -Name 'RDS-RD-Server' -IncludeAllSubFeature -IncludeManagementTools
        # May need a restart but this is covered when the machine is added to the domain
    }
}

Install-RDSSessionHostRole

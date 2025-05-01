# Set local time zone to UK although this should now be set by Group Policy objects
$desiredTimeZone = "GMT Standard Time"
$currentTimeZone = (Get-TimeZone).Id

if ($currentTimeZone -eq $desiredTimeZone) {
    Write-Host "Time zone is already set to $desiredTimeZone."
} else {
    Set-TimeZone -Name $desiredTimeZone
    Write-Host "Time zone has been set to $desiredTimeZone."
}

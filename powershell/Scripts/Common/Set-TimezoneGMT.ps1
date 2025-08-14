# Set local time zone to UK although this should now be set by Group Policy objects
$desiredTimeZone = "GMT Standard Time"
$currentTimeZone = (Get-TimeZone).Id

if ($currentTimeZone -eq $desiredTimeZone) {
    Write-Verbose "TimeZone is already set to $desiredTimeZone"
} else {
    Write-Output "Setting TimeZone to $desiredTimeZone"
    Set-TimeZone -Name $desiredTimeZone
}
Exit 1

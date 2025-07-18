# to use in windows task scheduler
# Action - start a program
#   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
# with args
#   -ExecutionPolicy Bypass -File "\\amznfsxhu7je3ss.azure.hmpp.root\PrisonerRetail$\Data\copy_incoming.ps1"

$sourcePath = "E:\PrisonerRetail\Data\Incoming"
$destinationPath = "\\amznfsxhu7je3ss.azure.hmpp.root\PrisonerRetail$\Data\Incoming" # "Z:\Data\Incoming"
$LogFile =  "\\amznfsxhu7je3ss.azure.hmpp.root\PrisonerRetail$\Data\copy_incoming_log.txt" # "Z:\Data\copy_incoming_log.txt"
$scriptFrequencySeconds = 10

# Create FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $sourcePath
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Define the action on new file creation
$action = {
    $eventArgs = $Event.SourceEventArgs
    $fullPath = $eventArgs.FullPath
    $fileName = $eventArgs.Name
    $destFile = Join-Path -Path $destinationPath -ChildPath $fileName
    $destDir = Split-Path -Path $destFile -Parent

    # Skip files ending with .processed
    if ($fileName -like '*.processed' -or $fileName -like '*.tmp'  -or $fileName -like '*.crdownload') {
        return
    }

    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }

    Start-Sleep -Milliseconds 1000

    $maxRetries = 3
    $attempt = 0
    $success = $false

    while (-not $success -and $attempt -lt $maxRetries) {
        try {
            Copy-Item -Path $fullPath -Destination $destFile -Force
            Write-Log "Copied $fileName to $destFile"
            $success = $true
        } catch {
            $attempt++
            $errorMessage = $_.Exception.Message
            Write-Log "Attempt: Failed to copy $fileName - $errorMessage"
            Start-Sleep -Milliseconds 2000
        }
    }
}

function Write-Log {
    param (
        [Parameter(Position = 0)][string]$Message
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$logTimestamp $_ - $Message" | Out-File -FilePath $LogFile -Append
}

# Register the event
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

# Keep the script running
Write-Log "Watching for new files in $sourcePath..."
while ($true) {
    Start-Sleep -Seconds $scriptFrequencySeconds
} 
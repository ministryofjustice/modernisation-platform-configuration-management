# Install WinRAR with specific version 7.12.0 because 'latest' failed to download as of Oct 2025
. ../Common/Install-Choco-Package.ps1 winrar '7.12.0'

# Add WinRAR to system PATH environment variable
$winrarPath = 'C:\Program Files\WinRAR'
if (Test-Path $winrarPath) {
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*$winrarPath*") {
        Write-Host "Adding WinRAR to system PATH: $winrarPath" -ForegroundColor Yellow
        $newPath = "$currentPath;$winrarPath"
        [Environment]::SetEnvironmentVariable('PATH', $newPath, [System.EnvironmentVariableTarget]::Machine)
        Write-Host 'WinRAR added to system PATH successfully' -ForegroundColor Green
        
        # Update current session PATH
        $env:PATH += ";$winrarPath"
        Write-Host 'Current session PATH updated' -ForegroundColor Gray
    }
    else {
        Write-Host 'WinRAR is already in system PATH' -ForegroundColor Green
    }
}
else {
    Write-Warning "WinRAR installation directory not found at $winrarPath"
}

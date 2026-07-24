<#
.SYNOPSIS
    Idempotently extracts and installs Symantec Encryption Desktop (file-encryption/PGP Zip only),
    suppresses the forced reboot, and removes the PGPtray autorun shortcut before any reboot occurs.

.DESCRIPTION
    Safe to re-run: it detects and skips each step that's already been completed
    (already extracted, already installed, shortcut already removed), so you can
    run it repeatedly - e.g. after a failure, or as part of a config-management
    run - without re-doing work or erroring out.

.PARAMETER Force
    Re-run the install step even if the product is already detected as installed.

.NOTES
    Copy this script to the target VM, then run this (manually) in an elevated PowerShell session (Run as Administrator).
#>

[CmdletBinding()]
param(
    [string]$BasePath     = "C:\Software\PGPInstaller",
    [string]$InstallerExe = "C:\Software\PGPInstaller\SymantecEncryptionDesktopWin64-10.3.2MP9.exe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$ExtractPath = Join-Path $BasePath "Extract"
$LogPath     = Join-Path $BasePath "Logs"
$extractLog  = Join-Path $LogPath "extract.log"
$installLog  = Join-Path $LogPath "install.log"
$marker      = Join-Path $BasePath ".install-complete"
$runLog      = Join-Path $LogPath ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

foreach ($p in @($BasePath, $ExtractPath, $LogPath)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# Transcript captures every Write-Step/Write-Skip/Write-Host/Write-Error below,
# regardless of whether extraction/install actually ran or were skipped — so
# every run leaves evidence, not just runs that trigger msiexec.
Start-Transcript -Path $runLog -Append | Out-Null

function Write-Step { param($msg) Write-Host "$(Get-Date -Format 'HH:mm:ss') ==> $msg" -ForegroundColor Cyan }
function Write-Skip { param($msg) Write-Host "$(Get-Date -Format 'HH:mm:ss') --> $msg (skipped, already done)" -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
# Helper: is Encryption Desktop / PGP Desktop already installed?
# ---------------------------------------------------------------------------
function Test-PGPInstalled {
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $hit = Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -match "PGP|Symantec Encryption" } |
           Select-Object -First 1
    return [bool]$hit
}

# ---------------------------------------------------------------------------
# Step 1: Extract MSI (skip if already extracted)
# ---------------------------------------------------------------------------
$msi = Get-ChildItem -Path $ExtractPath -Filter *.msi -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($msi) {
    Write-Skip "MSI already extracted: $($msi.FullName)"
}
else {
    Write-Step "Extracting MSI to $ExtractPath ..."

    if (-not (Test-Path $InstallerExe)) {
        Write-Error "Installer not found at $InstallerExe. Place it there or pass -InstallerExe <path>."
        Stop-Transcript | Out-Null
        exit 1
    }

    # Nested quotes must be backslash-escaped, not doubled - Start-Process passes
    # this straight to CreateProcess (no cmd.exe involved), and the InstallShield
    # engine's own argv parser expects \" for embedded quotes, not "".
    $vArg = "/qn TARGETDIR=\`"$ExtractPath\`" /l*v \`"$extractLog\`""
    $extractArgs = @("/a", "/s", "/v`"$vArg`"")
    Start-Process -FilePath $InstallerExe -ArgumentList $extractArgs -Wait -PassThru | Out-Null

    $msi = Get-ChildItem -Path $ExtractPath -Filter *.msi -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    # Fallback: some InstallScript/MSI hybrids ignore TARGETDIR on silent runs
    if (-not $msi) {
        Write-Step "MSI not found under $ExtractPath — searching %TEMP% as fallback..."
        $msi = Get-ChildItem -Path $env:TEMP -Filter *.msi -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match "PGP" } |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($msi) {
            # Copy into our known ExtractPath so re-runs find it there next time
            Copy-Item $msi.FullName -Destination $ExtractPath -Force
            $msi = Get-ChildItem -Path $ExtractPath -Filter *.msi | Select-Object -First 1
        }
    }

    if (-not $msi) {
        Write-Error "Could not locate the extracted MSI. Check $extractLog for details."
        Stop-Transcript | Out-Null
        exit 1
    }

    Write-Step "Extracted: $($msi.FullName)"
}

# ---------------------------------------------------------------------------
# Step 2: Install (skip if already installed, unless -Force)
# ---------------------------------------------------------------------------
$alreadyInstalled = Test-PGPInstalled
$proc = $null

if ($alreadyInstalled -and -not $Force) {
    Write-Skip "Product already installed"
}
else {
    if ($alreadyInstalled -and $Force) {
        Write-Step "Already installed, but -Force specified — re-running install..."
    }
    else {
        Write-Step "Installing (reboot suppressed)..."
    }

    $msiArgs = @(
        "/i", "`"$($msi.FullName)`""
        "PGP_INSTALL_WDE=0"
        "PGP_INSTALL_SSO=0"
        "PGP_INSTALL_LSP=0"
        "PGP_INSTALL_MAPI=0"
        "PGP_INSTALL_MAPI_PLUGIN=0"
        "PGP_INSTALL_NOTES=0"
        "PGP_INSTALL_GROUPWISE=0"
        "PGP_INSTALL_NETSHARE=0"
        "PGP_INSTALL_VDISK=0"
        "REBOOT=ReallySuppress"
        "/qn"
        "/norestart"
        "/l*v", "`"$installLog`""
    )

    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    Write-Step "msiexec exit code: $($proc.ExitCode)"
    # 0 = success, no reboot needed. 3010 = success, reboot required (suppressed above).
    if ($proc.ExitCode -notin @(0, 3010)) {
        Write-Error "Install failed (exit code $($proc.ExitCode)). Check $installLog for details."
        Stop-Transcript | Out-Null
        exit 1
    }

    Set-Content -Path $marker -Value (Get-Date -Format "o")
}

$rebootRecommended = ($proc -and $proc.ExitCode -eq 3010)

# ---------------------------------------------------------------------------
# Step 3: Remove autorun shortcut(s) / Run-key entries (naturally idempotent —
# only acts if the artifact is still present)
# ---------------------------------------------------------------------------
Write-Step "Checking for PGPtray autorun artifacts..."

$shortcutTargets = @(
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\PGPtray.exe.lnk"
)
$userStartups = Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\PGPtray.exe.lnk" -ErrorAction SilentlyContinue
if ($userStartups) { $shortcutTargets += $userStartups.FullName }

$removedAny = $false
foreach ($path in $shortcutTargets) {
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Step "Removed: $path"
        $removedAny = $true
    }
}

$runKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$pgpRunEntry = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue |
               Get-Member -MemberType NoteProperty | Where-Object { $_.Name -match "PGP" }
if ($pgpRunEntry) {
    foreach ($entry in $pgpRunEntry) {
        Write-Step "Found Run-key autorun entry '$($entry.Name)' — removing."
        Remove-ItemProperty -Path $runKey -Name $entry.Name -ErrorAction SilentlyContinue
        $removedAny = $true
    }
}

if (-not $removedAny) { Write-Skip "No autorun shortcut/Run-key entries found" }

# ---------------------------------------------------------------------------
# Step 4: Report status — reboot deliberately left to you, not automatic
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
if ($rebootRecommended) {
    Write-Host "A reboot is recommended (exit code 3010) but was suppressed." -ForegroundColor Yellow
    Write-Host "Shortcut cleanup is already done, so it's safe to reboot whenever you like, e.g.:" -ForegroundColor Yellow
    Write-Host "    Restart-Computer -Force" -ForegroundColor Yellow
}
else {
    Write-Host "No reboot required." -ForegroundColor Green
}
Write-Host "Logs: $extractLog | $installLog | $runLog"

Stop-Transcript | Out-Null

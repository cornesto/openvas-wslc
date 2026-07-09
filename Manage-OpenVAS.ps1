<#
.SYNOPSIS
    Manages Greenbone OpenVAS (Community Edition) via native wslc.exe.

.DESCRIPTION
    Provides an interactive lifecycle management menu with built-in state awareness.
    Universal script: Automatically detects and targets x64 or ARM64 architectures.
    Default Web UI Credentials: admin / admin
#>

$ErrorActionPreference = "Continue"
# ---------------------------------------------------------
# DYNAMIC HARDWARE DETECTION
# ---------------------------------------------------------
$HostArch = $env:PROCESSOR_ARCHITECTURE
if ($HostArch -eq "ARM64") {
    $PlatformFlag = @()
    $ArchDisplay = "ARM64"
} elseif ($HostArch -eq "AMD64") {
    $PlatformFlag = @()
    $ArchDisplay = "x64"
} else {
    # Fallback to engine defaults if unusual architecture
    $PlatformFlag = @() 
    $ArchDisplay = "Unknown ($HostArch)"
}

# Centralized configurations
# Centralized configurations
$Containers = @("gvm-all-in-one") 
$Volumes = @("openvas_immauss_data")
$Images = @("immauss/openvas:latest")

# ---------------------------------------------------------
# STATE & VALIDATION FUNCTIONS
# ---------------------------------------------------------

Function Test-EngineAvailability {
    $wsl = [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
    $wslc = [bool](Get-Command wslc.exe -ErrorAction SilentlyContinue)
    return @{ WSL = $wsl; WSLC = $wslc }
}

Function Test-OpenVASInstalled {
    $engines = Test-EngineAvailability
    if (-not $engines.WSLC) { return $false }

    wslc inspect gvm-all-in-one 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

Function Show-MenuHeader {
    Clear-Host
    # CORNESTO ASCII Art
    Write-Host "  ____ ___  ____  _   _ _____ ___ _____ ___  " -ForegroundColor Cyan
    Write-Host " / ___/ _ \|  _ \| \ | | ____/ __|_   _/ _ \ " -ForegroundColor Cyan
    Write-Host "| |  | | | | |_) |  \| |  _| \__ \ | || | | |" -ForegroundColor Cyan
    Write-Host "| |__| |_| |  _ <| |\  | |___ ___) || || |_| |" -ForegroundColor Cyan
    Write-Host " \____\___/|_| \_\_| \_|_____|____/ |_| \___/ " -ForegroundColor Cyan
    Write-Host "                 IT & Security                 `n" -ForegroundColor DarkCyan
    
    Write-Host "===============================================" -ForegroundColor White
    Write-Host " OpenVAS WSLC Orchestrator v1.0 (Windows x64/ARM64) " -ForegroundColor White
    Write-Host "===============================================" -ForegroundColor White
    Write-Host " All-In-One Edition (immauss/openvas) " -ForegroundColor DarkGray
    Write-Host "===============================================" -ForegroundColor White
    Write-Host " Web UI URL: http://localhost:9392" -ForegroundColor Cyan
    Write-Host " Credentials: admin / admin" -ForegroundColor DarkGray
    Write-Host "===============================================" -ForegroundColor White
}

Function Show-SystemStatus {
    $Engines = Test-EngineAvailability
    $IsInstalled = Test-OpenVASInstalled

    Write-Host "`n--- SYSTEM STATUS QUICK VIEW ------------------" -ForegroundColor DarkGray
    
    # Hardware Status
    Write-Host "Host CPU:     $ArchDisplay Detected" -ForegroundColor Cyan

    # Engine Status
    Write-Host -NoNewline "WSL Engine:   "
    if ($Engines.WSL) { Write-Host "Installed" -ForegroundColor Green } else { Write-Host "Missing" -ForegroundColor Red }
    
    Write-Host -NoNewline "WSLC Engine:  "
    if ($Engines.WSLC) { Write-Host "Installed" -ForegroundColor Green } else { Write-Host "Missing" -ForegroundColor Red }

    Write-Host ("-" * 47) -ForegroundColor DarkGray

    # Stack Status
    if (-not $Engines.WSLC) {
        Write-Host "Stack Status: Cannot check (WSLC not found)" -ForegroundColor Yellow
        return
    }

    if (-not $IsInstalled) {
        Write-Host "Stack Status: " -NoNewline; Write-Host "Not Installed" -ForegroundColor DarkGray
        Write-Host "Updates:      N/A" -ForegroundColor DarkGray
    } else {
        Write-Host "Stack Status: " -NoNewline; Write-Host "Deployed" -ForegroundColor Green
        
        $rawStatus = (wslc inspect gvm-all-in-one 2>$null | ConvertFrom-Json)
        $status = if ($null -ne $rawStatus) { $rawStatus[0].State.Status } else { "unknown" }
        $statusColor = if ($status -eq "running") { "Green" } elseif ($status -match "exited|created") { "Yellow" } else { "Red" }
        Write-Host "Containers:   " -NoNewline
        Write-Host "gvm-all-in-one is $status" -ForegroundColor $statusColor
        
        $uiStatus = "Offline"
        $uiColor = "Red"
        if ($status -eq "running") {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:9392" -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
                $uiStatus = "Online (Responding)"
                $uiColor = "Green"
            } catch {
                if ($_.Exception.Response) {
                    $uiStatus = "Online (Responding)"
                    $uiColor = "Green"
                } else {
                    $uiStatus = "Starting up... (Not responding yet)"
                    $uiColor = "Yellow"
                }
            }
        }
        Write-Host "Web UI:       " -NoNewline
        Write-Host $uiStatus -ForegroundColor $uiColor
        Write-Host "Updates:      " -NoNewline
        Write-Host "Select Option 5 to fetch remote registry diff" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------
# CORE DEPLOYMENT LOGIC
# ---------------------------------------------------------

Function Install-WSLEngine {
    Write-Host "`n=== INSTALLING / UPDATING WSL ENGINE ===" -ForegroundColor Cyan
    Write-Host "Updating to the latest preview version (2.9.x+) for native container support..." -ForegroundColor Yellow
    
    try {
        wsl --update --pre-release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Update command failed. Attempting full installation..." -ForegroundColor Yellow
            wsl --install --pre-release
        }
    } catch {
        Write-Host "Standard command failed. Invoking absolute path installer..." -ForegroundColor Yellow
        wsl.exe --install --pre-release
    }

    Write-Host "`nShutting down current WSL services..." -ForegroundColor Yellow
    wsl --shutdown 2>$null

    Write-Host "`nAttempting to reload environment variables dynamically..." -ForegroundColor Yellow
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command wslc.exe -ErrorAction SilentlyContinue) {
        $wslcVer = (wslc --version 2>&1) -join ""
        Write-Host "`n[SUCCESS] WSLC detected in PATH!" -ForegroundColor Green
        Write-Host "Version Info: $wslcVer"
        Write-Host "You can now proceed with Option 2 to deploy OpenVAS." -ForegroundColor Green
    } else {
        Write-Host "`n[NOTICE] Update executed, but wslc.exe is not in the current session PATH." -ForegroundColor Yellow
        Write-Host "Please completely CLOSE and RE-OPEN this terminal app to reload the new executables." -ForegroundColor Yellow
        Write-Host "After restarting, you can validate with: wslc --version" -ForegroundColor Yellow
    }
}

Function Deploy-OpenVASContainers {
    Write-Host "`nBootstrapping Container..." -ForegroundColor Yellow
    $Activity = "Deploying OpenVAS All-In-One ($ArchDisplay)"
    
    Write-Progress -Activity $Activity -Status "Starting gvm-all-in-one (1/1)" -PercentComplete 100

    # Execute wslc dynamically. We set SKIPSYNC=true to avoid the problematic rsync server.
    wslc run -d --name gvm-all-in-one $PlatformFlag `
        -p 9392:9392 `
        -p 8080:80 `
        -e SKIPSYNC=true `
        -v openvas_immauss_data:/data `
        immauss/openvas:latest 2>&1 | Out-Null

    Write-Progress -Activity $Activity -Completed
    Write-Host " - Deployment phase successful." -ForegroundColor Green
}

# ---------------------------------------------------------
# MENU FUNCTIONS
# ---------------------------------------------------------

Function Install-OpenVAS {
    if (-not (Test-EngineAvailability).WSLC) {
        Write-Host "`n[ERROR] wslc.exe is not installed or not in PATH." -ForegroundColor Red
        Write-Host "Please run Option 1 from the menu to install the WSLC engine." -ForegroundColor Yellow
        return
    }
    if (Test-OpenVASInstalled) {
        Write-Host "`n[NOTICE] OpenVAS is already installed. Use Option 4 to Restart or 6 to Rebuild." -ForegroundColor Yellow
        return
    }

    Write-Host "`n=== STARTING FULL DEPLOYMENT ===" -ForegroundColor Cyan
    
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    $configContent = if (Test-Path $wslConfigPath) { Get-Content $wslConfigPath -Raw } else { "" }
    if ($configContent -notmatch "memory=8GB" -or $configContent -notmatch "processors=4") {
        Write-Host "Updating .wslconfig to allocate 4 vCPUs and 8GB RAM..."
        Add-Content -Path $wslConfigPath -Value "`n[wsl2]`nmemory=8GB`nprocessors=4`nnestedVirtualization=true"
        wsl --shutdown
        Start-Sleep -Seconds 3
    }

    Write-Host "Provisioning Native wslc Volumes..." -ForegroundColor Yellow
    foreach ($vol in $Volumes) { wslc volume create $vol 2>$null | Out-Null }

    Deploy-OpenVASContainers

    Write-Host "`nInitial deployment complete." -ForegroundColor Yellow
    Write-Host "Because SKIPSYNC=true was used, feeds will not auto-download." -ForegroundColor Gray
    Write-Host "Use Option 8 in the menu to force a manual HTTP sync if desired." -ForegroundColor Gray
}

Function Get-OpenVASStatus {
    if (-not (Test-OpenVASInstalled)) {
        Write-Host "`n[ERROR] OpenVAS stack is not installed." -ForegroundColor Red
        return
    }

    Write-Host "`n=== COMPONENT STATUS ===" -ForegroundColor Cyan
    Write-Host ("{0,-30} | {1}" -f "CONTAINER NAME", "STATE")
    Write-Host ("-" * 50)

    foreach ($container in $Containers) {
        $rawStatus = (wslc inspect $container 2>$null | ConvertFrom-Json)
        
        if ($null -eq $rawStatus) {
            $status = "missing"
            $color = "Red"
        } else {
            $status = $rawStatus[0].State.Status
            if ($status -eq "running") { 
                $color = "Green" 
            } elseif ($status -eq "exited" -or $status -eq "created") { 
                $color = "Yellow" 
            } else { 
                $color = "Red" 
                if (-not $status) { $status = "unknown / down" }
            }
        }
        Write-Host ("{0,-30} | {1}" -f $container, $status) -ForegroundColor $color
    }

    Write-Host ("-" * 50)
    Write-Host ("{0,-30} | " -f "Web UI (http://localhost:9392)") -NoNewline
    
    $uiStatus = "Offline"
    $uiColor = "Red"
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9392" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        $uiStatus = "Online & Active"
        $uiColor = "Green"
    } catch {
        if ($_.Exception.Response) {
            $uiStatus = "Online & Active"
            $uiColor = "Green"
        } else {
            $uiStatus = "Offline (Not Responding)"
            $uiColor = "Yellow"
        }
    }
    Write-Host $uiStatus -ForegroundColor $uiColor
}

Function Restart-OpenVAS {
    if (-not (Test-OpenVASInstalled)) {
        Write-Host "`n[ERROR] OpenVAS stack is not installed. Nothing to restart." -ForegroundColor Red
        return
    }

    Write-Host "`n=== RESTARTING SERVICES ===" -ForegroundColor Cyan
    
    Write-Host "Stopping gvm-all-in-one..."
    wslc stop gvm-all-in-one 2>$null | Out-Null
    
    Write-Host "Starting gvm-all-in-one..."
    wslc start gvm-all-in-one 2>$null | Out-Null
    
    Write-Host "`nRestart complete." -ForegroundColor Green
    Get-OpenVASStatus
}

Function Update-OpenVASImages {
    if (-not (Test-EngineAvailability).WSLC) { 
        Write-Host "`n[ERROR] WSLC engine missing. Run Option 1 first." -ForegroundColor Red
        return 
    }

    Write-Host "`n=== CHECKING & APPLYING UPDATES ===" -ForegroundColor Cyan
    
    $Activity = "Pulling Latest Images ($ArchDisplay)"
    $updateFound = $false
    
    Write-Progress -Activity $Activity -Status "Downloading immauss/openvas:latest" -PercentComplete 100
    $pullOutput = wslc pull immauss/openvas:latest 2>&1
    if ($pullOutput -match "Downloaded newer image") { $updateFound = $true }
    
    Write-Progress -Activity $Activity -Completed

    if (-not $updateFound) {
        Write-Host "`nAll images are already up to date." -ForegroundColor Green
        return
    }

    if (Test-OpenVASInstalled) {
        Write-Host "`nUpdates downloaded. Rebuilding containers to apply changes..." -ForegroundColor Yellow
        wslc rm -f gvm-all-in-one 2>$null | Out-Null
        Deploy-OpenVASContainers
    } else {
        Write-Host "`nImages updated locally, but OpenVAS is not currently deployed." -ForegroundColor Gray
    }
}

Function Uninstall-OpenVAS {
    if (-not (Test-OpenVASInstalled)) {
        Write-Host "`n[NOTICE] OpenVAS stack is not currently installed." -ForegroundColor Yellow
        return
    }

    Write-Host "`n=== STARTING TEARDOWN ===" -ForegroundColor Red
    $Confirm = Read-Host "WARNING: This destroys the database and vulnerability feeds. Proceed? (Y/N)"
    
    if ($Confirm -notmatch "^[Yy]$") { return }

    $Activity = "Destroying OpenVAS Environment"

    Write-Progress -Activity $Activity -Status "Removing container: gvm-all-in-one" -PercentComplete 50
    wslc rm -f gvm-all-in-one 2>$null | Out-Null 
    
    Write-Progress -Activity $Activity -Status "Removing volume: openvas_immauss_data" -PercentComplete 100
    wslc volume rm openvas_immauss_data 2>$null | Out-Null 

    Write-Progress -Activity $Activity -Completed
    Write-Host "`nTeardown Complete." -ForegroundColor Cyan
}

Function Show-OpenVASLogs {
    if (-not (Test-OpenVASInstalled)) {
        Write-Host "`n[ERROR] OpenVAS stack is not currently installed." -ForegroundColor Red
        return
    }

    Write-Host "`n=== CONTAINER STARTUP LOGS ===" -ForegroundColor Cyan
    Write-Host "Displaying the latest 50 lines from the container (press Ctrl+C to exit if it hangs)..." -ForegroundColor Yellow
    wslc logs --tail 50 gvm-all-in-one
}

Function Sync-OpenVASFeeds {
    if (-not (Test-OpenVASInstalled)) {
        Write-Host "`n[ERROR] OpenVAS stack is not currently installed." -ForegroundColor Red
        return
    }

    Write-Host "`n=== INITIATING VULNERABILITY FEED SYNC ===" -ForegroundColor Cyan
    Write-Host "This will pull the latest NVT, SCAP, and CERT feeds directly into the container." -ForegroundColor Yellow
    Write-Host "Please note that this process can take 15-45 minutes and runs in the background." -ForegroundColor Yellow
    
    $rawStatus = (wslc inspect gvm-all-in-one 2>$null | ConvertFrom-Json)
    if ($null -ne $rawStatus -and $rawStatus[0].State.Status -eq "running") {
        # immauss image includes a command to force sync via greenbone-feed-sync
        Write-Host "Executing feed sync within container..." -ForegroundColor Cyan
        wslc exec gvm-all-in-one /bin/sh -c "greenbone-feed-sync --type all"
        Write-Host "`nSync Complete! You may need to restart the container for GVM to fully ingest the updates." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Container is not running." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# MAIN MENU LOOP
# ---------------------------------------------------------
$menuLoop = $true

while ($menuLoop) {
    Show-MenuHeader
    Show-SystemStatus

    Write-Host "--- INTERACTIVE MENU --------------------------" -ForegroundColor DarkGray
    Write-Host "1. Install/Update WSL Engine (Enables WSLC)"
    Write-Host "2. Deploy OpenVAS"
    Write-Host "3. Check Component Status"
    Write-Host "4. Restart Services"
    Write-Host "5. Update Images & Rebuild Containers"
    Write-Host "6. Completely Remove OpenVAS (Nuke Data)"
    Write-Host "7. Sync Vulnerability Feeds (Manual HTTP Sync)"
    Write-Host "8. View Container Logs (Troubleshooting)"
    Write-Host "9. Exit"
    
    $Choice = Read-Host "`nSelect an option (1-9) [Press Enter to Refresh]"

    switch ($Choice) {
        ''  { continue }
        '1' { Install-WSLEngine; Read-Host "`nPress Enter to return to menu..." }
        '2' { Install-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
        '3' { Get-OpenVASStatus; Read-Host "`nPress Enter to return to menu..." }
        '4' { Restart-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
        '5' { Update-OpenVASImages; Read-Host "`nPress Enter to return to menu..." }
        '6' { Uninstall-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
        '7' { Sync-OpenVASFeeds; Read-Host "`nPress Enter to return to menu..." }
        '8' { Show-OpenVASLogs; Read-Host "`nPress Enter to return to menu..." }
        '9' { 
            Write-Host "Exiting CORNESTO Orchestrator." -ForegroundColor Cyan
            $menuLoop = $false 
        }
        Default { 
            Write-Host "Invalid selection. Please enter a number from 1 to 9." -ForegroundColor Red
            Start-Sleep -Seconds 2 
        }
    }
}
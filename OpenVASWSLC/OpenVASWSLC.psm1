# ---------------------------------------------------------
# OpenVAS WSLC Orchestrator PowerShell Module
# ---------------------------------------------------------

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
    $PlatformFlag = @() 
    $ArchDisplay = "Unknown ($HostArch)"
}

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
    Write-Host "Host CPU:     $ArchDisplay Detected" -ForegroundColor Cyan

    Write-Host -NoNewline "WSL Engine:   "
    if ($Engines.WSL) { Write-Host "Installed" -ForegroundColor Green } else { Write-Host "Missing" -ForegroundColor Red }
    
    Write-Host -NoNewline "WSLC Engine:  "
    if ($Engines.WSLC) { Write-Host "Installed" -ForegroundColor Green } else { Write-Host "Missing" -ForegroundColor Red }

    Write-Host ("-" * 47) -ForegroundColor DarkGray

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
                $response = Invoke-WebRequest -Uri "http://127.0.0.1:9392" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
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
        Write-Host "Select Option 7 to fetch remote registry diff/update" -ForegroundColor Yellow
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
        Write-Host "You can now proceed with Option 7 to deploy OpenVAS." -ForegroundColor Green
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
# OPTIMIZATION FUNCTIONS
# ---------------------------------------------------------

Function Optimize-WSLConfig {
    $wslConfigPath = "$env:USERPROFILE\.wslconfig"
    $newSettings = @{
        "memory"               = "8GB"
        "processors"           = "4"
        "nestedVirtualization" = "true"
        "networkingMode"       = "mirrored"
        "dnsTunneling"         = "true"
        "kernelCommandLine"    = "sysctl.vm.overcommit_memory=1"
    }

    # Load existing content or initialize
    $lines = @()
    if (Test-Path $wslConfigPath) {
        $lines = Get-Content $wslConfigPath
    }

    $updatedLines = @()
    $inWsl2Section = $false
    $sectionHeaderFound = $false
    $processedKeys = @{}
    $modified = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "[wsl2]") {
            $inWsl2Section = $true
            $sectionHeaderFound = $true
            $updatedLines += $line
            continue
        } elseif ($trimmed -match "^\[.*\]$") {
            if ($inWsl2Section) {
                foreach ($key in $newSettings.Keys) {
                    if (-not $processedKeys.ContainsKey($key)) {
                        $updatedLines += "$key=$($newSettings[$key])"
                        $modified = $true
                    }
                }
                $inWsl2Section = $false
            }
            $updatedLines += $line
            continue
        }

        if ($inWsl2Section -and $trimmed -match "^([^=]+)=(.*)$") {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            if ($newSettings.ContainsKey($key)) {
                if ($processedKeys.ContainsKey($key)) {
                    $modified = $true
                    continue
                }
                if ($val -ne $newSettings[$key]) {
                    $updatedLines += "$key=$($newSettings[$key])"
                    $modified = $true
                } else {
                    $updatedLines += $line
                }
                $processedKeys[$key] = $true
                continue
            }
        }
        $updatedLines += $line
    }

    if ($inWsl2Section -or -not $sectionHeaderFound) {
        if (-not $sectionHeaderFound) {
            $updatedLines += ""
            $updatedLines += "[wsl2]"
            $modified = $true
        }
        foreach ($key in $newSettings.Keys) {
            if (-not $processedKeys.ContainsKey($key)) {
                $updatedLines += "$key=$($newSettings[$key])"
                $modified = $true
            }
        }
    }

    if ($modified) {
        Write-Host "Updating host .wslconfig with optimal settings (mirrored network, memory overcommit, resource limits)..." -ForegroundColor Yellow
        $updatedLines | Set-Content $wslConfigPath
        return $true
    } else {
        Write-Host "Host .wslconfig is already optimal." -ForegroundColor Green
        return $false
    }
}

Function Configure-OpenVASLimits {
    if (-not (Ensure-OpenVASInstalled)) { return }

    $rawStatus = (wslc inspect gvm-all-in-one 2>$null | ConvertFrom-Json)
    $status = if ($null -ne $rawStatus) { $rawStatus[0].State.Status } else { "unknown" }
    
    $needsStop = $false
    if ($status -ne "running") {
        Write-Host "Starting container temporarily to apply configurations..." -ForegroundColor Yellow
        wslc start gvm-all-in-one 2>$null | Out-Null
        $needsStop = $true
        Start-Sleep -Seconds 5
    }

    Write-Host "Configuring OpenVAS limits inside the container (/etc/openvas/openvas.conf)..." -ForegroundColor Yellow
    wslc exec gvm-all-in-one /usr/bin/sed -i '/max_hosts/d' /etc/openvas/openvas.conf 2>$null
    wslc exec gvm-all-in-one /usr/bin/sed -i '/max_checks/d' /etc/openvas/openvas.conf 2>$null
    wslc exec gvm-all-in-one /bin/sh -c "echo 'max_hosts = 4' >> /etc/openvas/openvas.conf" 2>$null
    wslc exec gvm-all-in-one /bin/sh -c "echo 'max_checks = 4' >> /etc/openvas/openvas.conf" 2>$null

    Write-Host "[SUCCESS] OpenVAS configured: max_hosts = 4, max_checks = 4." -ForegroundColor Green

    Write-Host "`nCurrent /etc/openvas/openvas.conf contents:" -ForegroundColor Gray
    wslc exec gvm-all-in-one cat /etc/openvas/openvas.conf 2>$null

    if ($needsStop) {
        Write-Host "Stopping container..." -ForegroundColor Yellow
        wslc stop gvm-all-in-one 2>$null | Out-Null
    } else {
        Write-Host "Please restart the container using Option 1 to apply scanner configuration changes." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------
# MENU HELPER FUNCTIONS
# ---------------------------------------------------------

Function Install-OpenVAS {
    if (-not (Test-EngineAvailability).WSLC) {
        Write-Host "`n[ERROR] wslc.exe is not installed or not in PATH." -ForegroundColor Red
        Write-Host "Please run Option 8 from the menu to install the WSLC engine." -ForegroundColor Yellow
        return
    }
    if (Test-OpenVASInstalled) {
        Write-Host "`n[NOTICE] OpenVAS is already installed. Use Option 1 to Start/Restart or Option 7 to Update." -ForegroundColor Yellow
        return
    }

    Write-Host "`n=== STARTING FULL DEPLOYMENT ===" -ForegroundColor Cyan
    
    $wslUpdated = Optimize-WSLConfig
    if ($wslUpdated) {
        Write-Host "WSL configuration updated. Shutting down WSL to apply..." -ForegroundColor Yellow
        wsl --shutdown
        Start-Sleep -Seconds 3
    }

    Write-Host "Provisioning Native wslc Volumes..." -ForegroundColor Yellow
    foreach ($vol in $Volumes) { wslc volume create $vol 2>$null | Out-Null }

    Deploy-OpenVASContainers
    Configure-OpenVASLimits

    Write-Host "`nInitial deployment complete." -ForegroundColor Yellow
    Write-Host "Because SKIPSYNC=true was used, feeds will not auto-download." -ForegroundColor Gray
    Write-Host "Use Option 5 in the menu to force a manual HTTP sync if desired." -ForegroundColor Gray
}

Function Get-OpenVASStatus {
    if (-not (Ensure-OpenVASInstalled)) { return }

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
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:9392" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
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
    if (-not (Ensure-OpenVASInstalled)) { return }

    Write-Host "`n=== RESTARTING SERVICES ===" -ForegroundColor Cyan
    
    Write-Host "Stopping gvm-all-in-one..."
    wslc stop gvm-all-in-one 2>$null | Out-Null
    
    Write-Host "Starting gvm-all-in-one..."
    wslc start gvm-all-in-one 2>$null | Out-Null
    
    Write-Host "`nRestart complete." -ForegroundColor Green
    Get-OpenVASStatus
}

Function Stop-OpenVAS {
    if (-not (Ensure-OpenVASInstalled)) { return }

    Write-Host "`n=== STOPPING SERVICES ===" -ForegroundColor Cyan
    Write-Host "Stopping gvm-all-in-one..."
    wslc stop gvm-all-in-one 2>$null | Out-Null
    Write-Host "`nServices stopped successfully." -ForegroundColor Green
}

Function Deploy-Or-Rebuild {
    if (-not (Test-OpenVASInstalled)) {
        Install-OpenVAS
    } else {
        $confirm = Read-Host "OpenVAS is already installed. Do you want to check for image updates and update the container? (Existing scan data will be retained) (Y/N)"
        if ($confirm -match "^[Yy]$") {
            Update-OpenVASImages
        }
    }
}

Function Ensure-OpenVASInstalled {
    if (Test-OpenVASInstalled) {
        return $true
    }
    
    Write-Host "`n[NOTICE] OpenVAS is not currently deployed." -ForegroundColor Yellow
    $confirm = Read-Host "Would you like to deploy OpenVAS now? (Y/N)"
    if ($confirm -match "^[Yy]$") {
        Deploy-Or-Rebuild
        return (Test-OpenVASInstalled)
    }
    return $false
}

Function Update-OpenVASImages {
    if (-not (Test-EngineAvailability).WSLC) { 
        Write-Host "`n[ERROR] WSLC engine missing. Run Option 8 first." -ForegroundColor Red
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
        Write-Host "`n[NOTICE] OpenVAS is not currently deployed." -ForegroundColor Yellow
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
    if (-not (Ensure-OpenVASInstalled)) { return }

    Write-Host "`n=== CONTAINER STARTUP LOGS ===" -ForegroundColor Cyan
    Write-Host "Displaying the latest 50 lines from the container (press Ctrl+C to exit if it hangs)..." -ForegroundColor Yellow
    wslc logs --tail 50 gvm-all-in-one
}

Function Sync-OpenVASFeeds {
    if (-not (Ensure-OpenVASInstalled)) { return }

    Write-Host "`n=== INITIATING VULNERABILITY FEED SYNC ===" -ForegroundColor Cyan
    Write-Host "This will pull the latest NVT, SCAP, and CERT feeds directly into the container." -ForegroundColor Yellow
    Write-Host "Please note that this process can take 15-45 minutes and runs in the background." -ForegroundColor Yellow
    
    $rawStatus = (wslc inspect gvm-all-in-one 2>$null | ConvertFrom-Json)
    if ($null -ne $rawStatus -and $rawStatus[0].State.Status -eq "running") {
        Write-Host "Executing feed sync within container..." -ForegroundColor Cyan
        wslc exec gvm-all-in-one /bin/sh -c "greenbone-feed-sync --type all"
        Write-Host "`nSync Complete! You may need to restart the container for GVM to fully ingest the updates." -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] Container is not running." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# PUBLIC ENTRYPOINT FUNCTION
# ---------------------------------------------------------

Function Manage-OpenVAS {
    <#
    .SYNOPSIS
        Starts the interactive menu for managing Greenbone OpenVAS.
    .DESCRIPTION
        Provides an interactive lifecycle management menu with built-in state awareness
        using wslc containers.
    .EXAMPLE
        Manage-OpenVAS
    #>
    $menuLoop = $true

    while ($menuLoop) {
        Show-MenuHeader
        Show-SystemStatus

        Write-Host "--- INTERACTIVE MENU --------------------------" -ForegroundColor DarkGray
        Write-Host "1. Start / Restart Services"
        Write-Host "2. Stop Services"
        Write-Host "3. Check Component Status"
        Write-Host "4. View Container Logs"
        Write-Host "5. Sync Vulnerability Feeds"
        Write-Host "6. Optimize Resource Limits (Fix Crashes)"
        Write-Host "7. Deploy / Update Container (Retains Data)"
        Write-Host "8. Setup / Update WSL Engine"
        Write-Host "9. Uninstall OpenVAS (Nuke Data)"
        Write-Host "10. Exit"
        
        $Choice = Read-Host "`nSelect an option (1-10) [Press Enter to Refresh]"

        switch ($Choice) {
            ''  { continue }
            '1' { Restart-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
            '2' { Stop-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
            '3' { Get-OpenVASStatus; Read-Host "`nPress Enter to return to menu..." }
            '4' { Show-OpenVASLogs; Read-Host "`nPress Enter to return to menu..." }
            '5' { Sync-OpenVASFeeds; Read-Host "`nPress Enter to return to menu..." }
            '6' {
                Write-Host "`n=== RUNNING RESOURCE & NETWORK OPTIMIZATION ===" -ForegroundColor Cyan
                $wslUpdated = Optimize-WSLConfig
                if ($wslUpdated) {
                    Write-Host "`n[IMPORTANT] WSL configuration was updated to Mirrored Networking & Memory Overcommit." -ForegroundColor Yellow
                    Write-Host "To apply these changes, you must SHUTDOWN WSL." -ForegroundColor Yellow
                    $confirm = Read-Host "Do you want to run 'wsl --shutdown' now? (Y/N)"
                    if ($confirm -match "^[Yy]$") {
                        Write-Host "Shutting down WSL... Please restart your terminal/script after this completes." -ForegroundColor Yellow
                        wsl --shutdown
                        Start-Sleep -Seconds 2
                        Exit
                    }
                }
                if (Test-OpenVASInstalled) {
                    Configure-OpenVASLimits
                } else {
                    Write-Host "`n[NOTICE] OpenVAS container is not deployed yet. Limits will be automatically configured upon deployment." -ForegroundColor Gray
                }
                Read-Host "`nPress Enter to return to menu..."
            }
            '7' { Deploy-Or-Rebuild; Read-Host "`nPress Enter to return to menu..." }
            '8' { Install-WSLEngine; Read-Host "`nPress Enter to return to menu..." }
            '9' { Uninstall-OpenVAS; Read-Host "`nPress Enter to return to menu..." }
            '10' { 
                Write-Host "Exiting CORNESTO Orchestrator." -ForegroundColor Cyan
                $menuLoop = $false 
            }
            Default { 
                Write-Host "Invalid selection. Please enter a number from 1 to 10." -ForegroundColor Red
                Start-Sleep -Seconds 2 
            }
        }
    }
}

Export-ModuleMember -Function Manage-OpenVAS

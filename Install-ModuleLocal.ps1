# ---------------------------------------------------------
# Installer Script for OpenVASWSLC PowerShell Module
# ---------------------------------------------------------

$ModuleName = "OpenVASWSLC"
$WorkspaceModulePath = Join-Path $PSScriptRoot $ModuleName

Write-Host "Installing OpenVASWSLC PowerShell Module..." -ForegroundColor Cyan

# Resolve dynamic Documents path (handles OneDrive redirection automatically)
$MyDocs = [Environment]::GetFolderPath('MyDocuments')
if (-not $MyDocs) {
    # Fallback if MyDocuments is empty (rare)
    $MyDocs = Join-Path $env:USERPROFILE "Documents"
}

# Standard PowerShell module paths
$DestPaths = @(
    Join-Path $MyDocs "WindowsPowerShell\Modules\$ModuleName"
    Join-Path $MyDocs "PowerShell\Modules\$ModuleName"
)

$installedCount = 0

foreach ($Dest in $DestPaths) {
    # Check parent folder existence
    $ParentDir = Split-Path $Dest -Parent
    if (Test-Path (Split-Path $ParentDir -Parent)) {
        Write-Host "Targeting: $Dest" -ForegroundColor Gray
        
        # Remove old version if exists
        if (Test-Path $Dest) {
            Write-Host "Removing existing version..." -ForegroundColor DarkGray
            Remove-Item -Path $Dest -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Create destination directory
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null

        # Copy files
        Copy-Item -Path "$WorkspaceModulePath\*" -Destination $Dest -Recurse -Force
        Write-Host "[SUCCESS] Copied module files to destination." -ForegroundColor Green
        $installedCount++
    }
}

if ($installedCount -gt 0) {
    Write-Host "`nImporting module to the current session..." -ForegroundColor Yellow
    Import-Module $ModuleName -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host " OpenVASWSLC Module Installed Successfully!" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " You can now launch the orchestrator from ANY shell by running:" -ForegroundColor White
    Write-Host "    Manage-OpenVAS" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Green
} else {
    Write-Error "Failed to locate standard PowerShell module directories."
}

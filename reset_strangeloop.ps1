# StrangeLoop Setup Reset Script - Version 6.1
# This script safely removes all changes made by setup_strangeloop.ps1
# Optionally uninstalls StrangeLoop CLI while preserving user projects
# 
# Usage: .\reset_strangeloop.ps1 [-Force] [-WhatIf]
# 
# Parameters:
#   -Force   : Skip confirmation prompts
#   -WhatIf  : Show what would be reset without actually doing it

param(
    [switch]$Force,
    [switch]$WhatIf
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Logging configuration
$logPrefix = "[RESET]"

# Colors for output
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Header = "Magenta"
}

# Helper functions
function Write-Step {
    param([string]$Message)
    Write-Host "$logPrefix " -ForegroundColor $Colors.Header
    Write-Host "$logPrefix === $Message ===" -ForegroundColor $Colors.Header
}

function Write-Success {
    param([string]$Message)
    Write-Host "$logPrefix ✓ $Message" -ForegroundColor $Colors.Success
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$logPrefix ⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-Info {
    param([string]$Message)
    Write-Host "$logPrefix   $Message" -ForegroundColor $Colors.Info
}

function Get-UserConfirmation {
    param([string]$Message)
    
    if ($Force) {
        Write-Info "$Message [Forced: y]"
        return $true
    }
    
    $choice = Read-Host "$Message [y/N - default: N]"
    # Default to No if empty input or anything other than explicit Yes
    return $choice -match '^[Yy]'
}

function Remove-IfExists {
    param(
        [string]$Path,
        [string]$Description,
        [switch]$Recurse = $false
    )
    
    if (Test-Path $Path) {
        if ($WhatIf) {
            Write-Info "Would remove: $Description ($Path)"
            return $true
        }
        
        try {
            if ($Recurse) {
                Remove-Item $Path -Recurse -Force -ErrorAction Stop
            } else {
                Remove-Item $Path -Force -ErrorAction Stop
            }
            Write-Success "Removed: $Description"
            return $true
        } catch {
            Write-Warning "Failed to remove $Description`: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Info "$Description not found (already clean)"
        return $false
    }
}

# Main reset script
Write-Host @"
$logPrefix ╔═══════════════════════════════════════════════════════════════╗
$logPrefix ║              StrangeLoop Setup Reset Script                   ║
$logPrefix ║                 Remove Setup Changes                          ║
$logPrefix ╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Error

if ($WhatIf) {
    Write-Warning "WhatIf mode: No actual changes will be made"
} else {
    Write-Warning "This will remove all changes made by setup_strangeloop.ps1!"
    Write-Info "This includes:"
    Write-Info "  • temp-strangeloop-scripts directory and downloaded files"
    Write-Info "  • Execution policy changes (reset to Restricted)"
    Write-Info "  • WSL uninstallation (optional - will ask for confirmation)"
    Write-Info "  • Azure CLI uninstallation (optional - will ask for confirmation)"
    Write-Info "  • StrangeLoop CLI uninstallation (optional - will ask for confirmation)"
    Write-Info "  • Temporary files created during setup"
    Write-Info ""
    Write-Warning "Note: Your StrangeLoop projects will be preserved"
    Write-Warning "WSL removal will delete ALL Linux distributions and data!"
    Write-Info ""
    Write-Host "�️  SAFETY: All confirmations default to NO (safe)" -ForegroundColor Green
    Write-Host "   → Just press ENTER to decline any destructive action" -ForegroundColor Green
    Write-Host "   → Type 'y' and press ENTER only if you want to proceed" -ForegroundColor Yellow
    
    if (-not $Force) {
        $proceed = Get-UserConfirmation "`nAre you sure you want to proceed with the reset?"
        if (-not $proceed) {
            Write-Info "Reset cancelled by user."
            exit 0
        }
    }
}

# Step 1: Remove temp scripts directory
Write-Step "Removing Temporary Scripts"
$tempScriptsDir = ".\temp-strangeloop-scripts"
Remove-IfExists -Path $tempScriptsDir -Description "temp-strangeloop-scripts directory" -Recurse

Write-Step "Resetting Execution Policy"

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "RemoteSigned") {
    $shouldReset = Get-UserConfirmation "Reset execution policy from RemoteSigned to Restricted?"
    
    if ($shouldReset) {
        if ($WhatIf) {
            Write-Info "Would reset execution policy to Restricted"
        } else {
            try {
                Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force
                Write-Success "Reset execution policy to Restricted"
            } catch {
                Write-Warning "Failed to reset execution policy: $($_.Exception.Message)"
                Write-Info "You may need to run: Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser"
            }
        }
    } else {
        Write-Info "Keeping current execution policy: $currentPolicy"
    }
} else {
    Write-Info "Execution policy is $currentPolicy (not changed by setup)"
}

# Step 3: Uninstall WSL (Windows Subsystem for Linux)
Write-Step "WSL Uninstallation"

# Check if WSL is installed
$wslInstalled = $false
try {
    $wslDistros = wsl --list --quiet 2>$null
    if ($wslDistros -and ($wslDistros | Where-Object { $_.Trim() -ne "" })) {
        $wslInstalled = $true
        Write-Info "WSL is installed with the following distributions:"
        $wslDistros | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
            Write-Info "  • $($_.Trim())"
        }
    }
} catch {
    # WSL command not found or failed
}

if ($wslInstalled) {
    Write-Warning "⚠ This will remove ALL WSL distributions and data!"
    Write-Warning "⚠ All Linux files, environments, and projects in WSL will be permanently deleted!"
    $shouldUninstallWSL = Get-UserConfirmation "Do you want to uninstall WSL and all distributions? (DESTRUCTIVE)"
    
    if ($shouldUninstallWSL) {
        if ($WhatIf) {
            Write-Info "Would unregister all WSL distributions and disable WSL feature"
        } else {
            Write-Info "Unregistering all WSL distributions..."
            try {
                # Unregister all WSL distributions
                wsl --list --quiet | ForEach-Object { 
                    $distro = $_.Trim()
                    if ($distro -and $distro -ne "") {
                        Write-Info "Unregistering distribution: $distro"
                        wsl --unregister $distro
                    }
                }
                Write-Success "All WSL distributions unregistered"
                
                # Disable WSL feature
                Write-Info "Disabling Windows Subsystem for Linux feature..."
                Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
                Write-Success "WSL feature disabled"
                Write-Warning "A system restart may be required to complete WSL removal"
                
            } catch {
                Write-Warning "WSL uninstallation failed: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Info "Keeping WSL and distributions installed"
    }
} else {
    Write-Info "WSL is not installed or has no distributions (already clean)"
}

# Step 4: Uninstall Azure CLI
Write-Step "Azure CLI Uninstallation"

# Check if Azure CLI is installed
$azureCliInstalled = $false
try {
    $null = Get-Command "az" -ErrorAction SilentlyContinue
    if ($?) {
        $azureCliInstalled = $true
        $azVersion = az --version 2>$null | Select-Object -First 1
        Write-Info "Azure CLI is installed: $azVersion"
    }
} catch {
    # Command not found
}

if ($azureCliInstalled) {
    $shouldUninstallAzure = Get-UserConfirmation "Do you want to uninstall Microsoft Azure CLI?"
    
    if ($shouldUninstallAzure) {
        if ($WhatIf) {
            Write-Info "Would attempt to uninstall Microsoft Azure CLI using winget"
        } else {
            Write-Info "Attempting to uninstall Microsoft Azure CLI using winget..."
            try {
                winget uninstall --name "Microsoft Azure CLI"
                Write-Success "Azure CLI uninstallation command executed"
                
                # Verify uninstallation
                Start-Sleep -Seconds 3
                $null = Get-Command "az" -ErrorAction SilentlyContinue
                if (-not $?) {
                    Write-Success "✓ Azure CLI has been successfully uninstalled"
                } else {
                    Write-Warning "Azure CLI may still be installed. Verification failed."
                    Write-Info "You may need to restart your terminal or complete the uninstallation manually"
                }
                
            } catch {
                Write-Warning "Azure CLI uninstallation failed: $($_.Exception.Message)"
                Write-Info "You can try uninstalling manually:"
                Write-Info "1. Use Windows Settings → Apps → Apps & features"
                Write-Info "2. Search for 'Microsoft Azure CLI' and uninstall"
                Write-Info "3. Or use: winget uninstall --name \"Microsoft Azure CLI\""
            }
        }
    } else {
        Write-Info "Keeping Azure CLI installed"
    }
} else {
    Write-Info "Azure CLI is not installed (already clean)"
}

# Step 5: Uninstall StrangeLoop CLI
Write-Step "StrangeLoop CLI Uninstallation"

# Check if StrangeLoop CLI is installed
$strangeloopInstalled = $false
try {
    $null = Get-Command "strangeloop" -ErrorAction SilentlyContinue
    if ($?) {
        $strangeloopInstalled = $true
        $version = strangeloop --version 2>$null
        Write-Info "StrangeLoop CLI is installed: $version"
    }
} catch {
    # Command not found
}

if ($strangeloopInstalled) {
    $shouldUninstallStrangeloop = Get-UserConfirmation "Do you want to uninstall Strangeloop CLI? (This will remove the CLI but preserve your projects)"
    
    if ($shouldUninstallStrangeloop) {
        if ($WhatIf) {
            Write-Info "Would attempt to uninstall Strangeloop CLI using winget"
        } else {
            Write-Info "Attempting to uninstall Strangeloop CLI using winget..."
            try {
                winget uninstall --name "Strangeloop CLI"
                Write-Success "StrangeLoop CLI uninstallation command executed"
                
                # Verify uninstallation
                Start-Sleep -Seconds 3
                $null = Get-Command "strangeloop" -ErrorAction SilentlyContinue
                if (-not $?) {
                    Write-Success "✓ StrangeLoop CLI has been successfully uninstalled"
                    Write-Success "✓ Command is no longer available in PATH"
                } else {
                    Write-Warning "StrangeLoop CLI may still be installed. Verification failed."
                    Write-Info "You may need to restart your terminal or complete the uninstallation manually"
                }
                
            } catch {
                Write-Warning "StrangeLoop CLI uninstallation failed: $($_.Exception.Message)"
                Write-Info "You can try uninstalling manually:"
                Write-Info "1. Use Windows Settings → Apps → Apps & features"
                Write-Info "2. Search for 'Strangeloop CLI' and uninstall"
                Write-Info "3. Or use: winget uninstall --name \"Strangeloop CLI\""
            }
        }
    } else {
        Write-Info "Keeping StrangeLoop CLI installed"
    }
} else {
    Write-Info "StrangeLoop CLI is not installed (already clean)"
}

# Step 6: Clean up any remaining temporary files
Write-Step "Cleaning Temporary Files"

$tempPaths = @(
    "$env:TEMP\strangeloop*",
    "$env:TEMP\setup_strangeloop*",
    "$env:TEMP\*strangeloop*"
)

$cleanedCount = 0
foreach ($tempPath in $tempPaths) {
    if ($WhatIf) {
        $tempFiles = Get-ChildItem $tempPath -ErrorAction SilentlyContinue
        if ($tempFiles) {
            Write-Info "Would remove $($tempFiles.Count) temporary file(s): $tempPath"
            $cleanedCount += $tempFiles.Count
        }
    } else {
        try {
            $tempFiles = Get-ChildItem $tempPath -ErrorAction SilentlyContinue
            if ($tempFiles) {
                $tempFiles | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Cleaned $($tempFiles.Count) temporary file(s): $tempPath"
                $cleanedCount += $tempFiles.Count
            }
        } catch {
            # Silently continue for temp file cleanup
        }
    }
}

if ($cleanedCount -eq 0) {
    Write-Info "No temporary files found"
} elseif ($WhatIf) {
    Write-Info "Would clean $cleanedCount temporary file(s)"
} else {
    Write-Success "Cleaned $cleanedCount temporary file(s)"
}

# Final summary
Write-Step "Reset Summary" "Green"

if ($WhatIf) {
    Write-Info "WhatIf mode completed. No actual changes were made."
    Write-Info "Run without -WhatIf to perform the actual reset."
} else {
    Write-Success "✓ StrangeLoop setup reset completed!"
    Write-Info ""
    Write-Info "The following areas were processed:"
    Write-Info "  • Temporary scripts directory (temp-strangeloop-scripts)"
    Write-Info "  • PowerShell execution policy"
    Write-Info "  • WSL uninstallation (if requested)"
    Write-Info "  • Azure CLI uninstallation (if requested)"
    Write-Info "  • StrangeLoop CLI uninstallation (if requested)"
    Write-Info "  • Temporary files"
    Write-Info ""
    Write-Info "Your system should now be clean of setup_strangeloop.ps1 changes."
    Write-Warning "Note: Your StrangeLoop projects were left untouched."
    Write-Info "If you want to remove projects, do it manually."
}

Write-Info "Reset script completed."
exit 0

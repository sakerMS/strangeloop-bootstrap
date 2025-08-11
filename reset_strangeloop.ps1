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
    
    $choice = Read-Host "$Message (y/n)"
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
    Write-Info "  • StrangeLoop CLI uninstallation (optional - will ask for confirmation)"
    Write-Info "  • Temporary files created during setup"
    Write-Info ""
    Write-Warning "Note: Your StrangeLoop projects will be preserved"
    
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

# Step 3: Uninstall StrangeLoop CLI (Optional)
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
    $shouldUninstall = Get-UserConfirmation "Do you want to uninstall StrangeLoop CLI? (This will remove the CLI but preserve your projects)"
    
    if ($shouldUninstall) {
        if ($WhatIf) {
            Write-Info "Would attempt to uninstall StrangeLoop CLI"
        } else {
            Write-Info "Attempting to uninstall StrangeLoop CLI..."
            
            # Method 1: Try using MSI product code (most reliable for MSI packages)
            $uninstalled = $false
            try {
                $strangeloopApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "strangeloop CLI" }
                if ($strangeloopApp) {
                    Write-Info "Found StrangeLoop CLI: $($strangeloopApp.Name) v$($strangeloopApp.Version)"
                    Write-Info "Product Code: $($strangeloopApp.IdentifyingNumber)"
                    Write-Info "Uninstalling using MSI product code..."
                    
                    # Use msiexec for silent uninstall
                    $msiResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x", "$($strangeloopApp.IdentifyingNumber)", "/quiet", "/norestart" -Wait -PassThru
                    
                    if ($msiResult.ExitCode -eq 0) {
                        Write-Success "StrangeLoop CLI uninstalled successfully using MSI"
                        $uninstalled = $true
                    } else {
                        Write-Warning "MSI uninstall returned exit code: $($msiResult.ExitCode)"
                    }
                } else {
                    Write-Info "StrangeLoop CLI not found in Win32_Product"
                }
            } catch {
                Write-Warning "MSI uninstall failed: $($_.Exception.Message)"
            }
            
            # Method 2: Try using Get-Package if MSI method failed
            if (-not $uninstalled) {
                try {
                    # Search for packages with various name patterns
                    $packagePatterns = @("*strangeloop*", "*strange*", "strangeloop CLI")
                    foreach ($pattern in $packagePatterns) {
                        $strangeloopPackage = Get-Package $pattern -ErrorAction SilentlyContinue
                        if ($strangeloopPackage) {
                            Write-Info "Found package: $($strangeloopPackage.Name) v$($strangeloopPackage.Version)"
                            $strangeloopPackage | Uninstall-Package -Force
                            Write-Success "StrangeLoop CLI uninstalled successfully using Package Manager"
                            $uninstalled = $true
                            break
                        }
                    }
                    if (-not $uninstalled) {
                        Write-Info "No matching packages found in Package Manager"
                    }
                } catch {
                    Write-Warning "Package Manager uninstall failed: $($_.Exception.Message)"
                }
            }
            
            # Method 3: Try WMI Uninstall method if others failed
            if (-not $uninstalled) {
                try {
                    $strangeloopApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*strangeloop*" }
                    if ($strangeloopApp) {
                        Write-Info "Found StrangeLoop application via WMI: $($strangeloopApp.Name)"
                        Write-Info "Attempting WMI uninstall (this may take a moment)..."
                        $wmiResult = $strangeloopApp.Uninstall()
                        if ($wmiResult.ReturnValue -eq 0) {
                            Write-Success "StrangeLoop CLI uninstalled successfully using WMI"
                            $uninstalled = $true
                        } else {
                            Write-Warning "WMI uninstall returned code: $($wmiResult.ReturnValue)"
                        }
                    }
                } catch {
                    Write-Warning "WMI uninstall failed: $($_.Exception.Message)"
                }
            }
            
            # Method 4: Registry-based uninstall
            if (-not $uninstalled) {
                try {
                    Write-Info "Trying registry-based uninstall..."
                    $uninstallKey = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*strangeloop*" }
                    if ($uninstallKey) {
                        Write-Info "Found uninstall registry entry: $($uninstallKey.DisplayName)"
                        if ($uninstallKey.QuietUninstallString) {
                            Write-Info "Executing quiet uninstall command..."
                            $quietCmd = $uninstallKey.QuietUninstallString
                            Invoke-Expression $quietCmd
                            Write-Success "StrangeLoop CLI uninstalled using quiet uninstall string"
                            $uninstalled = $true
                        } elseif ($uninstallKey.UninstallString) {
                            Write-Info "Found uninstall string: $($uninstallKey.UninstallString)"
                            # Parse msiexec command and make it silent
                            if ($uninstallKey.UninstallString -match "msiexec.*?(\{[^}]+\})") {
                                $productCode = $matches[1]
                                Write-Info "Extracted product code: $productCode"
                                $regResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x", $productCode, "/quiet", "/norestart" -Wait -PassThru
                                if ($regResult.ExitCode -eq 0) {
                                    Write-Success "StrangeLoop CLI uninstalled using registry product code"
                                    $uninstalled = $true
                                }
                            }
                        }
                    }
                } catch {
                    Write-Warning "Registry-based uninstall failed: $($_.Exception.Message)"
                }
            }
            
            # Method 5: Manual instructions if all automatic methods fail
            if (-not $uninstalled) {
                Write-Warning "All automatic uninstallation methods failed."
                Write-Info "Please uninstall manually using one of these methods:"
                Write-Info ""
                Write-Info "Method A - Windows Settings:"
                Write-Info "1. Open Settings → Apps → Apps & features"
                Write-Info "2. Search for 'strangeloop'"
                Write-Info "3. Click on 'strangeloop CLI' and select 'Uninstall'"
                Write-Info ""
                Write-Info "Method B - Control Panel:"
                Write-Info "1. Open Control Panel → Programs → Programs and Features"
                Write-Info "2. Find 'strangeloop CLI' and right-click → Uninstall"
                Write-Info ""
                Write-Info "Method C - Manual MSI command:"
                Write-Info "msiexec /x {75FCBA9A-5321-48DE-9A9A-EF5FA1E16858} /quiet /norestart"
            }
            
            # Verify uninstallation with enhanced checking
            Write-Info "Verifying uninstallation..."
            Start-Sleep -Seconds 3
            
            $stillInstalled = $false
            try {
                # Check command availability
                $null = Get-Command "strangeloop" -ErrorAction SilentlyContinue
                if ($?) {
                    $stillInstalled = $true
                }
            } catch {
                # Command not found is good
            }
            
            # Double-check with WMI
            try {
                $remainingApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "strangeloop CLI" }
                if ($remainingApp) {
                    $stillInstalled = $true
                }
            } catch {
                # Error checking is fine
            }
            
            if ($stillInstalled) {
                Write-Warning "StrangeLoop CLI may still be installed. Uninstallation verification failed."
                Write-Info "You may need to:"
                Write-Info "1. Restart your terminal/PowerShell session"
                Write-Info "2. Complete the uninstallation manually"
                Write-Info "3. Restart your computer if prompted"
            } else {
                Write-Success "✓ StrangeLoop CLI has been successfully uninstalled"
                Write-Success "✓ Command is no longer available in PATH"
            }
        }
    } else {
        Write-Info "Keeping StrangeLoop CLI installed"
    }
} else {
    Write-Info "StrangeLoop CLI is not installed (already clean)"
}

# Step 4: Clean up any remaining temporary files
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
    Write-Info "  • StrangeLoop CLI uninstallation (if requested)"
    Write-Info "  • Temporary files"
    Write-Info ""
    Write-Info "Your system should now be clean of setup_strangeloop.ps1 changes."
    Write-Warning "Note: Your StrangeLoop projects were left untouched."
    Write-Info "If you want to remove projects, do it manually."
}

Write-Info "Reset script completed."
exit 0

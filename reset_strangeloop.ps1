# StrangeLoop Setup Reset Script - Version 6.1
# This script safely removes all changes made by setup_strangeloop.ps1
# Preserves user projects and only cleans up setup-related changes
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
    Write-Info "  • Temporary files created during setup"
    
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

# Step 3: Clean up any remaining temporary files
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
    Write-Info "  • Temporary files"
    Write-Info ""
    Write-Info "Your system should now be clean of setup_strangeloop.ps1 changes."
    Write-Warning "Note: Your StrangeLoop projects were left untouched."
    Write-Info "If you want to remove projects, do it manually."
}

Write-Info "Reset script completed."
exit 0

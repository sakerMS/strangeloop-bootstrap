# StrangeLoop CLI Reset Script
# This script reverts all changes made by the StrangeLoop setup scripts
# 
# Usage: .\reset_strangeloop.ps1 [-Force] [-KeepWSL] [-KeepGit]
# 
# Parameters:
#   -Force      : Skip confirmation prompts and reset everything
#   -KeepWSL    : Don't remove WSL distributions (keep Ubuntu-24.04)
#   -KeepGit    : Don't reset Git global configuration
#   -WhatIf     : Show what would be reset without actually doing it

param(
    [switch]$Force,
    [switch]$KeepWSL,
    [switch]$KeepGit,
    [switch]$WhatIf
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Colors for output
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Highlight = "Magenta"
}

# Helper functions
function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n=== $Message ===" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
}

function Write-Info {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor $Colors.Info
}

function Test-Command {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Get-UserConfirmation {
    param([string]$Message, [string]$DefaultChoice = "n")
    
    if ($Force) {
        Write-Info "$Message [Forced: y]"
        return $true
    }
    
    $choice = Read-Host "$Message (y/n) [$DefaultChoice]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $DefaultChoice
    }
    
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
            return
        }
        
        try {
            if ($Recurse) {
                Remove-Item $Path -Recurse -Force
            } else {
                Remove-Item $Path -Force
            }
            Write-Success "Removed $Description"
        } catch {
            Write-Warning "Failed to remove $Description`: $($_.Exception.Message)"
        }
    } else {
        Write-Info "$Description not found (already clean)"
    }
}

function Reset-EnvironmentVariable {
    param(
        [string]$Name,
        [string]$Description
    )
    
    $currentValue = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::User)
    if ($currentValue) {
        if ($WhatIf) {
            Write-Info "Would reset environment variable: $Description ($Name)"
            return
        }
        
        try {
            [Environment]::SetEnvironmentVariable($Name, $null, [EnvironmentVariableTarget]::User)
            Write-Success "Reset environment variable: $Description"
        } catch {
            Write-Warning "Failed to reset $Description`: $($_.Exception.Message)"
        }
    } else {
        Write-Info "$Description environment variable not set (already clean)"
    }
}

# Main reset script
Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║              StrangeLoop CLI Reset Script                     ║
║                 Revert All Setup Changes                      ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Error

if ($WhatIf) {
    Write-Warning "WhatIf mode: No actual changes will be made"
} else {
    Write-Warning "This will revert ALL changes made by StrangeLoop setup!"
    Write-Info "This includes removing:"
    Write-Info "  • StrangeLoop CLI installation"
    Write-Info "  • Python packages (pipx, Poetry packages)"
    Write-Info "  • WSL Ubuntu distribution (if not using -KeepWSL)"
    Write-Info "  • Git global configuration (if not using -KeepGit)"
    Write-Info "  • Environment variables and PATH modifications"
    
    if (-not $Force) {
        $proceed = Get-UserConfirmation "`nAre you sure you want to proceed with the reset?" "n"
        if (-not $proceed) {
            Write-Info "Reset cancelled by user."
            exit 0
        }
    }
}

# Step 1: Remove StrangeLoop CLI
Write-Step "Removing StrangeLoop CLI"

# Check for StrangeLoop in various locations
$strangeLoopPaths = @(
    "$env:USERPROFILE\.strangeloop",
    "$env:LOCALAPPDATA\StrangeLoop",
    "$env:APPDATA\StrangeLoop"
)

foreach ($path in $strangeLoopPaths) {
    Remove-IfExists -Path $path -Description "StrangeLoop installation directory" -Recurse
}

# Remove from pipx if installed via pipx
if (Test-Command "pipx") {
    if ($WhatIf) {
        Write-Info "Would uninstall StrangeLoop from pipx"
    } else {
        try {
            $pipxList = pipx list --short 2>$null
            if ($pipxList -and $pipxList -match "strangeloop") {
                pipx uninstall strangeloop
                Write-Success "Uninstalled StrangeLoop from pipx"
            } else {
                Write-Info "StrangeLoop not found in pipx (already clean)"
            }
        } catch {
            Write-Warning "Failed to check/uninstall StrangeLoop from pipx: $($_.Exception.Message)"
        }
    }
}

# Step 2: Reset Python Environment
Write-Step "Resetting Python Environment"

# Remove pipx packages that might have been installed by StrangeLoop
$pipxPackagesToRemove = @(
    "strangeloop",
    "poetry",
    "cookiecutter"
)

if (Test-Command "pipx") {
    foreach ($package in $pipxPackagesToRemove) {
        if ($WhatIf) {
            Write-Info "Would uninstall $package from pipx"
        } else {
            try {
                $pipxList = pipx list --short 2>$null
                if ($pipxList -and $pipxList -match $package) {
                    pipx uninstall $package
                    Write-Success "Uninstalled $package from pipx"
                } else {
                    Write-Info "$package not found in pipx"
                }
            } catch {
                Write-Info "$package not installed or already removed"
            }
        }
    }
}

# Remove pipx itself if it was installed by our setup
$pipxPath = "$env:USERPROFILE\.local\bin"
if (Test-Path $pipxPath) {
    if (Get-UserConfirmation "Remove pipx installation directory?" "n") {
        Remove-IfExists -Path $pipxPath -Description "pipx installation directory" -Recurse
    }
}

# Step 3: Reset WSL Environment (Optional)
if (-not $KeepWSL) {
    Write-Step "Resetting WSL Environment"
    
    if (Test-Command "wsl") {
        $ubuntuDistro = "Ubuntu-24.04"
        
        # Check if Ubuntu distribution exists
        $wslDistros = wsl -l -v 2>$null
        $foundUbuntu = $false
        
        if ($wslDistros) {
            $wslDistros -split "`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -and $line -like "*$ubuntuDistro*") {
                    $foundUbuntu = $true
                }
            }
        }
        
        if ($foundUbuntu) {
            if (Get-UserConfirmation "Remove WSL Ubuntu-24.04 distribution? (This will delete all data in WSL)" "n") {
                if ($WhatIf) {
                    Write-Info "Would unregister WSL Ubuntu-24.04 distribution"
                } else {
                    try {
                        wsl --unregister $ubuntuDistro
                        Write-Success "Removed WSL Ubuntu-24.04 distribution"
                    } catch {
                        Write-Warning "Failed to remove WSL Ubuntu distribution: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Info "Keeping WSL Ubuntu distribution"
            }
        } else {
            Write-Info "WSL Ubuntu distribution not found (already clean)"
        }
    } else {
        Write-Info "WSL not installed (already clean)"
    }
} else {
    Write-Info "Keeping WSL environment (KeepWSL parameter specified)"
}

# Step 4: Reset Git Configuration (Optional)
if (-not $KeepGit) {
    Write-Step "Resetting Git Configuration"
    
    if (Test-Command "git") {
        $gitConfigs = @(
            @{ Key = "merge.tool"; Description = "Git merge tool" },
            @{ Key = "mergetool.vscode.cmd"; Description = "VS Code merge tool command" },
            @{ Key = "diff.tool"; Description = "Git diff tool" },
            @{ Key = "difftool.vscode.cmd"; Description = "VS Code diff tool command" },
            @{ Key = "core.autocrlf"; Description = "Git autocrlf setting" },
            @{ Key = "core.eol"; Description = "Git eol setting" }
        )
        
        foreach ($config in $gitConfigs) {
            $currentValue = git config --global --get $config.Key 2>$null
            if ($currentValue) {
                if (Get-UserConfirmation "Reset $($config.Description)?" "y") {
                    if ($WhatIf) {
                        Write-Info "Would reset Git config: $($config.Key)"
                    } else {
                        try {
                            git config --global --unset $config.Key
                            Write-Success "Reset $($config.Description)"
                        } catch {
                            Write-Warning "Failed to reset $($config.Description): $($_.Exception.Message)"
                        }
                    }
                }
            } else {
                Write-Info "$($config.Description) not set (already clean)"
            }
        }
    } else {
        Write-Info "Git not installed (nothing to reset)"
    }
} else {
    Write-Info "Keeping Git configuration (KeepGit parameter specified)"
}

# Step 5: Reset Environment Variables
Write-Step "Resetting Environment Variables"

# Reset PATH modifications (this is tricky, we'll warn the user)
Write-Warning "PATH modifications cannot be automatically reverted"
Write-Info "You may need to manually remove the following from your PATH if they were added:"
Write-Info "  • ~/.local/bin (Linux/WSL)"
Write-Info "  • StrangeLoop installation directories"
Write-Info "  • pipx directories"

# Reset other environment variables that might have been set
$envVarsToReset = @(
    @{ Name = "STRANGELOOP_HOME"; Description = "StrangeLoop home directory" },
    @{ Name = "POETRY_HOME"; Description = "Poetry home directory" }
)

foreach ($envVar in $envVarsToReset) {
    Reset-EnvironmentVariable -Name $envVar.Name -Description $envVar.Description
}

# Step 6: Clean up Docker networks (if any were created)
Write-Step "Cleaning Docker Networks"

if (Test-Command "docker") {
    if ($WhatIf) {
        Write-Info "Would check for and remove agent-network Docker network"
    } else {
        try {
            $networks = docker network ls --format "{{.Name}}" 2>$null
            if ($networks -and $networks -contains "agent-network") {
                docker network rm agent-network 2>$null
                Write-Success "Removed agent-network Docker network"
            } else {
                Write-Info "agent-network Docker network not found (already clean)"
            }
        } catch {
            Write-Info "No Docker networks to clean or Docker not available"
        }
    }
} else {
    Write-Info "Docker not installed (nothing to clean)"
}

# Step 7: Remove temporary files
Write-Step "Cleaning Temporary Files"

$tempPaths = @(
    "$env:TEMP\strangeloop*",
    "$env:TEMP\setup_strangeloop*"
)

foreach ($tempPath in $tempPaths) {
    if ($WhatIf) {
        Write-Info "Would remove temporary files: $tempPath"
    } else {
        try {
            Get-ChildItem $tempPath -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
            Write-Success "Cleaned temporary files: $tempPath"
        } catch {
            Write-Info "No temporary files found: $tempPath"
        }
    }
}

# Final summary
Write-Step "Reset Summary" "Green"

if ($WhatIf) {
    Write-Info "WhatIf mode completed. No actual changes were made."
    Write-Info "Run without -WhatIf to perform the actual reset."
} else {
    Write-Success "✓ StrangeLoop reset completed successfully!"
    Write-Info ""
    Write-Info "The following have been reset/removed:"
    Write-Info "  • StrangeLoop CLI installation"
    Write-Info "  • Python packages installed by setup"
    if (-not $KeepWSL) { Write-Info "  • WSL Ubuntu distribution (if removed)" }
    if (-not $KeepGit) { Write-Info "  • Git global configuration changes" }
    Write-Info "  • Environment variables"
    Write-Info "  • Docker networks"
    Write-Info "  • Temporary files"
    Write-Info ""
    Write-Warning "Manual steps that may be needed:"
    Write-Info "  • Review and clean PATH environment variable"
    Write-Info "  • Remove any shortcuts or aliases you created"
    Write-Info "  • Clear any IDE/editor configurations"
    Write-Info "  • Restart your terminal/PowerShell session"
}

Write-Info "`nReset script completed."
exit 0

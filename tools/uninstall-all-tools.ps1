#Requires -Version 7.0

<#
.SYNOPSIS
    Uninstall all development tools installed by strangeloop bootstrap

.DESCRIPTION
    This script uninstalls Git, Docker Desktop, Python, Poetry, and Git LFS
    that were installed by the strangeloop bootstrap process.

.PARAMETER Tools
    Specify which tools to uninstall. Valid values: Git, Docker, Python, Poetry, GitLFS, All
    Default: All

.PARAMETER SkipConfirmation
    Skip confirmation prompts and proceed with uninstallation

.PARAMETER KeepConfigurations
    Keep user configurations and data when uninstalling

.PARAMETER WhatIf
    Show what would be uninstalled without actually doing it

.EXAMPLE
    .\uninstall-all-tools.ps1
    Uninstall all tools with confirmation prompts

.EXAMPLE
    .\uninstall-all-tools.ps1 -Tools Git,Docker -SkipConfirmation
    Uninstall only Git and Docker without confirmation

.EXAMPLE
    .\uninstall-all-tools.ps1 All -SkipConfirmation
    Uninstall all tools without confirmation

.EXAMPLE
    .\uninstall-all-tools.ps1 -WhatIf
    Preview what would be uninstalled
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("Git", "Docker", "Python", "Poetry", "GitLFS", "WSL", "All")]
    [string[]]$Tools = @("All"),
    
    [switch]$SkipConfirmation,
    [switch]$KeepConfigurations,
    [switch]$WhatIf
)

# Normalize input - if "All" is specified, include all tools
if ($Tools -contains "All") {
    $Tools = @("Git", "Docker", "Python", "Poetry", "GitLFS", "WSL")
}

# Color-coded output functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-ToolInstalled {
    param([string]$ToolName)
    
    $installed = $false
    
    switch ($ToolName) {
        "Git" {
            $installed = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }
        "Docker" {
            $installed = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
        }
        "Python" {
            $installed = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }
        "Poetry" {
            $installed = $null -ne (Get-Command poetry -ErrorAction SilentlyContinue)
        }
        "GitLFS" {
            $installed = $null -ne (Get-Command git-lfs -ErrorAction SilentlyContinue)
        }
        "WSL" {
            $wslDistros = wsl --list --quiet 2>$null
            $installed = $LASTEXITCODE -eq 0 -and $wslDistros
        }
    }
    
    return $installed
}

function Uninstall-Tool {
    param(
        [string]$ToolName,
        [string]$WingetId,
        [scriptblock]$CustomUninstall = $null
    )
    
    if (-not (Test-ToolInstalled $ToolName)) {
        Write-Info "$ToolName is not installed, skipping"
        return $true
    }
    
    if ($WhatIf) {
        Write-Info "WHAT-IF: Would uninstall $ToolName"
        return $true
    }
    
    Write-Info "Uninstalling $ToolName..."
    
    $success = $false
    
    # Try winget first
    try {
        $result = winget uninstall --id $WingetId --silent --accept-source-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$ToolName uninstalled successfully via winget"
            $success = $true
        } else {
            Write-Warning "Winget uninstall failed (exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Warning "Winget uninstall error: $($_.Exception.Message)"
    }
    
    # If winget failed and custom uninstaller exists, try it
    if (-not $success -and $CustomUninstall) {
        try {
            Write-Info "Trying custom uninstall method for $ToolName..."
            & $CustomUninstall
            if ($LASTEXITCODE -eq 0 -or $?) {
                Write-Success "$ToolName uninstalled successfully via custom method"
                $success = $true
            } else {
                Write-Warning "Custom uninstall failed"
            }
        } catch {
            Write-Warning "Custom uninstall error: $($_.Exception.Message)"
        }
    }
    
    # Verify uninstallation
    Start-Sleep -Seconds 2
    if (Test-ToolInstalled $ToolName) {
        Write-Warning "$ToolName may still be accessible (restart terminal or system may be required)"
        # Don't mark as failed if tool is still accessible - it might just need a refresh
    }
    
    if (-not $success) {
        Write-ErrorMsg "Failed to uninstall ${ToolName} - tried all available methods"
    }
    
    return $success
}

# Banner
Write-Host ""
Write-Host "===============================================================================" -ForegroundColor Blue
Write-Host "                  strangeloop Development Tools Uninstaller" -ForegroundColor Blue
Write-Host "===============================================================================" -ForegroundColor Blue
Write-Host ""

# Show what will be uninstalled
Write-Info "Tools to uninstall: $($Tools -join ', ')"
if ($WhatIf) {
    Write-Warning "Running in WhatIf mode - no actual changes will be made"
}
Write-Host ""

# Confirmation prompt
if (-not $SkipConfirmation -and -not $WhatIf) {
    Write-Warning "This will uninstall the selected development tools from your system."
    if (-not $KeepConfigurations) {
        Write-Warning "User configurations and data may also be removed."
    }
    Write-Host ""
    
    $response = Read-Host "Continue with uninstallation? (yes/no)"
    if ($response -ne "yes") {
        Write-Info "Uninstallation cancelled"
        exit 0
    }
    Write-Host ""
}

# Track results
$results = @{}

# Uninstall each tool
foreach ($tool in $Tools) {
    switch ($tool) {
        "Git" {
            $results["Git"] = Uninstall-Tool -ToolName "Git" -WingetId "Git.Git"
        }
        "Docker" {
            $results["Docker"] = Uninstall-Tool -ToolName "Docker Desktop" -WingetId "Docker.DockerDesktop"
        }
        "Python" {
            $results["Python"] = Uninstall-Tool -ToolName "Python" -WingetId "Python.Python.3.12"
        }
        "Poetry" {
            # Custom uninstall for Poetry since it's not typically installed via winget
            $poetryCustomUninstall = {
                $poetryCmd = Get-Command poetry -ErrorAction SilentlyContinue
                if ($poetryCmd) {
                    $poetryPath = $poetryCmd.Source
                    $poetryDir = Split-Path (Split-Path $poetryPath)
                    if (Test-Path $poetryDir) {
                        Remove-Item -Recurse -Force $poetryDir -ErrorAction Stop
                        return $true
                    }
                }
                return $false
            }
            $results["Poetry"] = Uninstall-Tool -ToolName "Poetry" -WingetId "Python.Poetry" -CustomUninstall $poetryCustomUninstall
        }
        "GitLFS" {
            $results["GitLFS"] = Uninstall-Tool -ToolName "Git LFS" -WingetId "GitHub.GitLFS"
        }
        "WSL" {
            # Custom uninstall for WSL - unregister all distributions
            $wslCustomUninstall = {
                Write-Info "Listing WSL distributions..."
                $distros = wsl --list --quiet 2>$null | Where-Object { $_ -and $_.Trim() }
                
                if ($distros) {
                    foreach ($distro in $distros) {
                        $distroName = $distro.Trim() -replace '\x00', '' # Remove null characters
                        if ($distroName) {
                            Write-Info "Unregistering WSL distribution: $distroName"
                            wsl --unregister $distroName 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Unregistered: $distroName"
                            } else {
                                Write-Warning "Failed to unregister: $distroName"
                            }
                        }
                    }
                    return $true
                } else {
                    Write-Info "No WSL distributions found"
                    return $true
                }
            }
            $results["WSL"] = & $wslCustomUninstall
        }
    }
    Write-Host ""
}

# Summary
Write-Host "===============================================================================" -ForegroundColor Blue
Write-Host "                           Uninstallation Summary" -ForegroundColor Blue
Write-Host "===============================================================================" -ForegroundColor Blue
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($tool in $results.Keys) {
    if ($results[$tool]) {
        Write-Success "${tool}: Uninstalled"
        $successCount++
    } else {
        Write-ErrorMsg "${tool}: Failed"
        $failCount++
    }
}

Write-Host ""
Write-Info "Total: $successCount succeeded, $failCount failed"
Write-Host ""

if (-not $WhatIf) {
    Write-Warning "Note: You may need to restart your terminal or system for changes to take full effect"
    Write-Host ""
}

# Exit with appropriate code
if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}

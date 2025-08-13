# StrangeLoop CLI Setup Script - Single Script Version
# Complete standalone setup for StrangeLoop CLI development environment
# 
# Author: [StrangeLoop Team]
# Version: 7.0 - Enhanced Enterprise Edition
# Created: August 2025
# Last Updated: August 13, 2025
# 
# This standalone script provides complete StrangeLoop CLI setup with automatic
# prerequisite checks and package updates for maximum simplicity.
#
# Features:
# - Centralized Git credential capture
# - Background Git LFS installation with auto-elevation
# - Azure CLI authentication integration
# - Group Policy compliance for corporate environments
# - WSL/Ubuntu 24.04 automatic setup
# - Comprehensive error handling and fallbacks
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+
# Execution Policy: Automatically handled
#
# Usage: .\setup_strangeloop.ps1 [-Verbose]

param(
    [switch]$Verbose
)

# Check and handle execution policy first (before any other operations)
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted") {
    Write-Host "Execution policy is Restricted. Setting to RemoteSigned for script execution..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "✓ Execution policy updated to RemoteSigned" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set execution policy. Please run the following command manually:" -ForegroundColor Red
        Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" -ForegroundColor Yellow
        Write-Host "Then run this script again." -ForegroundColor Yellow
        exit 1
    }
}

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Display banner
Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║              StrangeLoop CLI Setup - Complete Setup           ║
║                    Version 7.3 - Enhanced Enterprise          ║
║                         Unified Architecture                  ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host " " -ForegroundColor White
Write-Host "StrangeLoop CLI Bootstrap Setup (Complete)" -ForegroundColor White
Write-Host "Version 7.0 - Enhanced Enterprise Edition" -ForegroundColor Cyan
Write-Host "This script will install and configure StrangeLoop CLI with environment-specific delegation" -ForegroundColor Gray
Write-Host " " -ForegroundColor White

#region Helper Functions

# Global variables for tracking display state
$script:LastShownDistribution = ""

# Helper function to execute commands with duration tracking
function Invoke-CommandWithDuration {
    param(
        [string]$Command,
        [string]$Description,
        [scriptblock]$ScriptBlock
    )
    
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $Description..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    try {
        if ($ScriptBlock) {
            $result = & $ScriptBlock
        } else {
            $result = Invoke-Expression $Command
        }
        
        $duration = (Get-Date).Subtract($startTime).TotalSeconds.ToString('F1')
        Write-Host "  ✓ Complete! Duration: ${duration}s" -ForegroundColor Green
        return $result
    } catch {
        $duration = (Get-Date).Subtract($startTime).TotalSeconds.ToString('F1')
        Write-Host "  ✗ Failed! Duration: ${duration}s" -ForegroundColor Red
        throw
    }
}

function Write-Step {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host " " -ForegroundColor White
    Write-Host "=== $Message ===" -ForegroundColor $Color
    Write-Host " " -ForegroundColor White
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor White
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Write-WSLCommand {
    param([string]$Command)
    if ($Verbose) {
        Write-Host "[WSL CMD] $Command" -ForegroundColor Cyan
    }
}

# Helper function to check background Git LFS installation status
function Test-BackgroundGitLfsInstallation {
    # Check if background installation was started (with proper variable existence check)
    if (-not (Get-Variable -Name "GitLfsInstallStarted" -Scope Global -ErrorAction SilentlyContinue)) {
        $global:GitLfsInstallStarted = $false
    }
    
    if ($global:GitLfsInstallStarted) {
        Write-Info "Checking background Git LFS installation status..."
        
        # Check if the elevated process has completed
        if ($global:GitLfsElevatedProcess -and -not $global:GitLfsElevatedProcess.HasExited) {
            Write-Info "Git LFS installation still running in background. Waiting..."
            $global:GitLfsElevatedProcess.WaitForExit(30000)  # Wait up to 30 seconds
        }
        
        # Check result file
        $resultFile = "$env:TEMP\git-lfs-install-result.txt"
        if (Test-Path $resultFile) {
            $result = Get-Content $resultFile -ErrorAction SilentlyContinue
            Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
            
            if ($result -eq "SUCCESS") {
                Write-Success "Background Git LFS installation completed successfully"
                
                # Refresh PATH and initialize Git LFS
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Start-Sleep -Seconds 2
                
                if (Test-Command "git-lfs") {
                    git lfs install --force 2>$null
                    Write-Success "Git LFS initialized"
                    return $true
                }
            } elseif ($result -eq "FAILED") {
                Write-Warning "Background Git LFS installation failed"
            }
        }
        
        # Clean up temp script
        Remove-Item "$env:TEMP\install-git-lfs-elevated.ps1" -Force -ErrorAction SilentlyContinue
        
        # Final check if Git LFS is available
        if (Test-Command "git-lfs") {
            Write-Success "Git LFS is available"
            git lfs install --force 2>$null
            return $true
        } else {
            Write-Warning "Git LFS not found after background installation"
            return $false
        }
    }
    
    # If no background installation was started, just check if Git LFS is available
    if (Test-Command "git-lfs") {
        return $true
    }
    
    return $false
}

# Helper function to execute commands with duration tracking (like original script)
function Invoke-CommandWithDuration {
    param(
        [string]$Command,
        [string]$Description,
        [scriptblock]$ScriptBlock
    )
    
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $Description..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    try {
        if ($ScriptBlock) {
            $result = & $ScriptBlock
        } else {
            $result = Invoke-Expression $Command
        }
        
        $duration = (Get-Date).Subtract($startTime).TotalSeconds.ToString('F1')
        Write-Host "  ✓ Complete! Duration: ${duration}s" -ForegroundColor Green
        return $result
    } catch {
        $duration = (Get-Date).Subtract($startTime).TotalSeconds.ToString('F1')
        Write-Host "  ✗ Failed! Duration: ${duration}s" -ForegroundColor Red
        throw
    }
}

function Test-WSLInstallation {
    param([string]$DistributionName = "Ubuntu-24.04")
    
    Write-Info "Validating WSL installation and $DistributionName distribution..."
    
    # Check if WSL command exists
    if (-not (Test-Command "wsl")) {
        Write-Warning "WSL command not found in PATH"
        return $false
    }
    
    # Check WSL version and status
    try {
        Write-WSLCommand "wsl --version"
        $wslVersion = wsl --version 2>$null
        if ($wslVersion) {
            Write-Success "WSL is installed and operational"
        } else {
            Write-Warning "WSL command exists but may not be fully functional"
            return $false
        }
    } catch {
        Write-Warning "WSL version check failed: $($_.Exception.Message)"
        return $false
    }
    
    # Check if the specific distribution is installed and functional
    try {
        Write-WSLCommand "wsl --list --quiet"
        $distributions = wsl --list --quiet 2>$null
        $distroFound = $false
        
        if ($distributions) {
            foreach ($line in $distributions) {
                if ($line -and $line -notmatch "^Windows Subsystem") {
                    $cleanLine = $line -replace '[^\x20-\x7F]', ''
                    if ($cleanLine -like "*$DistributionName*") {
                        $distroFound = $true
                        break
                    }
                }
            }
        }
        
        if ($distroFound) {
            # Test if we can execute commands in the distribution
            try {
                Write-WSLCommand "wsl --distribution $DistributionName --exec echo `"test`""
                $testResult = wsl --distribution $DistributionName --exec echo "test"
                if ($testResult -eq "test") {
                    Write-Success "$DistributionName is installed and functional"
                    return $true
                } else {
                    Write-Warning "$DistributionName found but command execution failed"
                    return $false
                }
            } catch {
                Write-Warning "$DistributionName found but not accessible: $($_.Exception.Message)"
                return $false
            }
        } else {
            Write-Info "$DistributionName distribution not found in current WSL installations"
            return $false
        }
    } catch {
        Write-Warning "WSL distribution check failed: $($_.Exception.Message)"
        return $false
    }
}

function Repair-WSLInstallation {
    param([string]$DistributionName = "Ubuntu-24.04")
    
    Write-Info "Attempting to repair WSL installation..."
    
    $repairSuccess = $false
    
    # Method 1: Reset WSL
    Write-Info "Attempting WSL reset..."
    try {
        Write-WSLCommand "wsl --shutdown"
        wsl --shutdown
        Start-Sleep -Seconds 3
        Write-WSLCommand "wsl --set-default-version 2"
        wsl --set-default-version 2
        Write-Success "WSL reset completed"
        $repairSuccess = $true
    } catch {
        Write-Warning "WSL reset failed: $($_.Exception.Message)"
    }
    
    # Method 2: Restart WSL service
    if (-not $repairSuccess) {
        Write-Info "Attempting to restart WSL service..."
        try {
            Restart-Service -Name "LxssManager" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            Write-Success "WSL service restarted"
            $repairSuccess = $true
        } catch {
            Write-Warning "WSL service restart failed: $($_.Exception.Message)"
        }
    }
    
    # Method 3: Re-register distribution
    if (-not $repairSuccess -and $DistributionName) {
        Write-Info "Attempting to re-register $DistributionName distribution..."
        try {
            Write-WSLCommand "wsl --unregister $DistributionName"
            wsl --unregister $DistributionName 2>$null
            Start-Sleep -Seconds 2
            Write-WSLCommand "wsl --install --distribution $DistributionName --no-launch"
            wsl --install --distribution $DistributionName --no-launch
            Write-Success "$DistributionName re-registration initiated"
            $repairSuccess = $true
        } catch {
            Write-Warning "Distribution re-registration failed: $($_.Exception.Message)"
        }
    }
    
    return $repairSuccess
}

function Initialize-UbuntuDistribution {
    param([string]$DistributionName = "Ubuntu-24.04")
    
    Write-Info "Checking if $DistributionName needs initial setup..."
    
    try {
        # Try to run a simple command to see if the distribution is initialized
        Write-WSLCommand "wsl --distribution $DistributionName --exec echo `"test`""
        $testResult = wsl --distribution $DistributionName --exec echo "test" 2>$null
        
        if ($testResult -eq "test") {
            Write-Success "$DistributionName is already initialized and ready"
            return $true
        } else {
            Write-Info "$DistributionName needs initial user setup"
            Write-Warning "Ubuntu will launch for initial user account creation."
            Write-Info "Please:"
            Write-Info "1. Create a username when prompted"
            Write-Info "2. Set a password when prompted" 
            Write-Info "3. Close the Ubuntu window when setup is complete"
            Write-Info "4. This script will continue automatically"
            
            # Launch Ubuntu for initial setup with a timeout
            Write-Info "Launching Ubuntu for setup in 3 seconds..."
            Start-Sleep -Seconds 3
            
            # Use Start-Process to launch Ubuntu without blocking
            Start-Process -FilePath "wsl" -ArgumentList "--distribution", $DistributionName -NoNewWindow:$false
            
            # Wait for the process to start and user to complete setup
            Write-Info "Waiting for Ubuntu setup to complete..."
            Write-Info "Please complete the setup in the Ubuntu window that opened."
            
            # Check periodically if setup is complete
            $maxWaitTime = 300  # 5 minutes
            $waitTime = 0
            $setupComplete = $false
            
            while ($waitTime -lt $maxWaitTime -and -not $setupComplete) {
                Start-Sleep -Seconds 10
                $waitTime += 10
                
                try {
                    Write-WSLCommand "wsl --distribution $DistributionName --exec echo `"test`""
                    $testResult = wsl --distribution $DistributionName --exec echo "test" 2>$null
                    if ($testResult -eq "test") {
                        $setupComplete = $true
                        Write-Success "Ubuntu setup completed successfully!"
                        break
                    }
                } catch {
                    # Setup still in progress
                }
                
                if ($waitTime % 30 -eq 0) {
                    Write-Info "Still waiting for Ubuntu setup... ($waitTime seconds elapsed)"
                }
            }
            
            if (-not $setupComplete) {
                Write-Warning "Ubuntu setup is taking longer than expected."
                Write-Info "Please ensure you complete the setup in the Ubuntu window."
                $response = Read-Host "Press Enter when Ubuntu setup is complete, or type 'skip' to continue without Ubuntu"
                
                if ($response -eq "skip") {
                    Write-Warning "Skipping Ubuntu setup. Some features may not work."
                    return $false
                }
                
                # Test one more time
                try {
                    Write-WSLCommand "wsl --distribution $DistributionName --exec echo `"test`""
                    $testResult = wsl --distribution $DistributionName --exec echo "test" 2>$null
                    if ($testResult -eq "test") {
                        Write-Success "Ubuntu setup completed!"
                        return $true
                    } else {
                        Write-Warning "Ubuntu setup verification failed. Continuing anyway..."
                        return $false
                    }
                } catch {
                    Write-Warning "Ubuntu setup verification failed. Continuing anyway..."
                    return $false
                }
            }
            
            return $setupComplete
        }
    } catch {
        Write-Warning "Failed to check Ubuntu initialization status: $($_.Exception.Message)"
        return $false
    }
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    if ($Default) {
        $response = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $Default
        }
        return $response
    } else {
        return Read-Host $Prompt
    }
}

function Test-WSL {
    try {
        Write-WSLCommand "wsl --version"
        $wslVersion = wsl --version 2>$null
        return $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($wslVersion)
    } catch {
        return $false
    }
}

function Resolve-WSLPath {
    param(
        [string]$Path,
        [string]$Distribution = ""
    )
    
    # Handle placeholder resolution first
    if ($Path -match '\$\(whoami\)') {
        $whoamiCommand = if ($Distribution) { "wsl -d $Distribution -- whoami" } else { "wsl -- whoami" }
        try {
            $actualUser = Invoke-Expression $whoamiCommand
            if ($actualUser) {
                $actualUser = $actualUser.Trim()
                $Path = $Path -replace '\$\(whoami\)', $actualUser
            }
        } catch {
            # Silently continue if whoami resolution fails
        }
    }
    
    return $Path
}

function Install-RecommendedVSCodeExtensions {
    param([bool]$IsWSL = $false)
    
    Write-Info "Checking for recommended VS Code extensions..."
    
    try {
        # Check if VS Code is installed
        if (-not (Test-Command "code")) {
            Write-Warning "VS Code CLI not found in PATH. Skipping extension check."
            return $false
        }
        
        # Get list of currently installed extensions
        $installedExtensions = @(code --list-extensions 2>$null)
        
        # Define recommended extensions for StrangeLoop development
        $recommendedExtensions = @(
            @{ Id = "ms-python.python"; Name = "Python"; Required = $true },
            @{ Id = "ms-vscode.powershell"; Name = "PowerShell"; Required = $false },
            @{ Id = "ms-dotnettools.csharp"; Name = "C# Dev Kit"; Required = $false },
            @{ Id = "bradlc.vscode-tailwindcss"; Name = "Tailwind CSS IntelliSense"; Required = $false }
        )
        
        # Add WSL extension if working with WSL
        if ($IsWSL) {
            $recommendedExtensions += @{ Id = "ms-vscode-remote.remote-wsl"; Name = "WSL"; Required = $true }
        }
        
        $extensionsToInstall = @()
        
        foreach ($ext in $recommendedExtensions) {
            if ($installedExtensions -notcontains $ext.Id) {
                if ($ext.Required) {
                    $extensionsToInstall += $ext
                } else {
                    Write-Info "Optional extension available: $($ext.Name) ($($ext.Id))"
                }
            } else {
                Write-Success "$($ext.Name) extension is already installed"
            }
        }
        
        # Install required extensions
        foreach ($ext in $extensionsToInstall) {
            if ($ext.Required) {
                Write-Info "Installing required extension: $($ext.Name)..."
                $installResult = code --install-extension $ext.Id --force 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$($ext.Name) extension installed successfully"
                } else {
                    Write-Warning "Failed to install $($ext.Name) extension"
                    Write-Info "Install result: $installResult"
                }
            }
        }
        
        return $true
    } catch {
        Write-Warning "Error checking/installing extensions: $($_.Exception.Message)"
        return $false
    }
}

function Install-VSCodeWSLExtension {
    Write-Info "Checking for WSL extension in VS Code..."
    
    try {
        # Check if VS Code is installed
        if (-not (Test-Command "code")) {
            Write-Warning "VS Code CLI not found in PATH. Please ensure VS Code is installed."
            return $false
        }
        
        # Check if WSL extension is already installed
        $installedExtensions = code --list-extensions 2>$null
        if ($installedExtensions -contains "ms-vscode-remote.remote-wsl") {
            Write-Success "WSL extension is already installed"
            return $true
        }
        
        Write-Info "Installing WSL extension for VS Code..."
        $installResult = code --install-extension ms-vscode-remote.remote-wsl --force 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL extension installed successfully"
            return $true
        } else {
            Write-Warning "Failed to install WSL extension automatically"
            Write-Info "Install result: $installResult"
            Write-Info "You can manually install it from: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl"
            return $false
        }
    } catch {
        Write-Warning "Error checking/installing WSL extension: $($_.Exception.Message)"
        Write-Info "You can manually install the WSL extension from VS Code marketplace"
        return $false
    }
}

function Open-VSCode {
    param(
        [string]$Path,
        [bool]$IsWSL,
        [string]$Distribution = ""
    )
    
    Write-Info "Opening VS Code for path: $Path"
    
    # Check and install recommended VS Code extensions
    Write-Info "Checking VS Code extensions for optimal development experience..."
    Install-RecommendedVSCodeExtensions -IsWSL:$IsWSL | Out-Null
    
    try {
        if ($IsWSL) {
            # For WSL, execute code command from within WSL itself, ensuring we're in the right directory
            if ($Distribution) {
                Write-Info "Launching VS Code from within WSL ($Distribution)"
                # Use absolute path and ensure we change to the directory first
                $wslCommand = "cd '$Path' `&`& pwd `&`& code ."
                $result = wsl -d $Distribution -- bash -c $wslCommand
                Write-Info "WSL command result: $result"
            } else {
                Write-Info "Launching VS Code from within default WSL"
                # Use absolute path and ensure we change to the directory first
                $wslCommand = "cd '$Path' `&`& pwd `&`& code ."
                $result = wsl -- bash -c $wslCommand
                Write-Info "WSL command result: $result"
            }
        } else {
            # For Windows, use standard path
            Write-Info "Opening in Windows mode"
            Write-Info "Tip: Consider installing VS Code WSL extension for future WSL development"
            Start-Process -FilePath "code" -ArgumentList @($Path) -NoNewWindow
        }
        Write-Success "VS Code launched for project"
    } catch {
        Write-Warning "Could not automatically open VS Code: $($_.Exception.Message)"
        Write-Info "You can manually open VS Code and navigate to: $Path"
        if ($IsWSL) {
            if ($Distribution) {
                Write-Info "Manual command: wsl -d $Distribution -- bash -c `"cd '$Path' `&`& code .`""
            } else {
                Write-Info "Manual command: wsl -- bash -c `"cd '$Path' `&`& code .`""
            }
        }
    }
}


function Invoke-WSLCommand {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Command,
        
        [Parameter(Position=1)]
        [string]$Description,
        
        [Parameter(Position=2)]
        [string]$Distribution = "",
        
        [Parameter(Position=3)]
        [SecureString]$SudoPassword = $null,
        
        [Parameter()]
        [scriptblock]$ScriptBlock
    )
    
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $Description..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    # Only show target distribution if it's different from the last shown one
    if ($Distribution) {
        $targetDisplay = $Distribution
        if ($script:LastShownDistribution -ne $targetDisplay) {
            Write-Host "  Target: $targetDisplay" -ForegroundColor Gray
            $script:LastShownDistribution = $targetDisplay
        }
    }
    
    try {
        if ($ScriptBlock) {
            # Execute script block in WSL context by converting commands
            $scriptContent = $ScriptBlock.ToString()
            $distroParam = if ($Distribution) { "-d $Distribution" } else { "" }
            
            # Handle sudo commands with password if provided
            if ($SudoPassword -and $scriptContent -match "sudo ") {
                $plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SudoPassword))
                # Replace sudo commands in script content
                $scriptContent = $scriptContent -replace "sudo ", "echo '$plaintextPassword' | sudo -S "
            }
            
            $wslCommand = "wsl $distroParam -- bash -c `"$scriptContent`""
            Write-WSLCommand $wslCommand
            $result = Invoke-Expression $wslCommand 2>&1
        } else {
            # Single command execution (legacy support)
            $distroParam = if ($Distribution) { "-d $Distribution" } else { "" }
            
            if ($SudoPassword -and $Command.StartsWith("sudo ")) {
                $plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SudoPassword))
                $sudoCommand = $Command -replace "^sudo ", ""
                $commandWithPassword = "echo '$plaintextPassword' | sudo -S $sudoCommand"
                $wslCommand = "wsl $distroParam -- bash -c `"$commandWithPassword`""
                Write-WSLCommand "wsl $distroParam -- bash -c `"echo '[SUDO]' | sudo -S $sudoCommand`""
            } else {
                $wslCommand = "wsl $distroParam -- bash -c `"$Command`""
                Write-WSLCommand $wslCommand
            }
            
            $result = Invoke-Expression $wslCommand 2>&1
        }
        
        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        Write-Host "  ✓ Complete! Duration: ${duration}s" -ForegroundColor Green
        return $result
    } catch {
        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        Write-Host "  ✗ Failed! Duration: ${duration}s" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to execute WSL command and return output
function Get-WSLCommandOutput {
    param([string]$Command, [string]$Distribution = "")
    try {
        $distroParam = if ($Distribution) { "-d $Distribution" } else { "" }
        $wslCommand = "wsl $distroParam -- bash -c `"$Command`""
        Write-WSLCommand $wslCommand
        $result = Invoke-Expression $wslCommand 2>&1
        
        if ($result -is [array]) {
            return $result -join "`n"
        } else {
            return $result
        }
    } catch {
        Write-Host "`n  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get and verify sudo password for WSL
function Get-SudoPassword {
    param([string]$Distribution = "")
    
    Write-Host "  Checking sudo access for WSL operations..." -ForegroundColor Yellow
    
    # First, check if we can run sudo without password (passwordless sudo)
    $sudoCheck = Get-WSLCommandOutput "sudo -n true 2>/dev/null && echo 'NOPASSWD' || echo 'PASSWD_REQUIRED'" $Distribution
    
    if ($sudoCheck -eq "NOPASSWD") {
        Write-Success "Passwordless sudo access confirmed"
        return $null
    }
    
    Write-Host "  Sudo password is required for package management operations." -ForegroundColor Yellow
    $securePassword = Read-Host "Please enter your WSL sudo password (input will be hidden)" -AsSecureString
    
    if ($securePassword.Length -eq 0) {
        Write-Error "No password provided. Sudo operations will be skipped."
        return $null
    }
    
    # Convert SecureString to plain text for verification
    $plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    
    # Test the password
    $testResult = Get-WSLCommandOutput "echo '$plaintextPassword' | sudo -S true 2>/dev/null && echo 'SUCCESS' || echo 'FAILED'" $Distribution
    
    if ($testResult -eq "SUCCESS") {
        Write-Success "Sudo password verified"
        return $securePassword
    } else {
        Write-Error "Invalid sudo password. Please check your password and try again."
        return $null
    }
}

# Function to download script content from GitHub
function Get-ScriptFromUrl {
    param([string]$Url, [string]$ScriptName)
    
    Write-Info "Downloading $ScriptName from GitHub..."
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Success "$ScriptName downloaded successfully"
            return $response.Content
        } else {
            throw "HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Error "Failed to download $ScriptName from $Url"
        Write-Error "Error: $($_.Exception.Message)"
        throw
    }
}

#endregion

#region Prerequisites Check

Write-Step "Checking Prerequisites"

# Check PowerShell version
Invoke-CommandWithDuration -Description "Checking PowerShell version" -ScriptBlock {
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
        Write-Error "PowerShell 5.1 or higher is required. Current version: $($psVersion.ToString())"
        exit 1
    }
    Write-Success "PowerShell version: $($psVersion.ToString())"
}
    
# Check execution policy
Invoke-CommandWithDuration -Description "Checking execution policy" -ScriptBlock {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    $allowedPolicies = @("RemoteSigned", "Unrestricted", "Bypass")
    if ($currentPolicy -notin $allowedPolicies) {
        Write-Warning "Current execution policy '$currentPolicy' may prevent script execution"
        Write-Info "Attempting to set execution policy to RemoteSigned for current user..."
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Success "Execution policy updated to RemoteSigned"
        } catch {
            Write-Error "Failed to update execution policy. Please run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
            exit 1
        }
    } else {
        Write-Success "Execution policy '$currentPolicy' is suitable for development"
    }
}
    
# Check basic tools
$requiredTools = @("git", "curl", "az")
foreach ($tool in $requiredTools) {
    if (Test-Command $tool) {
        Write-Success "$tool is available"
    } else {
        Write-Warning "$tool is not installed - will install during setup"
    }
}

#endregion

#region Git Credential Capture

# Capture Git credentials once at the beginning for use throughout the script
Write-Step "Git User Configuration"

if (Test-Command "git") {
    Write-Info "Configuring Git user information for use throughout setup..."
    
    # Get current Git configuration
    $currentEmail = git config --global user.email 2>$null
    $currentName = git config --global user.name 2>$null
    
    # Prompt for Git user information with defaults from existing config
    if ([string]::IsNullOrWhiteSpace($currentEmail)) {
        $global:GitUserEmail = Get-UserInput "Enter your Git email address"
    } else {
        $global:GitUserEmail = Get-UserInput "Git email address" $currentEmail
    }
    
    if ([string]::IsNullOrWhiteSpace($currentName)) {
        $global:GitUserName = Get-UserInput "Enter your Git display name"
    } else {
        $global:GitUserName = Get-UserInput "Git display name" $currentName
    }
    
    Write-Success "Git user configured: $global:GitUserName <$global:GitUserEmail>"
    Write-Info "These credentials will be used for both Windows and WSL Git configuration"
} else {
    Write-Warning "Git not found - will configure credentials after Git installation"
    $global:GitUserEmail = ""
    $global:GitUserName = ""
}

#endregion

#region Git Configuration

# Configure Git for development
if (Test-Command "git") {
    Write-Step "Git Configuration"
    
    # If Git credentials weren't captured earlier (Git wasn't available), capture them now
    if ([string]::IsNullOrWhiteSpace($global:GitUserEmail) -or [string]::IsNullOrWhiteSpace($global:GitUserName)) {
        Write-Info "Git credentials not captured earlier - configuring now..."
        
        # Get current Git configuration
        $currentEmail = git config --global user.email 2>$null
        $currentName = git config --global user.name 2>$null
        
        # Prompt for Git user information with defaults from existing config
        if ([string]::IsNullOrWhiteSpace($currentEmail)) {
            $global:GitUserEmail = Get-UserInput "Enter your Git email address"
        } else {
            $global:GitUserEmail = Get-UserInput "Git email address" $currentEmail
        }
        
        if ([string]::IsNullOrWhiteSpace($currentName)) {
            $global:GitUserName = Get-UserInput "Enter your Git display name"
        } else {
            $global:GitUserName = Get-UserInput "Git display name" $currentName
        }
        
        Write-Success "Git user configured: $global:GitUserName <$global:GitUserEmail>"
    }
    
    # Use the globally captured Git credentials
    Write-Info "Configuring Git settings..."
    git config --global user.email $global:GitUserEmail
    git config --global user.name $global:GitUserName
    git config --global init.defaultBranch "main"
    
    # Clear any existing credential helpers and set the correct one
    git config --global --unset-all credential.helper 2>$null
    
    # Find and configure Git Credential Manager
    $credentialManagerPaths = @(
        "C:\Program Files\Git\mingw64\bin\git-credential-manager.exe",
        "C:\Program Files\Git\mingw64\libexec\git-core\git-credential-manager.exe",
        "C:\Program Files\Git\mingw64\libexec\git-core\git-credential-manager-core.exe"
    )
    
    $credentialManager = $null
    foreach ($path in $credentialManagerPaths) {
        if (Test-Path $path) {
            $credentialManager = $path
            break
        }
    }
    
    if ($credentialManager) {
        git config --global credential.helper "`"$credentialManager`""
        Write-Info "Git credential manager configured: $credentialManager"
    } else {
        Write-Warning "Git Credential Manager not found. Authentication may fail."
    }
    
    git config --global credential.useHttpPath true
    git config --global merge.tool vscode
    git config --global mergetool.vscode.cmd 'code --wait $MERGED'
    git config --global core.longpaths true
    
    Write-Success "Git configured with user: $global:GitUserName <$global:GitUserEmail>"
    
    # Install Git LFS if not available
    if (-not (Test-Command "git-lfs")) {
        Write-Info "Installing Git LFS..."
        try {
            # Try chocolatey first if available
            if (Test-Command "choco") {
                Write-Info "Attempting Git LFS installation via Chocolatey..."
                
                # Check if running as administrator
                $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                
                if (-not $isAdmin) {
                    Write-Warning "Chocolatey requires administrator privileges for package installation."
                    Write-Info "Launching elevated PowerShell window to install Git LFS in background..."
                    
                    try {
                        # Create a script to run in elevated session
                        $elevatedScript = @"
Write-Host "Installing Git LFS via Chocolatey (Elevated Session)..." -ForegroundColor Green
choco install git-lfs -y
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Git LFS installed successfully via Chocolatey" -ForegroundColor Green
    # Create success marker file
    "SUCCESS" | Out-File -FilePath "$env:TEMP\git-lfs-install-result.txt" -Encoding UTF8
} else {
    Write-Host "Git LFS installation failed via Chocolatey" -ForegroundColor Red
    "FAILED" | Out-File -FilePath "$env:TEMP\git-lfs-install-result.txt" -Encoding UTF8
}
Write-Host "Installation process completed. You can close this window." -ForegroundColor Yellow
"@
                        
                        # Save the script to a temporary file
                        $tempScript = "$env:TEMP\install-git-lfs-elevated.ps1"
                        $elevatedScript | Out-File -FilePath $tempScript -Encoding UTF8
                        
                        # Remove any existing result file
                        Remove-Item "$env:TEMP\git-lfs-install-result.txt" -Force -ErrorAction SilentlyContinue
                        
                        # Launch elevated PowerShell in background
                        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                        $processInfo.FileName = "powershell.exe"
                        $processInfo.Arguments = "-ExecutionPolicy Bypass -File `"$tempScript`""
                        $processInfo.Verb = "runas"
                        $processInfo.UseShellExecute = $true
                        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
                        
                        Write-Host "Please complete the UAC prompt to install Git LFS in background..." -ForegroundColor Yellow
                        $process = [System.Diagnostics.Process]::Start($processInfo)
                        
                        # Continue with script while installation runs in background
                        Write-Info "Git LFS installation started in background. Continuing with setup..."
                        Write-Info "Will check installation status later in the process."
                        
                        # Store process info for later checking
                        $global:GitLfsElevatedProcess = $process
                        $global:GitLfsInstallStarted = $true
                        
                    } catch {
                        Write-Warning "Failed to start elevated Git LFS installation: $($_.Exception.Message)"
                        Write-Info "Falling back to direct download method..."
                        
                        # Direct download fallback
                        Write-Info "Installing Git LFS via direct download..."
                        $gitLfsUrl = "https://github.com/git-lfs/git-lfs/releases/download/v3.4.0/git-lfs-windows-amd64-v3.4.0.exe"
                        $gitLfsInstaller = "$env:TEMP\git-lfs-installer.exe"
                        Invoke-WebRequest -Uri $gitLfsUrl -OutFile $gitLfsInstaller -UseBasicParsing
                        Start-Process -FilePath $gitLfsInstaller -ArgumentList "/SILENT" -Wait
                        Remove-Item $gitLfsInstaller -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    # Already running as admin, proceed with Chocolatey
                    $chocoResult = choco install git-lfs -y 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Git LFS installed via Chocolatey"
                    } else {
                        Write-Warning "Chocolatey installation failed: $chocoResult"
                        Write-Info "Falling back to direct download method..."
                        
                        # Direct download fallback
                        Write-Info "Installing Git LFS via direct download..."
                        $gitLfsUrl = "https://github.com/git-lfs/git-lfs/releases/download/v3.4.0/git-lfs-windows-amd64-v3.4.0.exe"
                        $gitLfsInstaller = "$env:TEMP\git-lfs-installer.exe"
                        Invoke-WebRequest -Uri $gitLfsUrl -OutFile $gitLfsInstaller -UseBasicParsing
                        Start-Process -FilePath $gitLfsInstaller -ArgumentList "/SILENT" -Wait
                        Remove-Item $gitLfsInstaller -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                # Direct download method
                Write-Info "Installing Git LFS via direct download..."
                $gitLfsUrl = "https://github.com/git-lfs/git-lfs/releases/download/v3.4.0/git-lfs-windows-amd64-v3.4.0.exe"
                $gitLfsInstaller = "$env:TEMP\git-lfs-installer.exe"
                Invoke-WebRequest -Uri $gitLfsUrl -OutFile $gitLfsInstaller -UseBasicParsing
                Start-Process -FilePath $gitLfsInstaller -ArgumentList "/SILENT" -Wait
                Remove-Item $gitLfsInstaller -Force -ErrorAction SilentlyContinue
            }
            
            # Refresh PATH and initialize Git LFS
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            # Wait a moment for PATH to refresh and verify Git LFS installation
            Start-Sleep -Seconds 2
            
            if (Test-Command "git-lfs") {
                git lfs install --force 2>$null
                Write-Success "Git LFS installed and initialized"
            } elseif (Test-Command "git") {
                # Try to initialize anyway in case git-lfs is available but not in PATH
                $gitLfsTest = git lfs version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    git lfs install --force 2>$null
                    Write-Success "Git LFS found and initialized"
                } else {
                    Write-Warning "Git LFS installation may not be complete. Please restart your terminal."
                }
            }
        } catch {
            Write-Warning "Failed to install Git LFS automatically: $($_.Exception.Message)"
            Write-Info "Please install Git LFS manually:"
            Write-Info "1. Download from: https://git-lfs.github.io/"
            Write-Info "2. Run the installer (may require Administrator privileges)"
            Write-Info "3. Restart your terminal and run this script again"
            Write-Info ""
            Write-Info "Alternative: Run this script as Administrator to enable Chocolatey installation"
        }
    } else {
        Write-Success "Git LFS is already available"
        git lfs install --force 2>$null
    }
}

#endregion

#region StrangeLoop Installation

Write-Step "Azure Authentication and StrangeLoop Installation"

# Check and install Azure CLI if needed
if (Test-Command "az") {
    Write-Success "Azure CLI is already installed"
    $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
    if ($azVersion) {
        Write-Info "Current version: $azVersion"
    }
} else {
    Write-Info "Azure CLI not found - installing now..."
    try {
        # Download and install Azure CLI
        Write-Info "Downloading Azure CLI installer..."
        $azCliUrl = "https://aka.ms/installazurecliwindows"
        $azCliInstaller = "$env:TEMP\AzureCLI.msi"
        
        Invoke-WebRequest -Uri $azCliUrl -OutFile $azCliInstaller -UseBasicParsing
        Write-Success "Azure CLI installer downloaded"
        
        # Install Azure CLI
        Write-Info "Installing Azure CLI (this may take a few minutes)..."
        Start-Process msiexec.exe -ArgumentList "/i", $azCliInstaller, "/quiet", "/norestart" -Wait -NoNewWindow
        
        # Cleanup
        Remove-Item $azCliInstaller -Force -ErrorAction SilentlyContinue
        
        # Refresh PATH to pick up Azure CLI
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
        $env:Path = $machinePath + ";" + $userPath
        
        # Verify installation
        if (Test-Command "az") {
            Write-Success "Azure CLI installed successfully"
            $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
            if ($azVersion) {
                Write-Info "Installed version: $azVersion"
            }
        } else {
            Write-Warning "Azure CLI installation completed but 'az' command not found in PATH"
            Write-Info "Please restart your terminal and run this script again"
            exit 1
        }
    } catch {
        Write-Error "Azure CLI installation failed: $($_.Exception.Message)"
        Write-Info "Please install Azure CLI manually:"
        Write-Info "1. Download from: https://aka.ms/installazurecliwindows"
        Write-Info "2. Run the installer"
        Write-Info "3. Restart your terminal and run this script again"
        exit 1
    }
}

# Azure Login
Write-Info "Checking Azure authentication status..."
$azAccountList = az account list --output json 2>$null
if ($azAccountList -and $azAccountList -ne "[]") {
    $accounts = $azAccountList | ConvertFrom-Json
    $defaultAccount = $accounts | Where-Object { $_.isDefault -eq $true }
    if ($defaultAccount) {
        Write-Success "Already logged in to Azure as: $($defaultAccount.user.name)"
        Write-Info "Subscription: $($defaultAccount.name) ($($defaultAccount.id))"
    } else {
        Write-Success "Logged in to Azure with multiple accounts"
        Write-Info "Available accounts: $($accounts.Count)"
    }
} else {
    Write-Info "Not logged in to Azure - starting login process..."
    Write-Host "Please complete the Azure login in your browser..." -ForegroundColor Yellow
    
    try {
        az login
        
        # Verify login was successful
        $azAccountList = az account list --output json 2>$null
        if ($azAccountList -and $azAccountList -ne "[]") {
            $accounts = $azAccountList | ConvertFrom-Json
            $defaultAccount = $accounts | Where-Object { $_.isDefault -eq $true }
            if ($defaultAccount) {
                Write-Success "Successfully logged in to Azure as: $($defaultAccount.user.name)"
                Write-Info "Subscription: $($defaultAccount.name) ($($defaultAccount.id))"
            } else {
                Write-Success "Successfully logged in to Azure"
                Write-Info "Available accounts: $($accounts.Count)"
            }
        } else {
            throw "Login verification failed"
        }
    } catch {
        Write-Error "Azure login failed: $($_.Exception.Message)"
        Write-Info "Please try logging in manually with: az login"
        Write-Info "Then run this script again"
        exit 1
    }
}

# Check if StrangeLoop is already installed
if (Test-Command "strangeloop") {
    Write-Success "StrangeLoop CLI is already installed"
    $version = strangeloop --version 2>$null
    if ($version) {
        Write-Info "Current version: $version"
    }
} else {
    Write-Info "StrangeLoop CLI not found - installing now..."
    try {
        # Download if not exists
        if (-not (Test-Path "strangeloop.msi")) {
            Write-Info "Downloading StrangeLoop CLI from Azure DevOps..."
            az artifacts universal download --organization "https://msasg.visualstudio.com/" --project "Bing_Ads" --scope project --feed "strangeloop" --name "strangeloop-x86" --version "*" --path . --only-show-errors
        }
        
        # Check if MSI was downloaded successfully
        if (-not (Test-Path "strangeloop.msi")) {
            throw "StrangeLoop MSI file was not downloaded successfully"
        }
        
        # Try to install using msiexec with elevated privileges
        Write-Info "Installing StrangeLoop CLI..."
        Write-Host "Note: This installation requires administrator privileges and may prompt for elevation." -ForegroundColor Yellow
        
        try {
            # Use msiexec for silent installation
            $msiPath = (Get-Item "strangeloop.msi").FullName
            $installArgs = @("/i", "`"$msiPath`"", "/quiet", "/norestart")
            
            # Try silent installation first
            $process = Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Success "StrangeLoop installed successfully (silent mode)"
            } elseif ($process.ExitCode -eq 1603) {
                # Exit code 1603 often indicates policy restrictions
                throw "Installation blocked by Group Policy (Error 1603). Contact your system administrator."
            } elseif ($process.ExitCode -eq 1260) {
                # Exit code 1260 is the specific Group Policy block error
                throw "Installation blocked by Group Policy (Error 1260). Contact your system administrator."
            } else {
                # Fall back to interactive installation
                Write-Warning "Silent installation failed (Exit Code: $($process.ExitCode)). Trying interactive installation..."
                Start-Process "msiexec.exe" -ArgumentList @("/i", "`"$msiPath`"") -Wait
            }
        } catch {
            # If Group Policy is blocking, provide detailed guidance
            if ($_.Exception.Message -match "1260|group policy|blocked") {
                Write-Error "❌ Installation blocked by Group Policy"
                Write-Host ""
                Write-Host "🔒 Group Policy Restriction Detected" -ForegroundColor Red
                Write-Host "This corporate environment blocks MSI installations." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "📋 Alternative Solutions:" -ForegroundColor Cyan
                Write-Host "1. Contact your system administrator to:" -ForegroundColor White
                Write-Host "   • Temporarily disable MSI execution restrictions" -ForegroundColor Gray
                Write-Host "   • Add an exception for StrangeLoop CLI" -ForegroundColor Gray
                Write-Host "   • Install StrangeLoop CLI centrally" -ForegroundColor Gray
                Write-Host ""
                Write-Host "2. Request IT to install StrangeLoop CLI manually" -ForegroundColor White
                Write-Host ""
                Write-Host "3. Use StrangeLoop via WSL (if available):" -ForegroundColor White
                Write-Host "   • Some loops may work in WSL environment" -ForegroundColor Gray
                Write-Host "   • This script will continue WSL setup" -ForegroundColor Gray
                Write-Host ""
                Write-Host "📁 MSI Location: $(Get-Item 'strangeloop.msi' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)" -ForegroundColor Green
                Write-Host ""
                
                # Don't exit immediately - continue with WSL setup
                Write-Warning "Continuing with WSL setup - some loops may still be available"
                $global:StrangeLoopInstallFailed = $true
            } else {
                throw $_
            }
        }
        
        # Cleanup
        Remove-Item "strangeloop.msi" -Force -ErrorAction SilentlyContinue
        
        # Only check for installation if we didn't hit Group Policy issues
        if (-not $global:StrangeLoopInstallFailed) {
            # Refresh PATH
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
            $env:Path = $machinePath + ";" + $userPath
            
            if (Test-Command "strangeloop") {
                Write-Success "StrangeLoop installed successfully"
                $version = strangeloop --version 2>$null
                if ($version) {
                    Write-Info "Installed version: $version"
                }
            } else {
                Write-Warning "StrangeLoop installation may require terminal restart"
                Write-Info "Please restart your terminal and run this script again"
                exit 1
            }
        }
    } catch {
        if ($_.Exception.Message -match "1260|group policy|blocked") {
            # Already handled above
        } else {
            Write-Error "StrangeLoop installation failed: $($_.Exception.Message)"
            Write-Info "Please install StrangeLoop CLI manually:"
            Write-Info "1. Run: az artifacts universal download --organization 'https://msasg.visualstudio.com/' --project 'Bing_Ads' --scope project --feed 'strangeloop' --name 'strangeloop-x86' --version '*' --path ."
            Write-Info "2. Run the downloaded strangeloop.msi installer"
            Write-Info "3. Restart your terminal and run this script again"
            exit 1
        }
    }
}

#endregion

#region Environment Analysis

# Define environment requirements for different loops
$linuxRequiredLoops = @(
    "flask-linux", "python-mcp-server", "dotnet-aspire", "csharp-mcp-server", 
    "csharp-semantic-kernel-agent", "python-semantic-kernel-agent", "langgraph-agent"
)

$windowsCompatibleLoops = @(
    "asp-dotnet-framework-api", "ads-snr-basic", "python-cli", "flask-windows"
)

#endregion

#region Loop Discovery and Selection

Write-Step "Loop Discovery and Selection"

# Get available loops
$availableLoops = @()
try {
    Write-Info "Discovering available StrangeLoop templates..."
    $loopsOutput = strangeloop library loops 2>$null
    if ($loopsOutput) {
        # Parse loops
        $availableLoops = @()
        $loopsOutput -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -match "^([a-zA-Z0-9\-]+)\s+(.+)$") {
                $availableLoops += @{
                    Name = $matches[1]
                    Description = $matches[2]
                }
            }
        }
    }
    
    if ($availableLoops.Count -eq 0) {
        Write-Error "Could not retrieve loops. Ensure StrangeLoop is properly installed."
        exit 1
    }
    
    Write-Success "Found $($availableLoops.Count) available loop templates"
} catch {
    Write-Error "Could not retrieve loops: $($_.Exception.Message)"
    exit 1
}

if ($availableLoops.Count -eq 0) {
    Write-Warning "No loops found."
    exit 0
}

# Display all available loops with platform indicators
Write-Info "Available loops:"
for ($i = 0; $i -lt $availableLoops.Count; $i++) {
    $loop = $availableLoops[$i]
    $platform = if ($linuxRequiredLoops -contains $loop.Name) { "[WSL]" } 
               elseif ($windowsCompatibleLoops -contains $loop.Name) { "[Win]" } 
               else { "[Any]" }
    Write-Host "  $($i + 1). $($loop.Name) - $($loop.Description) $platform" -ForegroundColor White
}
Write-Host "  0. Skip loop initialization" -ForegroundColor Gray

# Get user choice
do {
    $choice = Read-Host "Select loop (0-$($availableLoops.Count))"
    $validChoice = $choice -match '^\d+$' -and [int]$choice -ge 0 -and [int]$choice -le $availableLoops.Count
    if (-not $validChoice) {
        Write-Warning "Please enter a valid number between 0 and $($availableLoops.Count)"
    }
} while (-not $validChoice)

if ($choice -eq "0") {
    Write-Info "Skipping loop initialization."
    Write-Step "Setup Completed Successfully!"
    Write-Success "StrangeLoop CLI is ready to use!"
    exit 0
}

# Initialize selected loop and derive environment from it
$selectedLoop = $availableLoops[[int]$choice - 1]
Write-Success "Selected: $($selectedLoop.Name)"

#endregion

# Derive environment requirements from selected loop
$needsLinux = $linuxRequiredLoops -contains $selectedLoop.Name
$isWindowsOnly = $windowsCompatibleLoops -contains $selectedLoop.Name

# Check and setup WSL environment when needed
$wslAvailable = $false

# StrangeLoop CLI specifically requires Ubuntu 24.04 LTS
# No fallback to other Ubuntu versions to ensure consistency
$ubuntuDistro = "Ubuntu-24.04"

if ($needsLinux -or (-not $isWindowsOnly)) {
    Write-Host "[DEBUG] WSL Logic: Entering WSL setup - needsLinux=$needsLinux, isWindowsOnly=$isWindowsOnly" -ForegroundColor Magenta
    Write-Step "WSL Setup and Availability Check"
    
    # Check background Git LFS installation status before proceeding
    Test-BackgroundGitLfsInstallation | Out-Null
    
    # Check for existing Ubuntu 24.04 distribution first
    try {
        Write-Info "Checking for existing Ubuntu 24.04 distribution..."
        
        # First, try to get the default distribution from wsl --status
        Write-WSLCommand "wsl --status"
        $wslStatus = wsl --status 2>$null
        if ($wslStatus) {
            $defaultDistroLine = $wslStatus | Where-Object { $_ -like "*Default Distribution:*" }
            if ($defaultDistroLine) {
                $defaultDistro = ($defaultDistroLine -split ":")[1].Trim()
                if ($defaultDistro -eq "Ubuntu-24.04") {
                    Write-Success "Found default Ubuntu 24.04 distribution"
                } else {
                    Write-Info "Default distribution is '$defaultDistro', checking for Ubuntu 24.04 in list..."
                }
            }
        }
        
        # Check the full distribution list for Ubuntu 24.04
        Write-WSLCommand "wsl --list --quiet"
        $distributions = wsl --list --quiet 2>$null
        $ubuntu2404Found = $false
        if ($distributions) {
            foreach ($line in $distributions) {
                if ($line -and $line -notmatch "^Windows Subsystem") {
                    $cleanLine = $line -replace '[^\x20-\x7F]', ''
                    if ($cleanLine -like "*Ubuntu-24.04*") {
                        $ubuntu2404Found = $true
                        Write-Success "Found Ubuntu 24.04 distribution in WSL"
                        break
                    }
                }
            }
        }
        
        if (-not $ubuntu2404Found) {
            Write-Info "Ubuntu 24.04 not found in current WSL installations"
        }
    } catch {
        Write-Warning "Could not detect Ubuntu 24.04 distribution: $($_.Exception.Message)"
    }
    
    # Check if WSL is installed and functional with Ubuntu 24.04
    $wslFullyFunctional = Test-WSLInstallation -DistributionName $ubuntuDistro
    
    # Set WSL availability based on validation result
    if ($wslFullyFunctional) {
        Write-Host "[DEBUG] WSL Logic: WSL is fully functional - wslFullyFunctional=$wslFullyFunctional, ubuntuDistro=$ubuntuDistro" -ForegroundColor Magenta
        Write-Success "WSL and $ubuntuDistro are fully functional"
        $wslAvailable = $true
    } else {
        Write-Host "[DEBUG] WSL Logic: WSL not fully functional, checking installation status - wslFullyFunctional=$wslFullyFunctional" -ForegroundColor Magenta
        # Check if basic WSL is at least installed
        if (-not (Test-Command "wsl")) {
            Write-Host "[DEBUG] WSL Logic: WSL command not found - Test-Command 'wsl' returned $false" -ForegroundColor Magenta
            if ($needsLinux) {
                Write-Host "[DEBUG] WSL Logic: Linux is needed, installing WSL - needsLinux=$needsLinux" -ForegroundColor Magenta
                Write-Info "WSL is required but not installed. Installing WSL..."
                Write-Warning "This requires administrator privileges and may require a restart."
                
                # Force WSL installation with multiple methods
                $installSuccess = $false
                
                # Method 1: Standard WSL install
                Write-Info "Attempting standard WSL installation..."
                try {
                    Write-WSLCommand "wsl --install --distribution $ubuntuDistro --no-launch"
                    wsl --install --distribution $ubuntuDistro --no-launch
                    Write-Success "WSL installation command executed successfully"
                    $installSuccess = $true
                } catch {
                    Write-Warning "Standard WSL installation failed: $($_.Exception.Message)"
                }
                
                # Method 2: Force enable WSL features if standard install failed
                if (-not $installSuccess) {
                    Write-Host "[DEBUG] WSL Logic: Standard install failed, trying force enable" -ForegroundColor Magenta
                    Write-Info "Attempting to force enable WSL features..."
                    try {
                        # Enable WSL and Virtual Machine Platform features
                        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
                        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
                        
                        # Try WSL install again after enabling features
                        Write-WSLCommand "wsl --install --distribution $ubuntuDistro --no-launch"
                        wsl --install --distribution $ubuntuDistro --no-launch
                        Write-Success "WSL features enabled and installation attempted"
                        $installSuccess = $true
                    } catch {
                        Write-Warning "Force WSL feature installation failed: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "[DEBUG] WSL Logic: Standard install succeeded, skipping force enable" -ForegroundColor Magenta
                }
                
                # Method 3: PowerShell feature installation as fallback
                if (-not $installSuccess) {
                    Write-Host "[DEBUG] WSL Logic: Force enable failed, trying PowerShell features" -ForegroundColor Magenta
                    Write-Info "Attempting PowerShell-based feature installation..."
                    try {
                        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
                        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
                        Write-Success "WSL features enabled via PowerShell"
                        $installSuccess = $true
                    } catch {
                        Write-Warning "PowerShell feature installation failed: $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "[DEBUG] WSL Logic: Previous installation method succeeded, skipping PowerShell features" -ForegroundColor Magenta
                }
                
                if ($installSuccess) {
                    Write-Host "[DEBUG] WSL Logic: Installation successful, requiring restart" -ForegroundColor Magenta
                    Write-Warning "WSL installation initiated. You MUST restart your computer now."
                    Write-Info "After restart:"
                    Write-Info "1. Run this script again to continue setup"
                    Write-Info "2. Ubuntu will be automatically initialized (no manual setup needed)"
                    Write-Info "3. If issues persist, try running as Administrator"
                    Write-Info ""
                    Write-Info "Note: The script will handle Ubuntu user setup automatically after restart."
                    exit 0
                } else {
                    Write-Host "[DEBUG] WSL Logic: All installation methods failed" -ForegroundColor Magenta
                    Write-Error "All WSL installation methods failed. Manual installation required:"
                    Write-Info "1. Run PowerShell as Administrator"
                    Write-Info "2. Execute: wsl --install"
                    Write-Info "3. If that fails, execute: dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
                    Write-Info "4. Then execute: dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart"
                    Write-Info "5. Restart your computer"
                    Write-Info "6. Run this script again"
                    exit 1
                }
            } else {
                Write-Host "[DEBUG] WSL Logic: Linux not needed, using Windows-only mode - needsLinux=$needsLinux" -ForegroundColor Magenta
                Write-Info "WSL not installed - will use Windows-only development mode"
            }
        } else {
            Write-Host "[DEBUG] WSL Logic: WSL command exists but distribution check failed - Test-Command 'wsl'=$true, wslFullyFunctional=$false" -ForegroundColor Magenta
            # WSL command exists but distribution check failed - try to fix or install distribution
            if ($needsLinux) {
                Write-Host "[DEBUG] WSL Logic: Linux needed, attempting to fix WSL distribution - needsLinux=$needsLinux, ubuntuDistro=$ubuntuDistro" -ForegroundColor Magenta
                Write-Info "WSL is installed but $ubuntuDistro distribution is not functional. Attempting to fix..."
                
                # Try to repair WSL first
                $repairResult = Repair-WSLInstallation -DistributionName $ubuntuDistro
                if ($repairResult) {
                    Write-Host "[DEBUG] WSL Logic: WSL repair attempted, re-checking - repairResult=$repairResult" -ForegroundColor Magenta
                    Write-Info "WSL repair attempted. Re-checking installation..."
                    $wslFullyFunctional = Test-WSLInstallation -DistributionName $ubuntuDistro
                    if ($wslFullyFunctional) {
                        Write-Host "[DEBUG] WSL Logic: WSL repair successful - wslFullyFunctional=$wslFullyFunctional after repair" -ForegroundColor Magenta
                        Write-Success "WSL repair successful - $ubuntuDistro is now functional"
                        $wslAvailable = $true
                        # Continue to development environment setup instead of returning
                    } else {
                        Write-Host "[DEBUG] WSL Logic: WSL repair did not resolve issue - wslFullyFunctional=$wslFullyFunctional after repair" -ForegroundColor Magenta
                        Write-Warning "WSL repair did not fully resolve the issue. Continuing with installation attempts..."
                    }
                } else {
                    Write-Host "[DEBUG] WSL Logic: WSL repair was not attempted - repairResult=$repairResult" -ForegroundColor Magenta
                }
                
            Write-WSLCommand "wsl -l -v"
            $wslDistros = wsl -l -v 2>$null

            $ubuntuDistroFound = $false
            if ($wslDistros) {
                Write-Host "[DEBUG] WSL Logic: Checking existing WSL distributions" -ForegroundColor Magenta
                $wslDistros -split "`n" | ForEach-Object {
                    $line = $_.Trim()
                    if ($line -and $line -notmatch "^Windows Subsystem") {
                        $cleanLine = $line -replace '[^\x20-\x7F]', ''
                        if ($cleanLine -like "*$ubuntuDistro*") {
                            Write-Host "[DEBUG] WSL Logic: Found Ubuntu distribution: $cleanLine" -ForegroundColor Magenta
                            Write-Success "Found Ubuntu distribution: $cleanLine"
                            $ubuntuDistroFound = $true
                        } else {
                            Write-Host "[DEBUG] WSL Logic: Distribution line doesn't match Ubuntu-24.04: $cleanLine" -ForegroundColor Magenta
                        }
                    } else {
                        Write-Host "[DEBUG] WSL Logic: Skipping empty or header line: $line" -ForegroundColor Magenta
                    }
                }
            } else {
                Write-Host "[DEBUG] WSL Logic: No WSL distributions found - wslDistros is null/empty" -ForegroundColor Magenta
            }

            if ($ubuntuDistroFound) {
                Write-Host "[DEBUG] WSL Logic: Ubuntu distribution found, verifying initialization - ubuntuDistroFound=$ubuntuDistroFound" -ForegroundColor Magenta
                # Ensure Ubuntu is properly initialized
                Write-Info "Verifying Ubuntu distribution is ready for use..."
                $initSuccess = Initialize-UbuntuDistribution -DistributionName $ubuntuDistro
                
                if ($initSuccess) {
                    Write-Host "[DEBUG] WSL Logic: Ubuntu initialization successful - initSuccess=$initSuccess" -ForegroundColor Magenta
                    Write-Success "$ubuntuDistro is ready for use!"
                    $wslAvailable = $true
                    
                    # Set as default distribution
                    try {
                        Write-WSLCommand "wsl -s $ubuntuDistro"
                        wsl -s $ubuntuDistro 2>$null
                        Write-Success "$ubuntuDistro set as default WSL distribution"
                    } catch {
                        Write-Warning "Could not set $ubuntuDistro as default distribution, but continuing..."
                    }
                } else {
                    Write-Host "[DEBUG] WSL Logic: Ubuntu found but not properly initialized - initSuccess=$initSuccess" -ForegroundColor Magenta
                    Write-Warning "$ubuntuDistro found but not properly initialized"
                    Write-Info "You may need to manually launch Ubuntu to complete setup"
                    $wslAvailable = $true  # Still mark as available
                }
            } elseif (-not $ubuntuDistroFound) {
                Write-Host "[DEBUG] WSL Logic: Ubuntu distribution not found - ubuntuDistroFound=$ubuntuDistroFound" -ForegroundColor Magenta
                if ($needsLinux) {
                    Write-Host "[DEBUG] WSL Logic: Linux needed, installing Ubuntu 24.04 - needsLinux=$needsLinux" -ForegroundColor Magenta
                    Write-Info "Ubuntu 24.04 not found. Installing Ubuntu 24.04..."
                    
                    # Enhanced Ubuntu 24.04 installation with multiple methods
                    $distroInstallSuccess = $false
                    
                    # Method 1: Standard WSL distribution install
                    Write-Info "Attempting standard WSL Ubuntu 24.04 installation..."
                    try {
                        Write-WSLCommand "wsl --install --distribution Ubuntu-24.04 --no-launch"
                        wsl --install --distribution Ubuntu-24.04 --no-launch
                        Write-Success "Ubuntu 24.04 installation initiated via WSL"
                        $distroInstallSuccess = $true
                    } catch {
                        Write-Warning "Standard WSL Ubuntu 24.04 installation failed: $($_.Exception.Message)"
                    }
                    
                    # Method 2: Microsoft Store via winget
                    if (-not $distroInstallSuccess -and (Test-Command "winget")) {
                        Write-Host "[DEBUG] WSL Logic: Standard install failed, trying winget" -ForegroundColor Magenta
                        Write-Info "Attempting Microsoft Store Ubuntu 24.04 installation via winget..."
                        try {
                            winget install --id=Canonical.Ubuntu.2404 --source=msstore --accept-package-agreements --accept-source-agreements --silent
                            Write-Success "Ubuntu 24.04 installed via Microsoft Store (winget)"
                            $distroInstallSuccess = $true
                        } catch {
                            Write-Warning "Microsoft Store Ubuntu 24.04 installation via winget failed: $($_.Exception.Message)"
                        }
                    } else {
                        Write-Host "[DEBUG] WSL Logic: Winget method skipped - distroInstallSuccess=$distroInstallSuccess, winget available=$(Test-Command 'winget')" -ForegroundColor Magenta
                    }
                    
                    # Method 3: Direct download and install Ubuntu 24.04 appx
                    if (-not $distroInstallSuccess) {
                        Write-Host "[DEBUG] WSL Logic: Winget failed, trying direct download" -ForegroundColor Magenta
                        Write-Info "Attempting direct Ubuntu 24.04 appx installation..."
                        try {
                            $ubuntuUrl = "https://aka.ms/wslubuntu2404"
                            $ubuntuPath = "$env:TEMP\Ubuntu2404.appx"
                            Write-Info "Downloading Ubuntu 24.04 package..."
                            Invoke-WebRequest -Uri $ubuntuUrl -OutFile $ubuntuPath -UseBasicParsing
                            
                            Write-Info "Installing Ubuntu 24.04 package..."
                            Add-AppxPackage -Path $ubuntuPath
                            Remove-Item $ubuntuPath -Force -ErrorAction SilentlyContinue
                            Write-Success "$ubuntuDistro installed via direct download"
                            $distroInstallSuccess = $true
                        } catch {
                            Write-Warning "Direct Ubuntu 24.04 installation failed: $($_.Exception.Message)"
                        }
                    }
                    
                    if ($distroInstallSuccess) {
                        Write-Host "[DEBUG] WSL Logic: Ubuntu installation completed, initializing" -ForegroundColor Magenta
                        Write-Success "Ubuntu 24.04 installation completed."
                        Write-Info "Initializing Ubuntu 24.04 distribution for first use..."
                        
                        # Initialize Ubuntu without blocking the script
                        $initSuccess = Initialize-UbuntuDistribution -DistributionName $ubuntuDistro
                        
                        if ($initSuccess) {
                            Write-Host "[DEBUG] WSL Logic: Ubuntu initialization after install successful" -ForegroundColor Magenta
                            Write-Success "$ubuntuDistro is ready for use!"
                            $wslAvailable = $true
                            
                            # Set as default distribution
                            try {
                                Write-WSLCommand "wsl -s $ubuntuDistro"
                                wsl -s $ubuntuDistro 2>$null
                                Write-Success "$ubuntuDistro set as default WSL distribution"
                            } catch {
                                Write-Warning "Could not set $ubuntuDistro as default distribution, but continuing..."
                            }
                        } else {
                            Write-Host "[DEBUG] WSL Logic: Ubuntu initialization after install failed" -ForegroundColor Magenta
                            Write-Warning "$ubuntuDistro installation completed but initialization failed"
                        }
                    } else {
                        Write-Host "[DEBUG] WSL Logic: Ubuntu installation failed - distroInstallSuccess=$distroInstallSuccess" -ForegroundColor Magenta
                        Write-Warning "All Ubuntu 24.04 installation methods failed"
                    }
                    
                # Final verification step
                $initSuccess = Test-WSLInstallation -DistributionName $ubuntuDistro
                if ($initSuccess) {
                    Write-Host "[DEBUG] WSL Logic: Final Ubuntu verification successful" -ForegroundColor Magenta
                    Write-Success "$ubuntuDistro is ready for use!"
                    $wslAvailable = $true
                    
                    # Set as default distribution
                    try {
                        Write-WSLCommand "wsl -s $ubuntuDistro"
                        wsl -s $ubuntuDistro 2>$null
                        Write-Success "$ubuntuDistro set as default WSL distribution"
                    } catch {
                        Write-Warning "Could not set $ubuntuDistro as default distribution, but continuing..."
                    }
                } else {
                    Write-Host "[DEBUG] WSL Logic: Final Ubuntu verification failed" -ForegroundColor Magenta
                    Write-Warning "$ubuntuDistro found but not properly initialized"
                    Write-Info "You may need to manually launch Ubuntu to complete setup"
                    $wslAvailable = $true  # Still mark as available
                }
            }
        } else {
            Write-Host "[DEBUG] WSL Logic: Linux not needed, setting wslAvailable to false" -ForegroundColor Magenta
            $wslAvailable = $false
            }
            }
        }
    }
    
    # Enhanced WSL development environment setup
        if ($wslAvailable -and $ubuntuDistro) {
            Write-Host "[DEBUG] WSL Logic: WSL development environment setup conditions met - wslAvailable=$wslAvailable, ubuntuDistro=$ubuntuDistro" -ForegroundColor Magenta
            Write-Step "WSL Development Environment Setup"
            Write-Info "Starting WSL development environment configuration..."
            Write-Info "WSL Status: Available=$wslAvailable, Distribution=$ubuntuDistro"
            
            # Get sudo password upfront for package management operations
            $sudoPassword = Get-SudoPassword $ubuntuDistro
            if ($null -eq $sudoPassword -and (Get-WSLCommandOutput "sudo -n true 2>/dev/null && echo 'NOPASSWD' || echo 'PASSWD_REQUIRED'" $ubuntuDistro) -ne "NOPASSWD") {
                Write-Warning "Cannot perform package management without sudo access. Continuing with limited setup..."
            } else {
                # Update package lists
                Write-Info "Updating package lists..."
                if ($null -eq $sudoPassword) {
                    $updateResult = Invoke-WSLCommand -Command "sudo apt update" -Description "Updating package lists" -Distribution $ubuntuDistro
                } else {
                    $updateResult = Invoke-WSLCommand -Command "sudo apt update" -Description "Updating package lists" -Distribution $ubuntuDistro -SudoPassword $sudoPassword
                }
                
                if ($updateResult) {
                    # Check for upgradeable packages with intelligent handling
                    $upgradeableCount = Get-WSLCommandOutput "apt list --upgradeable 2>/dev/null | grep -v 'WARNING:' | wc -l" $ubuntuDistro
                    
                    # Install Git LFS in WSL
                    Write-Info "Installing Git LFS in WSL..."
                    if ($null -eq $sudoPassword) {
                        $gitLfsResult = Invoke-WSLCommand -Command "sudo apt-get install -y git-lfs" -Description "Installing Git LFS" -Distribution $ubuntuDistro
                    } else {
                        $gitLfsResult = Invoke-WSLCommand -Command "sudo apt-get install -y git-lfs" -Description "Installing Git LFS" -Distribution $ubuntuDistro -SudoPassword $sudoPassword
                    }
                    

                    
                    if ($upgradeableCount -and [int]$upgradeableCount -gt 1) {
                        Write-Info "Found $([int]$upgradeableCount - 1) upgradeable packages"
                        
                        # Check for critical development packages
                        $criticalPackages = @("python3", "python3-pip", "python3-venv", "python3-dev", "build-essential", "git")
                        $upgradeablePackages = Get-WSLCommandOutput 'apt list --upgradeable 2>/dev/null | grep -v "WARNING:" | awk -F"/" "{print $1}"' $ubuntuDistro
                        $criticalUpgrades = @()
                        
                        if ($upgradeablePackages) {
                            foreach ($package in $criticalPackages) {
                                if ($upgradeablePackages -split "`n" | Where-Object { $_ -like "$package*" }) {
                                    $criticalUpgrades += $package
                                }
                            }
                        }
                        
                        if ($criticalUpgrades.Count -gt 0) {
                            Write-Warning "⚠ Development tools with available upgrades detected:"
                            foreach ($pkg in $criticalUpgrades) {
                                $currentVersion = Get-WSLCommandOutput 'dpkg -l | grep "^ii" | grep "'"$pkg"'" | awk "{print $3}"' $ubuntuDistro
                                Write-Host "  • $pkg (current: $currentVersion)" -ForegroundColor Yellow
                            }
                            Write-Info "`nUpgrading these packages may affect existing projects that depend on current versions."
                            
                            $upgradeChoice = Get-UserInput "`nProceed with system package upgrades? (y/n)" "n"
                            if ($upgradeChoice -match '^[Yy]') {
                                Write-Info "Proceeding with package upgrades..."
                                if ($null -eq $sudoPassword) {
                                    Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro
                                } else {
                                    Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro $sudoPassword
                                }
                            } else {
                                Write-Success "Skipping package upgrades to preserve current versions"
                            }
                        } else {
                            # Safe to upgrade non-critical packages
                            if ($null -eq $sudoPassword) {
                                Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro
                            } else {
                                Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro $sudoPassword
                            }
                        }
                    } else {
                        Write-Success "System packages are up to date"
                    }
                    
                    # Install/verify Python development environment
                    Write-Info "Setting up Python development environment..."
                    
                    # Check Python version with intelligent handling
                    $pythonVersion = Get-WSLCommandOutput "python3 --version 2>/dev/null" $ubuntuDistro
                    if ($pythonVersion -and $pythonVersion -match "Python 3\.(\d+)\.(\d+)") {
                        $pythonMajor = [int]$matches[1]
                        $pythonMinor = [int]$matches[2]
                        if ($pythonMajor -ge 10 -or ($pythonMajor -eq 9 -and $pythonMinor -ge 0)) {
                            Write-Success "Python $pythonVersion is already installed"
                        } else {
                            Write-Warning "⚠ Python version $pythonVersion may be outdated for some StrangeLoop templates"
                            $pythonUpgradeChoice = Get-UserInput "`nUpgrade Python to latest version? (y/n)" "n"
                            if ($pythonUpgradeChoice -match '^[Yy]') {
                                if ($null -eq $sudoPassword) {
                                    Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro
                                } else {
                                    Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro $sudoPassword
                                }
                            }
                        }
                    } else {
                        Write-Info "Installing Python development tools..."
                        if ($null -eq $sudoPassword) {
                            Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro
                        } else {
                            Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro $sudoPassword
                        }
                    }
                    
                    # Install pipx and Poetry with version checking
                    $pipxVersion = Get-WSLCommandOutput "pipx --version 2>/dev/null" $ubuntuDistro
                    if ($pipxVersion) {
                        Write-Success "pipx is already installed (version: $pipxVersion)"
                    } else {
                        Write-Info "Installing pipx..."
                        if ($null -eq $sudoPassword) {
                            Invoke-WSLCommand "sudo apt install -y pipx || python3 -m pip install --user pipx" "Installing pipx" $ubuntuDistro
                        } else {
                            Invoke-WSLCommand "sudo apt install -y pipx || python3 -m pip install --user pipx" "Installing pipx" $ubuntuDistro $sudoPassword
                        }
                        Invoke-WSLCommand "pipx ensurepath" "Configuring pipx PATH" $ubuntuDistro
                    }
                    
                    $poetryVersion = Get-WSLCommandOutput "poetry --version 2>/dev/null || ~/.local/bin/poetry --version 2>/dev/null" $ubuntuDistro
                    if ($poetryVersion) {
                        Write-Success "Poetry is already installed ($poetryVersion)"
                        Invoke-WSLCommand "poetry config virtualenvs.in-project true 2>/dev/null || ~/.local/bin/poetry config virtualenvs.in-project true" "Configuring Poetry" $ubuntuDistro
                    } else {
                        Write-Info "Installing Poetry..."
                        Invoke-WSLCommand "pipx install poetry" "Installing Poetry" $ubuntuDistro
                        Invoke-WSLCommand "~/.local/bin/poetry config virtualenvs.in-project true" "Configuring Poetry" $ubuntuDistro
                    }
                    
                    # Git configuration setup
                    Write-Info "Configuring Git in WSL environment..."
                    
                    # Check existing Git configuration first
                    Write-Info "Checking existing Git configuration..."
                    $existingGitName = Get-WSLCommandOutput "git config --global user.name 2>/dev/null || echo ''" $ubuntuDistro
                    $existingGitEmail = Get-WSLCommandOutput "git config --global user.email 2>/dev/null || echo ''" $ubuntuDistro
                    
                    if ($existingGitName -and $existingGitName.Trim() -ne "") {
                        Write-Success "Found existing Git user name: $($existingGitName.Trim())"
                    }
                    if ($existingGitEmail -and $existingGitEmail.Trim() -ne "") {
                        Write-Success "Found existing Git user email: $($existingGitEmail.Trim())"
                    }
                    
                    # Set up Git configuration using globally captured credentials
                    Write-Info "Setting up Git configuration..."

                    # Pass the global variables to the WSL command
                    $gitUserEmail = $global:GitUserEmail
                    $gitUserName = $global:GitUserName
                    $gitdefaultBranch = "main"

                    Invoke-WSLCommand -Description "Configuring complete Git setup" -Distribution $ubuntuDistro -ScriptBlock {
                        # Configure Git user information using globally captured credentials
                        git config --global user.email "$gitUserEmail"
                        git config --global user.name "$gitUserName"
                        git config --global init.defaultBranch "$gitdefaultBranch"

                        # Install Git LFS
                        sudo apt-get install -y git-lfs
                        
                        # Configure Git credential manager and merge tool
                        git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
                        git config --global credential.helper "/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe"
                        git config --global credential.useHttpPath true
                        git config --global merge.tool vscode
                        git config --global mergetool.vscode.cmd 'code --wait `$MERGED'
                    }

                    if ($gitUserName -and $gitUserEmail) {
                        Write-Success "Git configured successfully:"
                        Write-Info "  Name: $gitUserName"
                        Write-Info "  Email: $gitUserEmail"
                        Write-Info "  Default branch: $gitdefaultBranch"
                        Write-Info "  Merge tool: $gitMergeTool"
                        Write-Info "  Credential helper: $gitCredentialHelper"
                    } else {
                        Write-Warning "Git configuration verification failed. You may need to configure Git manually."
                    }
                    
                    # Clear sudo password from memory for security
                    if ($sudoPassword) {
                        $sudoPassword.Dispose()
                        Write-Info "Cleared sudo credentials from memory"
                    }
                }
            }
        } else {
            Write-Host "[DEBUG] WSL Logic: WSL development environment setup skipped - wslAvailable=$wslAvailable, ubuntuDistro=$ubuntuDistro" -ForegroundColor Magenta
        }
    }

if ($needsLinux) {
        Write-Host "[DEBUG] WSL Logic: Environment check - Linux is required - needsLinux=$needsLinux, selectedLoop=$($selectedLoop.Name)" -ForegroundColor Magenta
        if (-not $wslAvailable) {
            Write-Host "[DEBUG] WSL Logic: ERROR - Linux required but WSL not available - wslAvailable=$wslAvailable" -ForegroundColor Red
            Write-Error "Selected loop '$($selectedLoop.Name)' requires WSL/Linux environment, but WSL is not available."
            Write-Info "Please install WSL or choose a Windows-compatible loop."
            exit 1
        }
        Write-Host "[DEBUG] WSL Logic: Using WSL/Linux environment - wslAvailable=$wslAvailable" -ForegroundColor Magenta
        Write-Success "Environment: WSL/Linux (required for $($selectedLoop.Name))"
        Write-Info "This loop requires Linux development environment"
    } elseif ($isWindowsOnly) {
        Write-Host "[DEBUG] WSL Logic: Environment check - Windows-only required - isWindowsOnly=$isWindowsOnly, selectedLoop=$($selectedLoop.Name)" -ForegroundColor Magenta
        $needsLinux = $false
        Write-Success "Environment: Windows native (required for $($selectedLoop.Name))"
        Write-Info "This loop is designed for Windows development"
    } else {
        Write-Host "[DEBUG] WSL Logic: Environment check - Universal loop, user choice - selectedLoop=$($selectedLoop.Name), needsLinux=$needsLinux, isWindowsOnly=$isWindowsOnly" -ForegroundColor Magenta
        # Universal loop - let user choose if WSL is available
        if ($wslAvailable) {
            Write-Host "[DEBUG] WSL Logic: WSL available for universal loop, offering choice - wslAvailable=$wslAvailable" -ForegroundColor Magenta
            Write-Info "`nThis loop supports both environments. Choose your preference:"
            Write-Host "  1. WSL/Linux (recommended for modern development)" -ForegroundColor Green
            Write-Host "  2. Windows native (enterprise/.NET Framework projects)" -ForegroundColor White
            
            $envChoice = Get-UserInput "Select environment (1-2)" "1"
            $needsLinux = ($envChoice -eq "1")
            
            if ($needsLinux) {
                Write-Host "[DEBUG] WSL Logic: User chose WSL/Linux environment - envChoice=$envChoice, needsLinux=$needsLinux" -ForegroundColor Magenta
                Write-Success "Environment: WSL/Linux (user preference)"
                Write-Info "Using Linux development environment"
            } else {
                Write-Host "[DEBUG] WSL Logic: User chose Windows native environment - envChoice=$envChoice, needsLinux=$needsLinux" -ForegroundColor Magenta
                Write-Success "Environment: Windows native (user preference)" 
                Write-Info "Using Windows development environment"
            }
        } else {
            Write-Host "[DEBUG] WSL Logic: WSL not available for universal loop, using Windows - wslAvailable=$wslAvailable" -ForegroundColor Magenta
            $needsLinux = $false
            Write-Success "Environment: Windows native (WSL not available)"
            Write-Info "Using Windows development environment"
        }
    }

#endregion

#region Project Initialization

# Initialize variables
$appName = $null
$projectCreated = $false

Write-Step "Project Initialization"

try {
    # Get application details with environment-specific defaults
    $defaultAppName = "my-$($selectedLoop.Name)-app"
    $appName = Get-UserInput "Application name" $defaultAppName
        
        if ($needsLinux) {
            # WSL development - use Linux file system
            # Detect WSL user once to avoid placeholder issues
            $detectedWslUser = $null
            try {
                $detectedWslUser = (wsl -d $ubuntuDistro -- bash -lc 'whoami' 2>$null)
                if ($detectedWslUser) { $detectedWslUser = $detectedWslUser.Trim() }
            } catch { }
            if (-not $detectedWslUser) {
                try { $detectedWslUser = (wsl -- bash -lc 'whoami' 2>$null).Trim() } catch { }
            }

            $defaultAppDir = if ($detectedWslUser) { "/home/$detectedWslUser/projects/$appName" } else { "/home/`$(whoami)/projects/$appName" }
            Write-Info "Using WSL environment for project initialization"
            $appDir = Get-UserInput "Application directory (WSL path)" $defaultAppDir
            # Resolve any placeholders in the provided path
            $appDirResolved = Resolve-WSLPath -Path $appDir -Distribution $ubuntuDistro
            
            # Create directory in WSL and check for existing projects
        Write-Info "Creating application directory in WSL: $appDirResolved"
            
        # Check if directory already exists and handle accordingly
        $dirCheckCommand = "if [ -d '$appDirResolved' ]; then echo 'EXISTS'; else echo 'NOT_EXISTS'; fi"
        Write-WSLCommand "wsl -- bash -c `"$dirCheckCommand`""
        $dirExists = wsl -- bash -c $dirCheckCommand
            
            $shouldInitialize = $true
            if ($dirExists -eq "EXISTS") {
                Write-Warning "Directory '$appDir' already exists"
                
                # Check if it's already a StrangeLoop project
                $isStrangeLoopCommand = "cd '$appDirResolved' && if [ -d './strangeloop' ]; then echo 'YES'; else echo 'NO'; fi"
                Write-WSLCommand "wsl -- bash -c `"$isStrangeLoopCommand`""
                $isStrangeLoopProject = wsl -- bash -c $isStrangeLoopCommand
                
                if ($isStrangeLoopProject -eq "YES") {
                    Write-Warning "Directory appears to be an existing StrangeLoop project"
                    $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "y"
                    if ($overwriteChoice -notmatch '^[Yy]') {
                        Write-Info "Skipping initialization. Using existing project directory."
                        $shouldInitialize = $false
                    } else {
                        Write-Info "Cleaning existing project and reinitializing..."
                        $cleanCommand = "cd '$appDirResolved' && rm -rf ./* ./.*[^.] 2>/dev/null || true"
                        Write-WSLCommand "wsl -- bash -c `"$cleanCommand`""
                        wsl -- bash -c $cleanCommand
                    }
                } else {
                    # Directory exists but not a StrangeLoop project
                    $hasFilesCommand = "cd '$appDirResolved' && find . -maxdepth 1 -type f | wc -l"
                    Write-WSLCommand "wsl -- bash -c `"$hasFilesCommand`""
                    $hasFiles = wsl -- bash -c $hasFilesCommand
                    if ($hasFiles -and [int]$hasFiles -gt 0) {
                        Write-Warning "Directory contains $hasFiles files"
                        $proceedChoice = Get-UserInput "Directory is not empty. Proceed anyway? (y/n)" "n"
                        if ($proceedChoice -notmatch '^[Yy]') {
                            Write-Info "Project initialization cancelled by user."
                            exit 0
                        }
                    }
                }
            } else {
                # Create directory
                Write-WSLCommand "wsl -- bash -c `"mkdir -p '$appDirResolved'`""
                wsl -- bash -c "mkdir -p '$appDirResolved'"
            }
            
            # Initialize project in WSL (only if needed)
            if ($shouldInitialize) {
                Write-Info "Initializing $($selectedLoop.Name) loop in WSL environment..."
                $initCommand = "cd '$appDirResolved' && strangeloop init --loop $($selectedLoop.Name)"
                Write-Info "initCommand: $initCommand"
                Write-WSLCommand "wsl -- bash -c `"$initCommand`""
                $loopResult = wsl -- bash -c $initCommand
                Write-Host "WSL loop init output:" -ForegroundColor Yellow
                if ($loopResult) { Write-Host "$loopResult" -ForegroundColor Gray }
            } else {
                Write-Info "Using existing StrangeLoop project directory"
            }
            
        if ($LASTEXITCODE -eq 0 -or -not $shouldInitialize) {
                if ($shouldInitialize) {
                    Write-Success "Loop initialized successfully in WSL!"
                } else {
                    Write-Success "Using existing StrangeLoop project in WSL!"
                }
                $projectCreated = $true
                
               
                
                # Update settings.yaml with project name
                Write-Info "Updating project settings..."
                $updateCommand = "cd '$appDirResolved' && if [ -f './strangeloop/settings.yaml' ]; then sed -i 's/^name:.*/name: $appName/' './strangeloop/settings.yaml'; fi"
                Write-WSLCommand "wsl -- bash -c `"$updateCommand`""
                wsl -- bash -c $updateCommand
                
                # Run strangeloop recurse to apply configuration changes
                Write-Info "Applying configuration changes..."
                $recurseCommand = "cd '$appDirResolved' && strangeloop recurse"
                Write-WSLCommand "wsl -- bash -c `"$recurseCommand`""
                wsl -- bash -c $recurseCommand
                
                # Provide access instructions
                Write-Info "`nTo access your project:"
                Write-Host "  WSL: cd '$appDirResolved'" -ForegroundColor Yellow
                Write-Host "  Windows: \\wsl.localhost\$ubuntuDistro$appDirResolved" -ForegroundColor Yellow
                Write-Host "  VS Code: code '$appDirResolved' (from WSL terminal)" -ForegroundColor Yellow

                # Open VS Code for the initialized project in WSL
                Open-VSCode -Path $appDirResolved -IsWSL:$true -Distribution $ubuntuDistro
            } else {
                Write-Error "Loop initialization failed in WSL"
                exit 1
            }
        } else {
            # Windows development - use Windows file system
            $defaultAppDir = "q:\src\$appName"
            Write-Info "Using Windows environment for project initialization"
            $appDir = Get-UserInput "Application directory (Windows path)" $defaultAppDir
            
            # Create directory in Windows and check for existing projects
            Write-Info "Creating application directory: $appDir"
            
            $shouldInitialize = $true
            if (Test-Path $appDir) {
                Write-Warning "Directory '$appDir' already exists"
                
                # Check if it's already a StrangeLoop project
                $strangeloopDir = Join-Path $appDir "strangeloop"
                if (Test-Path $strangeloopDir) {
                    Write-Warning "Directory appears to be an existing StrangeLoop project"
                    $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "y"
                    if ($overwriteChoice -notmatch '^[Yy]') {
                        Write-Info "Skipping initialization. Using existing project directory."
                        $shouldInitialize = $false
                    } else {
                        Write-Info "Cleaning existing project and reinitializing..."
                        Get-ChildItem -Path $appDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    # Directory exists but not a StrangeLoop project
                    $existingFiles = @(Get-ChildItem -Path $appDir -Force -ErrorAction SilentlyContinue)
                    if ($existingFiles.Count -gt 0) {
                        Write-Warning "Directory contains $($existingFiles.Count) items"
                        $proceedChoice = Get-UserInput "Directory is not empty. Proceed anyway? (y/n)" "n"
                        if ($proceedChoice -notmatch '^[Yy]') {
                            Write-Info "Project initialization cancelled by user."
                            exit 0
                        }
                    }
                }
            } else {
                # Create directory
                New-Item -ItemType Directory -Path $appDir -Force | Out-Null
            }
            
            Set-Location $appDir
            
            # Initialize project (only if needed)
            if ($shouldInitialize) {
                Write-Info "Initializing $($selectedLoop.Name) loop in Windows environment..."
                strangeloop init --loop $selectedLoop.Name
            } else {
                Write-Info "Using existing StrangeLoop project directory"
            }
            
        if ($LASTEXITCODE -eq 0 -or -not $shouldInitialize) {
                if ($shouldInitialize) {
                    Write-Success "Loop initialized successfully!"
                } else {
                    Write-Success "Using existing StrangeLoop project!"
                }
                $projectCreated = $true
                
                # Update settings.yaml with project name
                $settingsPath = ".\strangeloop\settings.yaml"
                if (Test-Path $settingsPath) {
                    Write-Info "Updating settings.yaml with project name..."
                    $content = Get-Content $settingsPath
                    $newContent = @()
                    
                    foreach ($line in $content) {
                        if ($line -match '^name:\s*.*') {
                            $newContent += "name: $appName"
                            Write-Info "Updated name field: $appName"
                        } else {
                            $newContent += $line
                        }
                    }
                    
                    Set-Content $settingsPath $newContent
                    
                    # Run strangeloop recurse to apply configuration changes
                    Write-Info "Applying configuration changes..."
                    strangeloop recurse
                    
                    Write-Success "Configuration applied successfully"
                } else {
                    Write-Warning "settings.yaml not found at $settingsPath"
                }
                
                Write-Info "`nProject created at: $appDir"
                Write-Host "  Open in VS Code: code ." -ForegroundColor Yellow

                # Open VS Code in Windows environment
                Open-VSCode -Path $appDir -IsWSL:$false
            } else {
                Write-Error "Loop initialization failed"
                exit 1
            }
        }
        
    } catch {
        Write-Error "Loop initialization failed: $($_.Exception.Message)"
        exit 1
    }


#endregion

#region Final Success

# Final check for background Git LFS installation
Write-Info "Performing final Git LFS installation check..."
Test-BackgroundGitLfsInstallation | Out-Null

Write-Step "Setup Completed Successfully!" "Green"
Write-Success "StrangeLoop CLI environment is ready!"

if ($projectCreated -and $appName) {
    Write-Success "Project '$appName' has been created and configured successfully!"
    
    if ($needsLinux) {
        Write-Info "You can now start developing with StrangeLoop in your WSL environment!"
    } else {
        Write-Info "You can now start developing with StrangeLoop!"
    }
    
    Write-Info "`nNext steps:"
    Write-Host "  1. Navigate to your project directory" -ForegroundColor Cyan
    Write-Host "  2. Explore the generated files and documentation" -ForegroundColor Cyan
    Write-Host "  3. Run 'strangeloop --help' for more commands" -ForegroundColor Cyan
} else {
    Write-Info "StrangeLoop CLI is now ready for use!"
    Write-Info "`nNext steps:"
    Write-Host "  1. Run 'strangeloop init --loop <loop-name>' in your project directory" -ForegroundColor Cyan
    Write-Host "  2. Run 'strangeloop --help' for more commands" -ForegroundColor Cyan
}

#endregion

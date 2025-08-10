# StrangeLoop CLI Setup Script - Linux/WSL
# Handles Linux/WSL-specific development environment setup
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script manages WSL setup, Linux package management, Python environment,
# Poetry, pipx, Git configuration, and Docker setup for Linux development.
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+, WSL capability
# Execution Policy: RemoteSigned or Unrestricted required
#
# Usage: .\strangeloop_linux.ps1 [-MaintenanceMode] [-Verbose] [-WhatIf] [-UserName "Name"] [-UserEmail "email@domain.com"]

param(
    [switch]$MaintenanceMode,
    [switch]$Verbose,
    [switch]$WhatIf,
    [string]$UserName,
    [string]$UserEmail
)

# Prefixed logging for this script
$script:LogPrefix = "[LINUX]"
function Write-Host {
    param(
        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        $Object,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$NoNewline,
        [string]$Separator
    )
    $prefix = $script:LogPrefix
    if ($null -ne $Separator -and $Object -is [System.Array]) {
        $text = "$prefix " + ($Object -join $Separator)
    } else {
        $text = "$prefix $Object"
    }
    $splat = @{ Object = $text }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $splat['ForegroundColor'] = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $splat['BackgroundColor'] = $BackgroundColor }
    if ($PSBoundParameters.ContainsKey('NoNewline'))      { $splat['NoNewline']      = $NoNewline }
    Microsoft.PowerShell.Utility\Write-Host @splat
}

function Write-Verbose {
    param([string]$Message)
    $prefix = $script:LogPrefix
    Microsoft.PowerShell.Utility\Write-Verbose -Message ("$prefix $Message")
}

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Banners
if ($Verbose) { $VerbosePreference = "Continue"; Write-Host "🔍 VERBOSE MODE ENABLED in Linux setup" -ForegroundColor Cyan }
if ($WhatIf) { Write-Host "🔍 WHATIF MODE ENABLED in Linux setup - Preview mode" -ForegroundColor Yellow }

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
    
    if ($WhatIf) {
        Write-Host "  ⚪ WhatIf: Would execute - $Description" -ForegroundColor Yellow
        return $null
    }
    
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

# Colors for output
$Colors = @{
    Success = "Green"
    Warning = "Yellow" 
    Error = "Red"
    Info = "Cyan"
    Highlight = "Magenta"
}

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

function Invoke-WSLCommand {
    param([string]$Command, [string]$Description, [string]$Distribution = "", [SecureString]$SudoPassword = $null)
    try {
        # Use specified distribution or default Ubuntu
        $distroParam = if ($Distribution) { "-d $Distribution" } else { "" }
        $targetDisplay = if ($Distribution) { $Distribution } else { 'Default WSL' }
        
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $Description..." -ForegroundColor Yellow
        
        # Only show target distribution if it's different from the last shown one
        if ($script:LastShownDistribution -ne $targetDisplay) {
            Write-Host "  Target: $targetDisplay" -ForegroundColor Gray
            $script:LastShownDistribution = $targetDisplay
        }
        
        # Track start time for duration calculation
        $startTime = Get-Date
        
        # Show progress indicator
        $originalTitle = $Host.UI.RawUI.WindowTitle
        $Host.UI.RawUI.WindowTitle = "StrangeLoop Setup - $Description"
        
        # Start progress animation in background
        $progressJob = Start-Job -ScriptBlock {
            $counter = 0
            $spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
            while ($true) {
                Write-Host "`r  $($spinner[$counter % $spinner.Length]) Processing..." -ForegroundColor Cyan -NoNewline
                Start-Sleep -Milliseconds 100
                $counter++
            }
        }
        
        try {
            # Handle sudo commands with password if provided
            if ($SudoPassword -and $Command.StartsWith("sudo ")) {
                # Convert SecureString to plain text for command execution
                $plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SudoPassword))
                # Replace sudo with echo password | sudo -S
                $sudoCommand = $Command -replace "^sudo ", ""
                $commandWithPassword = "echo '$plaintextPassword' | sudo -S $sudoCommand"
                $wslCommand = "wsl $distroParam -- bash -c `"$commandWithPassword`""
            } else {
                $wslCommand = "wsl $distroParam -- bash -c `"$Command`""
            }
            
            $result = Invoke-Expression $wslCommand 2>&1
            
            # Stop progress animation
            Stop-Job $progressJob -ErrorAction SilentlyContinue
            Remove-Job $progressJob -ErrorAction SilentlyContinue
            Write-Host "`r  ✓ Complete!                    " -ForegroundColor Green
        } finally {
            # Ensure progress job is cleaned up
            if ($progressJob) {
                Stop-Job $progressJob -ErrorAction SilentlyContinue
                Remove-Job $progressJob -ErrorAction SilentlyContinue
            }
        }
        
        # Restore window title
        $Host.UI.RawUI.WindowTitle = $originalTitle
        
        # For StrangeLoop commands, check if output contains success indicators rather than relying solely on exit code
        $isStrangeLoopCommand = $Command -match "strangeloop"
        $hasSuccessOutput = $result -and ($result -join "`n") -match "(initialized|generated|merged|up to date)"
        
        if ($LASTEXITCODE -eq 0 -or ($isStrangeLoopCommand -and $hasSuccessOutput)) {
            Write-Host "  Duration: $((Get-Date).Subtract($startTime).TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "`n  ⚠ Failed (Exit code: $LASTEXITCODE)" -ForegroundColor Red
            if ($result) {
                $errorLines = $result | Where-Object { $_ -and $_.ToString().Trim() }
                if ($errorLines) {
                    Write-Host "  Error: $($errorLines[0])" -ForegroundColor Red
                }
            }
            Write-Host "  Manual command: wsl $distroParam -- $Command" -ForegroundColor Yellow
            return $false
        }
    } catch {
        # Restore window title in case of exception
        if ($originalTitle) {
            $Host.UI.RawUI.WindowTitle = $originalTitle
        }
        Write-Host "`n  ✗ Exception occurred" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-WSLCommandOutput {
    param([string]$Command, [string]$Distribution = "")
    try {
        $distroParam = if ($Distribution) { "-d $Distribution" } else { "" }
        $wslCommand = "wsl $distroParam -- bash -c `"$Command`""
        $result = Invoke-Expression $wslCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            return ($result | Where-Object { $_ -and $_.ToString().Trim() }) -join "`n"
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

function Get-SudoPassword {
    param([string]$Distribution)
    
    Write-Info "Checking sudo access for WSL operations..."
    
    # First check if sudo is passwordless
    $sudoCheck = Get-WSLCommandOutput "sudo -n true 2>/dev/null && echo 'NOPASSWD' || echo 'PASSWD_REQUIRED'" $Distribution
    
    if ($sudoCheck -eq "NOPASSWD") {
        Write-Success "Passwordless sudo is configured"
        return $null
    } else {
        Write-Info "Sudo password is required for package management operations."
        Write-Host "Please enter your WSL sudo password (input will be hidden):" -ForegroundColor Yellow
        
        # Securely read password
        $securePassword = Read-Host -AsSecureString
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
}

function Get-UserInput {
    param([string]$Prompt, [string]$DefaultValue = "", [bool]$Required = $false)
    
    do {
        if ($DefaultValue) {
            $userInput = Read-Host "$Prompt [$DefaultValue]"
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                return $DefaultValue
            }
        } else {
            $userInput = Read-Host $Prompt
        }
        
        if ($Required -and [string]::IsNullOrWhiteSpace($userInput)) {
            Write-Error "This field is required. Please enter a value."
        }
    } while ($Required -and [string]::IsNullOrWhiteSpace($userInput))
    
    return $userInput
}

# Main Script
if ($MaintenanceMode) {
    Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           StrangeLoop CLI Setup - Linux/WSL Maintenance       ║
║                     Package Updates Only                      ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Success
} else {
    Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           StrangeLoop CLI Setup - Linux/WSL Dependencies      ║
║                     Development Environment                   ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Highlight
}

# Define Ubuntu distribution variable
$ubuntuDistro = "Ubuntu-24.04"

# Maintenance Mode - Skip WSL setup, focus on package updates
if ($MaintenanceMode) {
    Write-Info "Running in Maintenance Mode - updating packages only"
    Write-Info "Assuming WSL and Ubuntu are already configured"
    
    # Quick check that WSL Ubuntu exists
    if (-not (Test-Command "wsl")) {
        Write-Error "WSL not found. Please run full setup first (without -MaintenanceMode)"
        exit 1
    }
    
    $wslDistros = wsl -l -v 2>$null
    $foundUbuntuLine = $false
    if ($wslDistros) {
        $wslDistros -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -and $line -like "*$ubuntuDistro*") {
                $foundUbuntuLine = $true
            }
        }
    }
    
    if (-not $foundUbuntuLine) {
        Write-Error "Ubuntu WSL distribution not found. Please run full setup first (without -MaintenanceMode)"
        exit 1
    }
    
    Write-Success "Found Ubuntu WSL distribution - proceeding with package updates"
    
    # Jump directly to package management (Step 2)
    Write-Step "System Package Updates"
    
    # Get sudo password for package updates
    $sudoPassword = Get-SudoPassword $ubuntuDistro
    if ($null -eq $sudoPassword -and (Get-WSLCommandOutput "sudo -n true 2>/dev/null && echo 'NOPASSWD' || echo 'PASSWD_REQUIRED'" $ubuntuDistro) -ne "NOPASSWD") {
        Write-Error "Cannot proceed without valid sudo credentials."
        exit 1
    }
    
    # Update packages
    Write-Info "Updating package lists..."
    if ($null -eq $sudoPassword) {
        $updateResult = Invoke-WSLCommand "sudo apt update" "Updating package lists" $ubuntuDistro
    } else {
        $updateResult = Invoke-WSLCommand "sudo apt update" "Updating package lists" $ubuntuDistro $sudoPassword
    }
    
    if (-not $updateResult) {
        Write-Warning "Package list update may have failed. Continuing..."
    }
    
    # Check for upgradeable packages
    $upgradeableCount = Get-WSLCommandOutput "apt list --upgradeable 2>/dev/null | grep -v 'WARNING:' | wc -l" $ubuntuDistro
    if ($upgradeableCount -and [int]$upgradeableCount -gt 1) {
        Write-Info "Found $([int]$upgradeableCount - 1) upgradeable packages"
        Write-Info "Proceeding with package upgrades..."
        if ($null -eq $sudoPassword) {
            Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro
        } else {
            Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro $sudoPassword
        }
    } else {
        Write-Success "System packages are up to date"
    }
    
    # Update Python packages
    Write-Step "Python Package Updates"
    
    # Update pipx packages
    $pipxList = Get-WSLCommandOutput "pipx list --short 2>/dev/null" $ubuntuDistro
    if ($pipxList) {
        Write-Info "Updating pipx packages..."
        Invoke-WSLCommand "pipx upgrade-all" "Updating pipx packages" $ubuntuDistro
    } else {
        Write-Info "No pipx packages found to update"
    }
    
    # Update Poetry if installed
    $poetryVersion = Get-WSLCommandOutput "poetry --version 2>/dev/null || ~/.local/bin/poetry --version 2>/dev/null" $ubuntuDistro
    if ($poetryVersion) {
        Write-Info "Updating Poetry..."
        Invoke-WSLCommand "pipx upgrade poetry" "Updating Poetry" $ubuntuDistro
    }
    
    # Clear sudo password from memory
    if ($sudoPassword) {
        $sudoPassword.Dispose()
        Write-Info "Cleared sudo credentials from memory"
    }
    
    # Maintenance mode completion
    Write-Step "Maintenance Complete" "Green"
    Write-Success "✓ Linux/WSL package updates completed successfully"
    Write-Info "Maintenance mode finished. All packages have been updated."
    exit 0
}

# Step 1: WSL Setup
Write-Step "WSL and Ubuntu Setup"

# Check WSL installation
if (-not (Test-Command "wsl")) {
    Write-Info "Installing WSL (requires admin privileges)..."
    try {
        wsl --install --distribution $ubuntuDistro
        Write-Warning "WSL installation initiated. You may need to restart your computer."
        Write-Info "After restart, run this script again to continue setup."
        exit 0
    } catch {
        Write-Error "WSL installation failed. Please install manually."
        exit 1
    }
}

# Check for Ubuntu 24.04 distribution
$wslDistros = wsl -l -v 2>$null
Write-Info "Checking for $ubuntuDistro distribution..."

$foundUbuntu = $false
if ($wslDistros) {
    $wslDistros -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and $line -notmatch "^Windows Subsystem") {
            # Clean the line of any special characters
            $cleanLine = $line -replace '[^\x20-\x7F]', ''  # Remove non-printable characters

            # Check if this line contains our Ubuntu distribution
            if ($cleanLine -like "*$ubuntuDistro*") {
                Write-Host "  Found: $cleanLine" -ForegroundColor Green
                $foundUbuntu = $true
            }
        }
    }
}

if (-not $foundUbuntu) {
    Write-Info "$ubuntuDistro not found. Installing $ubuntuDistro..."
    try {
        wsl --install --distribution $ubuntuDistro
        Write-Warning "$ubuntuDistro installation initiated. Please wait for completion and run this script again."
        exit 0
    } catch {
        Write-Error "$ubuntuDistro installation failed. Please install manually from Microsoft Store."
        exit 1
    }
} else {
    Write-Success "Found $ubuntuDistro - skipping installation"
}

# Display found Ubuntu distribution
Write-Success "Found Ubuntu distribution: $ubuntuDistro"
Write-Info "This distribution will be used for development environment setup."

# Set as default and update
Invoke-CommandWithDuration -Description "Setting $ubuntuDistro as default WSL distribution" -ScriptBlock {
    wsl -s $ubuntuDistro 2>$null
    Write-Success "$ubuntuDistro set as default WSL distribution"
}

# Step 2: System Package Management
Write-Step "System Package Management"

# Get sudo password upfront for package management operations
$sudoPassword = Get-SudoPassword $ubuntuDistro
if ($null -eq $sudoPassword -and (Get-WSLCommandOutput "sudo -n true 2>/dev/null && echo 'NOPASSWD' || echo 'PASSWD_REQUIRED'" $ubuntuDistro) -ne "NOPASSWD") {
    Write-Error "Cannot proceed without valid sudo credentials."
    exit 1
}

# Check and update packages intelligently
Write-Info "Updating package lists..."

if ($null -eq $sudoPassword) {
    $updateResult = Invoke-WSLCommand "sudo apt update" "Updating package lists" $ubuntuDistro
} else {
    $updateResult = Invoke-WSLCommand "sudo apt update" "Updating package lists" $ubuntuDistro $sudoPassword
}

if (-not $updateResult) {
    Write-Warning "Package update may have failed. Continuing with setup..."
}

# Check for upgradeable packages
$upgradeableCount = Get-WSLCommandOutput "apt list --upgradeable 2>/dev/null | grep -v 'WARNING:' | wc -l" $ubuntuDistro
if ($upgradeableCount -and [int]$upgradeableCount -gt 1) {
    Write-Info "Found $([int]$upgradeableCount - 1) upgradeable packages"
    
    # Check for specific development tools that might affect existing projects
    $criticalPackages = @("python3", "python3-pip", "python3-venv", "python3-dev", "build-essential", "git")
    $upgradeablePackages = Get-WSLCommandOutput "apt list --upgradeable 2>/dev/null | grep -v 'WARNING:' | awk -F'/' '{print `$1}'" $ubuntuDistro
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
            $currentVersion = Get-WSLCommandOutput "dpkg -l | grep '^ii' | grep '$pkg ' | awk '{print `$3}'" $ubuntuDistro
            Write-Host "  • $pkg (current: $currentVersion)" -ForegroundColor Yellow
        }
        Write-Info "`nUpgrading these packages may affect existing projects that depend on current versions."
        Write-Info "Consider backing up your existing projects before proceeding."
        
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
        # No critical packages, safe to upgrade
        if ($null -eq $sudoPassword) {
            Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro
        } else {
            Invoke-WSLCommand "sudo apt upgrade -y" "Upgrading system packages" $ubuntuDistro $sudoPassword
        }
    }
} else {
    Write-Success "System packages are up to date"
}

# Step 3: Python Development Environment
Write-Step "Python Development Environment"

# Check Python installation and version
$pythonVersion = Get-WSLCommandOutput "python3 --version 2>/dev/null" $ubuntuDistro
if ($pythonVersion -and $pythonVersion -match "Python 3\.(\d+)\.(\d+)") {
    $pythonMajor = [int]$matches[1]
    $pythonMinor = [int]$matches[2]
    if ($pythonMajor -ge 10 -or ($pythonMajor -eq 9 -and $pythonMinor -ge 0)) {
        Write-Success "Python $pythonVersion is already installed"
    } else {
        Write-Warning "⚠ Python version $pythonVersion is outdated"
        Write-Info "Current Python version may be required by existing projects."
        Write-Info "Upgrading Python could potentially break existing virtual environments."
        
        $pythonUpgradeChoice = Get-UserInput "`nUpgrade Python to latest version? (y/n)" "n"
        if ($pythonUpgradeChoice -match '^[Yy]') {
            Write-Info "Installing latest Python version..."
            if ($null -eq $sudoPassword) {
                Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro
            } else {
                Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro $sudoPassword
            }
        } else {
            Write-Success "Keeping current Python version: $pythonVersion"
            Write-Info "Note: Some StrangeLoop templates may require Python 3.9+"
        }
    }
} else {
    Write-Info "Python3 not found, installing..."
    if ($null -eq $sudoPassword) {
        Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro
    } else {
        Invoke-WSLCommand "sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential" "Installing Python tools" $ubuntuDistro $sudoPassword
    }
}

# Check pipx installation
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

# Check Poetry installation
$poetryVersion = Get-WSLCommandOutput "poetry --version 2>/dev/null || ~/.local/bin/poetry --version 2>/dev/null" $ubuntuDistro
if ($poetryVersion) {
    Write-Success "Poetry is already installed ($poetryVersion)"
    # Ensure Poetry configuration is set - try both poetry and full path
    $configResult = Invoke-WSLCommand "poetry config virtualenvs.in-project true 2>/dev/null || ~/.local/bin/poetry config virtualenvs.in-project true" "Configuring Poetry" $ubuntuDistro
    if (-not $configResult) {
        Write-Warning "Poetry configuration may have failed, but continuing..."
    }
} else {
    Write-Info "Installing Poetry..."
    Invoke-WSLCommand "pipx install poetry" "Installing Poetry" $ubuntuDistro
    # Configure Poetry using full path since it may not be in PATH immediately
    Invoke-WSLCommand "~/.local/bin/poetry config virtualenvs.in-project true" "Configuring Poetry" $ubuntuDistro
}

# Step 4: Git Configuration
Write-Step "Git Configuration"
# Check existing Git configuration
$existingName = Get-WSLCommandOutput "git config --global user.name 2>/dev/null" $ubuntuDistro
$existingEmail = Get-WSLCommandOutput "git config --global user.email 2>/dev/null" $ubuntuDistro

# Always set required git config values (idempotent)
Write-Info "Configuring Git user/email/default branch..."
Invoke-WSLCommand "git config --global user.email '$UserEmail'" "Setting Git user email" $ubuntuDistro
Invoke-WSLCommand "git config --global user.name '$UserName'" "Setting Git user name" $ubuntuDistro
Invoke-WSLCommand "git config --global init.defaultBranch 'main'" "Setting default branch to main" $ubuntuDistro

# Install git-lfs
Write-Info "Ensuring git-lfs is installed..."
Invoke-WSLCommand "sudo apt-get update && sudo apt-get install -y git-lfs" "Installing Git LFS" $ubuntuDistro $sudoPassword
Invoke-WSLCommand "git lfs install" "Configuring Git LFS" $ubuntuDistro

# Credential helper and other config
Write-Info "Configuring Git credential helper and merge tool..."
Invoke-WSLCommand "git config --global credential.helper '/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe'" "Setting credential helper" $ubuntuDistro
Invoke-WSLCommand "git config --global credential.useHttpPath true" "Setting credential.useHttpPath" $ubuntuDistro
Invoke-WSLCommand "git config --global merge.tool vscode" "Setting merge.tool vscode" $ubuntuDistro
Invoke-WSLCommand "git config --global mergetool.vscode.cmd 'code --wait $MERGED'" "Setting mergetool.vscode.cmd" $ubuntuDistro

# Configure Git line endings for cross-platform compatibility in WSL
Write-Info "Configuring Git line endings for cross-platform compatibility in WSL..."
Invoke-WSLCommand "git config --global core.autocrlf false" "Setting Git autocrlf" $ubuntuDistro
Invoke-WSLCommand "git config --global core.eol lf" "Setting Git eol" $ubuntuDistro
Write-Success "Git line endings configured in WSL (LF for Linux/Windows compatibility)"

    # Check Git LFS installation
    $gitLfsVersion = Get-WSLCommandOutput "git lfs version 2>/dev/null" $ubuntuDistro
    if ($gitLfsVersion) {
        # Extract just the version number for cleaner display
        $versionMatch = $gitLfsVersion -match "git-lfs/([0-9]+\.[0-9]+\.[0-9]+)"
        if ($versionMatch) {
            Write-Success "Git LFS is already installed (version: $($matches[1]))"
        } else {
            Write-Success "Git LFS is already installed ($gitLfsVersion)"
        }
    } else {
        # Try to install git-lfs if not present
        Write-Info "Git LFS not found, attempting installation..."
        $installResult = Invoke-WSLCommand "sudo apt-get update && sudo apt-get install -y git-lfs" "Installing Git LFS" $ubuntuDistro $sudoPassword
        if ($installResult) {
            Write-Success "Git LFS installed successfully."
        } else {
            Write-Warning "Git LFS installation may have failed. Attempting to configure anyway..."
        }
        # Try to run git lfs install and capture output
        $lfsInstallResult = Get-WSLCommandOutput "git lfs install 2>&1" $ubuntuDistro
        if ($lfsInstallResult -and $lfsInstallResult -notmatch "fatal|error|not found") {
            Write-Success "Git LFS configured: $lfsInstallResult"
        } else {
            Write-Warning "git lfs install failed: $lfsInstallResult"
            Write-Info "Manual command: wsl -d $ubuntuDistro -- git lfs install"
        }
    }

# Step 5: Docker Setup
Write-Step "Docker Configuration"

if (-not (Test-Command "docker")) {
    Write-Info "Docker not found. Please install Docker Desktop manually:"
    Write-Info "https://www.docker.com/products/docker-desktop/"
    Write-Warning "After installing Docker Desktop, enable WSL 2 integration for $ubuntuDistro in Docker Desktop settings"
} else {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Success "Docker is installed ($dockerVersion)"
        } else {
            Write-Success "Docker is installed"
        }
        
        # Configure Docker for Linux containers
        Write-Info "Configuring Docker for Linux containers..."
        
        # Check if Docker Desktop CLI is available for engine switching
        if (Test-Command "dockerdesktop") {
            Write-Info "Switching to Linux containers for WSL development..."
            try {
                & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchLinuxEngine 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Docker configured for Linux containers"
                } else {
                    Write-Warning "Docker engine switch may have failed, but continuing..."
                }
            } catch {
                Write-Warning "Could not switch Docker engine automatically. Please ensure Linux containers are enabled in Docker Desktop."
            }
        } else {
            # Alternative approach using Docker Desktop executable directly
            $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerDesktopPath) {
                Write-Info "Configuring Docker for Linux containers..."
                Write-Host "  Please ensure Linux containers are enabled in Docker Desktop settings" -ForegroundColor Yellow
            } else {
                Write-Warning "Docker Desktop not found in default location. Please configure engine manually."
            }
        }
        
        # Create agent network
        try {
            $networks = docker network ls --filter name=agent-network --format "{{.Name}}" 2>$null
            if ($networks -notcontains "agent-network") {
                docker network create agent-network 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Created agent-network for MCP development"
                }
            } else {
                Write-Success "agent-network already exists"
            }
        } catch {
            Write-Warning "Could not create agent-network. Ensure Docker is running."
        }
    } catch {
        Write-Success "Docker is installed"
    }
}

# Clear sudo password from memory for security
if ($sudoPassword) {
    $sudoPassword.Dispose()
    Write-Info "Cleared sudo credentials from memory"
}

# Final summary
Write-Step "Linux/WSL Environment Summary" "Green"
Write-Success "✓ WSL Ubuntu-24.04 configured and ready"
Write-Success "✓ Python development environment set up in WSL"
Write-Success "✓ Package management tools (pipx, Poetry) installed in WSL"
Write-Success "✓ Git configuration completed in WSL"
Write-Success "✓ Docker network prepared for development"

Write-Info "`nLinux/WSL development environment is ready!"
Write-Info "You can now use this environment for StrangeLoop development."

# Script completion
exit 0

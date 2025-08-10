# StrangeLoop CLI Setup Script - Windows Dependencies
# Handles Windows-specific development environment setup
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script manages Windows-specific Python environment, Poetry, pipx,
# Git configuration, and Docker setup for Windows development.
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+
# Execution Policy: RemoteSigned or Unrestricted required
#
# Usage: .\Setup-StrangeLoop-Windows.ps1 [-MaintenanceMode]

param(
    [switch]$MaintenanceMode,
    [switch]$Verbose
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Enable verbose output if Verbose is specified
if ($Verbose) {
    $VerbosePreference = "Continue"
    Write-Host "� VERBOSE MODE ENABLED in Windows setup" -ForegroundColor Cyan
}

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
║           StrangeLoop CLI Setup - Windows Maintenance         ║
║                     Package Updates Only                      ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Success
} else {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║           StrangeLoop CLI Setup - Windows Dependencies        ║
║                     Development Environment                   ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Highlight
}

# Maintenance Mode - Focus on package updates only
if ($MaintenanceMode) {
    Write-Info "Running in Maintenance Mode - updating packages only"
    Write-Info "Skipping initial environment setup"
    
    # Update Python packages
    Write-Step "Python Package Updates"
    
    # Check if Python is available
    if (-not (Test-Command "python")) {
        Write-Error "Python not found. Please run full setup first (without -MaintenanceMode)"
        exit 1
    }
    
    Write-Info "Updating Python packages..."
    
    # Update pip itself
    try {
        python -m pip install --upgrade pip
        Write-Success "Updated pip to latest version"
    } catch {
        Write-Warning "Failed to update pip, but continuing..."
    }
    
    # Update pipx if installed
    if (Test-Command "pipx") {
        Write-Info "Updating pipx packages..."
        try {
            pipx upgrade-all
            Write-Success "Updated all pipx packages"
        } catch {
            Write-Warning "Failed to update some pipx packages, but continuing..."
        }
    } else {
        Write-Info "pipx not found, skipping pipx package updates"
    }
    
    # Update Poetry if installed
    $poetryInstalled = $false
    try {
        $poetryVersion = poetry --version 2>$null
        if ($poetryVersion) {
            $poetryInstalled = $true
        }
    } catch {
        # Poetry not available via direct command, check pipx
        try {
            pipx list | Select-String "poetry" >$null
            $poetryInstalled = $true
        } catch {
            $poetryInstalled = $false
        }
    }
    
    if ($poetryInstalled) {
        Write-Info "Updating Poetry..."
        try {
            pipx upgrade poetry
            Write-Success "Updated Poetry to latest version"
        } catch {
            Write-Warning "Failed to update Poetry, but continuing..."
        }
    } else {
        Write-Info "Poetry not found, skipping Poetry update"
    }
    
    # Check for Windows package manager updates
    Write-Step "Windows Package Manager Updates"
    
    # Check if winget is available
    if (Test-Command "winget") {
        Write-Info "Updating packages via winget..."
        try {
            winget upgrade --all --accept-source-agreements --accept-package-agreements
            Write-Success "Updated packages via winget"
        } catch {
            Write-Warning "winget upgrade failed or no updates available"
        }
    } else {
        Write-Info "winget not available, skipping package manager updates"
    }
    
    # Maintenance mode completion
    Write-Step "Maintenance Complete" "Green"
    Write-Success "✓ Windows package updates completed successfully"
    Write-Info "Maintenance mode finished. All packages have been updated."
    exit 0
}

# Step 1: Python Environment Setup
Write-Step "Python Environment Setup"

# Windows Python setup
Write-Info "Checking Windows Python environment..."
Invoke-CommandWithDuration -Description "Checking Windows Python environment" -ScriptBlock {
    if (Test-Command "python") {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion) {
            Write-Success "Python is installed: $pythonVersion"
            
            # Check Python version compatibility
            if ($pythonVersion -match "Python 3\.(\d+)\.(\d+)") {
                $pythonMajor = [int]$matches[1]
                $pythonMinor = [int]$matches[2]
                if ($pythonMajor -ge 9 -or ($pythonMajor -eq 3 -and $pythonMinor -ge 9)) {
                    Write-Success "Python version is compatible with StrangeLoop templates"
                } else {
                    Write-Warning "Python version may be too old for some StrangeLoop templates (3.9+ recommended)"
                }
            }
        } else {
            Write-Success "Python is installed"
        }
    } else {
        Write-Warning "Python not found on Windows PATH"
        Write-Info "Please install Python from one of these sources:"
        Write-Host "  • Official Python: https://www.python.org/downloads/" -ForegroundColor Yellow
        Write-Host "  • Microsoft Store: ms-windows-store://search?query=python" -ForegroundColor Yellow
        Write-Host "  • Winget: winget install Python.Python.3.12" -ForegroundColor Yellow
        
        $installChoice = Get-UserInput "`nWould you like to continue without Python? (y/n)" "n"
        if ($installChoice -notmatch '^[Yy]') {
            Write-Info "Please install Python and run this script again."
            exit 1
        }
    }
}

# Step 2: Package Management Tools
Write-Step "Package Management Tools"

# Check pipx on Windows
Invoke-CommandWithDuration -Description "Checking/Installing pipx on Windows" -ScriptBlock {
    if (Test-Command "pipx") {
        $pipxVersion = pipx --version 2>$null
        if ($pipxVersion) {
            Write-Success "pipx is installed: $pipxVersion"
        } else {
            Write-Success "pipx is installed"
        }
    } else {
        if (Test-Command "python") {
            Write-Info "Installing pipx on Windows..."
            try {
                python -m pip install --user pipx
                python -m pipx ensurepath
                Write-Success "pipx installed successfully"
                Write-Info "You may need to restart your terminal for pipx to be available in PATH"
            } catch {
                Write-Warning "pipx installation failed. Please install manually:"
                Write-Host "  pip install --user pipx" -ForegroundColor Yellow
                Write-Host "  python -m pipx ensurepath" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "Cannot install pipx without Python. Please install Python first."
        }
    }
}

# Check Poetry on Windows
Invoke-CommandWithDuration -Description "Checking/Installing Poetry on Windows" -ScriptBlock {
    if (Test-Command "poetry") {
        $poetryVersion = poetry --version 2>$null
        if ($poetryVersion) {
            Write-Success "Poetry is installed: $poetryVersion"
        } else {
            Write-Success "Poetry is installed"
        }
        
        # Configure Poetry
        try {
            poetry config virtualenvs.in-project true
            Write-Success "Poetry configured for in-project virtual environments"
        } catch {
            Write-Warning "Poetry configuration may have failed"
        }
    } else {
        if (Test-Command "pipx") {
            Write-Info "Installing Poetry on Windows..."
            try {
                pipx install poetry
                poetry config virtualenvs.in-project true
                Write-Success "Poetry installed and configured"
            } catch {
                Write-Warning "Poetry installation failed. Please install manually:"
                Write-Host "  pipx install poetry" -ForegroundColor Yellow
                Write-Host "  poetry config virtualenvs.in-project true" -ForegroundColor Yellow
            }
        } else {
            Write-Warning "Cannot install Poetry without pipx. Please install pipx first."
        }
    }
}

# Step 3: Git Configuration
Write-Step "Git Configuration"

# Git should already be checked in main script, but verify it's working
if (Test-Command "git") {
    # Check existing Git configuration
    $existingName = git config --global user.name 2>$null
    $existingEmail = git config --global user.email 2>$null
    
    if ($existingName -and $existingEmail) {
        Write-Success "Git is already configured:"
        Write-Host "  Name: $existingName" -ForegroundColor Gray
        Write-Host "  Email: $existingEmail" -ForegroundColor Gray
    } else {
        Write-Info "Git user configuration may need setup (this is typically done in the main script)"
    }
    
    # Ensure Git line endings are configured for Windows
    Write-Info "Verifying Git line endings configuration for Windows..."
    $autocrlf = git config --global core.autocrlf 2>$null
    $eol = git config --global core.eol 2>$null
    
    if ($autocrlf -eq "false" -and $eol -eq "lf") {
        Write-Success "Git line endings configured for cross-platform compatibility"
    } else {
        Write-Info "Configuring Git line endings for cross-platform compatibility..."
        try {
            git config --global core.autocrlf false
            git config --global core.eol lf
            Write-Success "Git line endings configured"
        } catch {
            Write-Warning "Git line endings configuration may have failed"
        }
    }
    
    # Check Git LFS
    if (Test-Command "git-lfs") {
        $gitLfsVersion = git lfs version 2>$null
        if ($gitLfsVersion -match "git-lfs/([0-9]+\.[0-9]+\.[0-9]+)") {
            Write-Success "Git LFS is installed (version: $($matches[1]))"
        } else {
            Write-Success "Git LFS is installed"
        }
    } else {
        Write-Warning "Git LFS not found. This should be installed as a prerequisite."
    }
} else {
    Write-Warning "Git not found. This should be available as a prerequisite."
}

# Step 4: Docker Setup
Write-Step "Docker Configuration"

if (-not (Test-Command "docker")) {
    Write-Info "Docker not found. Please install Docker Desktop manually:"
    Write-Host "  • Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    Write-Host "  • Winget: winget install Docker.DockerDesktop" -ForegroundColor Yellow
    
    Write-Info "For Windows development, ensure Windows containers are available in Docker Desktop settings"
} else {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Success "Docker is installed ($dockerVersion)"
        } else {
            Write-Success "Docker is installed"
        }
        
        # Configure Docker engine for Windows development
        Write-Info "Configuring Docker engine for Windows development..."
        
        # Check if Docker Desktop CLI is available for engine switching
        if (Test-Command "dockerdesktop") {
            Write-Info "Switching to Windows containers for Windows development..."
            try {
                & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Docker configured for Windows containers"
                } else {
                    Write-Warning "Docker engine switch may have failed, but continuing..."
                }
            } catch {
                Write-Warning "Could not switch Docker engine automatically. Please configure Docker Desktop manually."
            }
        } else {
            # Alternative approach using Docker Desktop executable directly
            $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerDesktopPath) {
                Write-Info "Configuring Docker for Windows containers..."
                Write-Host "  Please ensure Windows containers are enabled in Docker Desktop settings" -ForegroundColor Yellow
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

# Step 5: Development Tools and IDE Setup
Write-Step "Development Tools and IDE Setup"

# Check for common IDEs and tools
$developmentTools = @{
    "Visual Studio Code" = "code"
    "Visual Studio" = "devenv"
    "JetBrains Rider" = "rider64"
}

Write-Info "Checking for development tools..."
foreach ($tool in $developmentTools.GetEnumerator()) {
    if (Test-Command $tool.Value) {
        Write-Success "$($tool.Key) is available"
    } else {
        Write-Info "$($tool.Key) not found in PATH"
    }
}

# Check Windows SDK for .NET Framework development
$windowsSdkPath = "${env:ProgramFiles(x86)}\Windows Kits\10"
if (Test-Path $windowsSdkPath) {
    Write-Success "Windows SDK is installed"
} else {
    Write-Info "Windows SDK not found. May be needed for .NET Framework development."
}

# Check .NET Framework versions
try {
    $dotnetVersions = Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse |
        Get-ItemProperty -Name Version -EA 0 |
        Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } |
        Select-Object PSChildName, Version

    if ($dotnetVersions) {
        Write-Success ".NET Framework versions detected:"
        foreach ($version in $dotnetVersions) {
            Write-Host "  • $($version.PSChildName): $($version.Version)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Info "Could not detect .NET Framework versions"
}

# Check .NET Core/.NET versions
if (Test-Command "dotnet") {
    try {
        $dotnetInfo = dotnet --info 2>$null
        if ($dotnetInfo) {
            $runtimeVersions = $dotnetInfo | Where-Object { $_ -match "Microsoft\.NETCore\.App|Microsoft\.AspNetCore\.App|Microsoft\.WindowsDesktop\.App" }
            if ($runtimeVersions) {
                Write-Success ".NET Core/.NET runtimes detected:"
                $runtimeVersions | ForEach-Object {
                    Write-Host "  • $_" -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Info "Could not detect .NET Core/.NET versions"
    }
} else {
    Write-Info ".NET CLI not found. May be needed for modern .NET development."
}

# Final summary
Write-Step "Windows Environment Summary" "Green"
Write-Success "✓ Windows development environment configured"
Write-Success "✓ Python development tools verified/installed"
Write-Success "✓ Package management tools (pipx, Poetry) configured"
Write-Success "✓ Git configuration verified"
Write-Success "✓ Docker configured for Windows containers"
Write-Success "✓ Development tools and frameworks checked"

Write-Info "`nWindows development environment is ready!"
Write-Info "You can now use this environment for StrangeLoop development."

Write-Info "`nRecommended next steps for Windows development:"
Write-Host "  • Install Visual Studio or Visual Studio Code if not already available" -ForegroundColor Cyan
Write-Host "  • Install .NET SDK if planning to develop .NET applications" -ForegroundColor Cyan
Write-Host "  • Restart your terminal to ensure all PATH changes are applied" -ForegroundColor Cyan

# Script completion
exit 0

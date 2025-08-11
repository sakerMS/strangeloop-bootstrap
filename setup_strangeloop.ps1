# StrangeLoop CLI Setup Script - Single Script Version
# Complete standalone setup for StrangeLoop CLI development environment
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 6.1 - Single Script Architecture
# Created: August 2025
# 
# This standalone script provides complete StrangeLoop CLI setup with automatic
# prerequisite checks and package updates for maximum simplicity.
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+
# Execution Policy: RemoteSigned or Unrestricted required
#
# Usage: .\setup_strangeloop.ps1

param()

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Display banner
Write-Host @"
 
╔═══════════════════════════════════════════════════════════════╗
║              StrangeLoop CLI Setup - Complete Setup           ║
║                    Unified Architecture                       ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host " " -ForegroundColor White
Write-Host "StrangeLoop CLI Bootstrap Setup (Complete)" -ForegroundColor White
Write-Host "This script will install and configure StrangeLoop CLI with environment-specific delegation" -ForegroundColor Gray
Write-Host " " -ForegroundColor White

#region Helper Functions

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

function Open-VSCode {
    param(
        [string]$Path,
        [bool]$IsWSL,
        [string]$Distribution = ""
    )
    
    Write-Info "Opening VS Code for path: $Path"
    
    try {
        if ($IsWSL) {
            # For WSL, execute code command from within WSL itself, ensuring we're in the right directory
            if ($Distribution) {
                Write-Info "Launching VS Code from within WSL ($Distribution)"
                # Use absolute path and ensure we change to the directory first
                $wslCommand = "cd '$Path' && pwd && code ."
                $result = wsl -d $Distribution -- bash -c $wslCommand
                Write-Info "WSL command result: $result"
            } else {
                Write-Info "Launching VS Code from within default WSL"
                # Use absolute path and ensure we change to the directory first
                $wslCommand = "cd '$Path' && pwd && code ."
                $result = wsl -- bash -c $wslCommand
                Write-Info "WSL command result: $result"
            }
        } else {
            # For Windows, use standard path
            Write-Info "Opening in Windows mode"
            Start-Process -FilePath "code" -ArgumentList @($Path) -NoNewWindow
        }
        Write-Success "VS Code launched for project"
    } catch {
        Write-Warning "Could not automatically open VS Code: $($_.Exception.Message)"
        Write-Info "You can manually open VS Code and navigate to: $Path"
        if ($IsWSL) {
            if ($Distribution) {
                Write-Info "Manual command: wsl -d $Distribution -- bash -c `"cd '$Path' && code .`""
            } else {
                Write-Info "Manual command: wsl -- bash -c `"cd '$Path' && code .`""
            }
        }
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
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Error "PowerShell 5.1 or higher is required. Current version: $($psVersion.ToString())"
    exit 1
}
Write-Success "PowerShell version: $($psVersion.ToString())"
    
    # Check execution policy
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
    
# Check basic tools
$requiredTools = @("git", "curl")
foreach ($tool in $requiredTools) {
    if (Test-Command $tool) {
        Write-Success "$tool is available"
    } else {
        Write-Warning "$tool is not installed - will install during setup"
    }
}

#endregion

#region StrangeLoop Installation

Write-Step "Azure Authentication & StrangeLoop Installation"

# Check if StrangeLoop is already installed
if (Test-Command "strangeloop") {
    Write-Success "StrangeLoop CLI is already installed"
    $version = strangeloop --version 2>$null
    if ($version) {
        Write-Info "Current version: $version"
    }
} else {
    Write-Info "StrangeLoop CLI not found - installation will be required"
    Write-Warning "Please install StrangeLoop CLI manually and run this script again"
    Write-Info "Installation instructions: https://github.com/your-org/strangeloop"
    exit 1
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
                if ($line -match "^([a-zA-Z0-9-]+)\s+(.+)$") {
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
    
    # Derive environment requirements from selected loop
    $needsLinux = $linuxRequiredLoops -contains $selectedLoop.Name
    $isWindowsOnly = $windowsCompatibleLoops -contains $selectedLoop.Name
    
    # Check WSL availability only when needed
    $wslAvailable = $false
    if ($needsLinux -or (-not $isWindowsOnly)) {
        Write-Step "Checking WSL Availability"
        $wslAvailable = Test-WSL
        if ($wslAvailable) {
            Write-Success "WSL is available for Linux development environments"
        } else {
            Write-Info "WSL not available - Windows-only development mode"
        }
    }
    
    if ($needsLinux) {
        if (-not $wslAvailable) {
            Write-Error "Selected loop '$($selectedLoop.Name)' requires WSL/Linux environment, but WSL is not available."
            Write-Info "Please install WSL or choose a Windows-compatible loop."
            exit 1
        }
        Write-Success "Environment: WSL/Linux (required for $($selectedLoop.Name))"
        Write-Info "This loop requires Linux development environment"
    } elseif ($isWindowsOnly) {
        $needsLinux = $false
        Write-Success "Environment: Windows native (required for $($selectedLoop.Name))"
        Write-Info "This loop is designed for Windows development"
    } else {
        # Universal loop - let user choose if WSL is available
        if ($wslAvailable) {
            Write-Info "`nThis loop supports both environments. Choose your preference:"
            Write-Host "  1. WSL/Linux (recommended for modern development)" -ForegroundColor Green
            Write-Host "  2. Windows native (enterprise/.NET Framework projects)" -ForegroundColor White
            
            $envChoice = Get-UserInput "Select environment (1-2)" "1"
            $needsLinux = ($envChoice -eq "1")
            
            if ($needsLinux) {
                Write-Success "Environment: WSL/Linux (user preference)"
                Write-Info "Using Linux development environment"
            } else {
                Write-Success "Environment: Windows native (user preference)" 
                Write-Info "Using Windows development environment"
            }
        } else {
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
            $wslDistro = "Ubuntu-24.04"
            # Detect WSL user once to avoid placeholder issues
            $detectedWslUser = $null
            try {
                $detectedWslUser = (wsl -d $wslDistro -- bash -lc 'whoami' 2>$null)
                if ($detectedWslUser) { $detectedWslUser = $detectedWslUser.Trim() }
            } catch { }
            if (-not $detectedWslUser) {
                try { $detectedWslUser = (wsl -- bash -lc 'whoami' 2>$null).Trim() } catch { }
            }

            $defaultAppDir = if ($detectedWslUser) { "/home/$detectedWslUser/projects/$appName" } else { "/home/`$(whoami)/projects/$appName" }
            Write-Info "Using WSL environment for project initialization"
            $appDir = Get-UserInput "Application directory (WSL path)" $defaultAppDir
            # Resolve any placeholders in the provided path
            $appDirResolved = Resolve-WSLPath -Path $appDir -Distribution $wslDistro
            
            # Create directory in WSL and check for existing projects
        Write-Info "Creating application directory in WSL: $appDirResolved"
            
            # Check if directory already exists and handle accordingly
        $dirCheckCommand = "if [ -d '$appDirResolved' ]; then echo 'EXISTS'; else echo 'NOT_EXISTS'; fi"
        $dirExists = wsl -- bash -c $dirCheckCommand
            
            $shouldInitialize = $true
            if ($dirExists -eq "EXISTS") {
                Write-Warning "Directory '$appDir' already exists"
                
                # Check if it's already a StrangeLoop project
                $isStrangeLoopCommand = "cd '$appDirResolved' && if [ -d './strangeloop' ]; then echo 'YES'; else echo 'NO'; fi"
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
                        wsl -- bash -c $cleanCommand
                    }
                } else {
                    # Directory exists but not a StrangeLoop project
                    $hasFilesCommand = "cd '$appDirResolved' && find . -maxdepth 1 -type f | wc -l"
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
                wsl -- bash -c "mkdir -p '$appDirResolved'"
            }
            
            # Initialize project in WSL (only if needed)
            if ($shouldInitialize) {
                Write-Info "Initializing $($selectedLoop.Name) loop in WSL environment..."
                $initCommand = "cd '$appDirResolved' && strangeloop init --loop $($selectedLoop.Name)"
                Write-Info "initCommand: $initCommand"
                Write-Info "Running: wsl -- bash -c \"$initCommand\""
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
                wsl -- bash -c $updateCommand
                
                # Run strangeloop recurse to apply configuration changes
                Write-Info "Applying configuration changes..."
                $recurseCommand = "cd '$appDirResolved' && strangeloop recurse"
                wsl -- bash -c $recurseCommand
                
                # Provide access instructions
                Write-Info "`nTo access your project:"
                Write-Host "  WSL: cd '$appDirResolved'" -ForegroundColor Yellow
                Write-Host "  Windows: \\wsl.localhost\$wslDistro$appDirResolved" -ForegroundColor Yellow
                Write-Host "  VS Code: code '$appDirResolved' (from WSL terminal)" -ForegroundColor Yellow

                # Open VS Code for the initialized project in WSL
                Open-VSCode -Path $appDirResolved -IsWSL:$true -Distribution $wslDistro
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

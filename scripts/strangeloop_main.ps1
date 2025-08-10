# StrangeLoop CLI Setup Script - Main Entry Point
# Automated setup following readme.md requirements
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script handles initial setup, StrangeLoop installation, loop analysis,
# calls appropriate OS-specific scripts, and completes project initialization.
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+
# Execution Policy: RemoteSigned or Unrestricted required
#
# Usage: .\strangeloop_main.ps1 [-SkipPrerequisites] [-SkipDevelopmentTools] [-MaintenanceMode] [-UserName "Name"] [-UserEmail "email@domain.com"]

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipDevelopmentTools,
    [switch]$MaintenanceMode,
    [switch]$Verbose,
    [string]$UserName,
    [string]$UserEmail,
    [string]$LinuxScriptUrl,
    [string]$WindowsScriptUrl
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Enable verbose output if Verbose is specified
if ($Verbose) {
    $VerbosePreference = "Continue"
    Write-Host "� VERBOSE MODE ENABLED in main orchestrator" -ForegroundColor Cyan
}

# Function to download script content
function Get-ScriptFromUrl {
    param([string]$Url, [string]$ScriptName)
    
    Write-Verbose "Downloading $ScriptName from $Url"
    Write-Host "Downloading $ScriptName..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Verbose "Download successful, content length: $($response.Content.Length) characters"
            Write-Host "✓ $ScriptName downloaded successfully" -ForegroundColor Green
            return $response.Content
        } else {
            throw "HTTP $($response.StatusCode)"
        }
    } catch {
        Write-Verbose "Download failed: $($_.Exception.Message)"
        Write-Host "✗ Failed to download $ScriptName from $Url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to execute script content with parameters
function Invoke-ScriptContent {
    param([string]$ScriptContent, [hashtable]$Parameters = @{})
    
    Write-Verbose "Creating temporary script for execution"
    # Create a temporary script file
    $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".ps1"
    
    try {
        # Write script content to temp file
        Set-Content -Path $tempScriptPath -Value $ScriptContent -Encoding UTF8
        
        # Build parameter array for splatting
        $paramSplat = @{}
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [switch] -and $Parameters[$key]) {
                $paramSplat[$key] = $true
                Write-Verbose "Added switch parameter: -$key"
            } elseif ($Parameters[$key] -and $Parameters[$key] -ne $false) {
                $paramSplat[$key] = $Parameters[$key]
                Write-Verbose "Added parameter: -$key = '$($Parameters[$key])'"
            }
        }
        
        Write-Verbose "Executing script with splatted parameters"
        # Execute the script
        try {
            & $tempScriptPath @paramSplat
            # If no exception was thrown, consider it successful
            return 0
        } catch {
            # If an exception was thrown, it failed
            Write-Verbose "Script execution failed: $($_.Exception.Message)"
            return 1
        }
    } finally {
        # Clean up temp file
        if (Test-Path $tempScriptPath) {
            Remove-Item $tempScriptPath -Force -ErrorAction SilentlyContinue
        }
    }
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
    Write-Verbose "Testing command availability: $Command"
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            Write-Verbose "Command '$Command' found"
            return $true
        }
        Write-Verbose "Command '$Command' not found"
        return $false
    } catch {
        Write-Verbose "Error testing command '$Command': $($_.Exception.Message)"
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
Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║              StrangeLoop CLI Setup - Main Entry               ║
║                     Automated Installation                    ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Highlight

if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Error "Execution policy is Restricted. Please change it to RemoteSigned or Unrestricted."
    exit 1
}

# Maintenance Mode - Skip to OS-specific package updates only
if ($MaintenanceMode) {
    Write-Verbose "MaintenanceMode enabled - skipping to package updates"
    Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║              StrangeLoop CLI Setup - Maintenance Mode         ║
║                    Package Updates Only                       ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Success
    
    Write-Info "Running in Maintenance Mode - updating packages only"
    Write-Info "Skipping StrangeLoop installation and template analysis"
    
    # Jump directly to OS-specific setup
    # Determine platform quickly for maintenance
    Write-Step "Determining Platform for Package Updates"
    Write-Verbose "Starting platform detection for maintenance mode"
    $needsLinux = $true  # Default to Linux/WSL for maintenance
    
    # Quick WSL check - if WSL is available and has distributions, prefer it
    if (Test-Command "wsl") {
        Write-Verbose "WSL command found, checking for distributions"
        $wslDistros = wsl -l -v 2>$null
        if ($wslDistros -and ($wslDistros | Where-Object { $_ -match "Ubuntu" })) {
            $needsLinux = $true
            Write-Verbose "Ubuntu WSL distribution found - selecting Linux path"
            Write-Info "Found WSL Ubuntu - will update Linux environment"
        } else {
            $needsLinux = $false
            Write-Verbose "No Ubuntu WSL distribution found - selecting Windows path"
            Write-Info "No WSL Ubuntu found - will update Windows environment"
        }
    } else {
        $needsLinux = $false
        Write-Info "WSL not available - will update Windows environment"
    }
    
    # Jump to Step 4 (OS-specific setup)
    Write-Step "Updating Development Environment Packages"
    
    if ($needsLinux) {
        Write-Info "Updating Linux/WSL environment packages..."
        if ($LinuxScriptUrl) {
            Write-Info "Downloading Linux setup script from: $LinuxScriptUrl"
            try {
                $linuxScriptContent = Get-ScriptFromUrl $LinuxScriptUrl "strangeloop_linux.ps1"
                
                $linuxParams = @{}
                if ($UserName) { $linuxParams.UserName = $UserName }
                if ($UserEmail) { $linuxParams.UserEmail = $UserEmail }
                if ($MaintenanceMode) { $linuxParams.MaintenanceMode = $MaintenanceMode }
                if ($Verbose) { $linuxParams.Verbose = $Verbose }
                
                if ($Verbose) {
                    Write-Verbose "Parameters for Linux script (maintenance):"
                    foreach ($param in $linuxParams.GetEnumerator()) {
                        Write-Verbose "- $($param.Key): $($param.Value)"
                    }
                }
                
                $exitCode = Invoke-ScriptContent $linuxScriptContent $linuxParams
                if ($exitCode -ne 0) {
                    Write-Error "Linux/WSL package update failed with exit code: $exitCode"
                    exit 1
                }
                Write-Success "Linux/WSL package update completed successfully"
            } catch {
                Write-Error "Failed to download or execute Linux setup script: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Error "Linux setup script URL not provided"
            exit 1
        }
    } else {
        Write-Info "Updating Windows environment packages..."
        if ($WindowsScriptUrl) {
            Write-Info "Downloading Windows setup script from: $WindowsScriptUrl"
            try {
                $windowsScriptContent = Get-ScriptFromUrl $WindowsScriptUrl "strangeloop_windows.ps1"
                
                $windowsParams = @{}
                if ($MaintenanceMode) { $windowsParams.MaintenanceMode = $MaintenanceMode }
                if ($Verbose) { $windowsParams.Verbose = $Verbose }
                
                if ($Verbose) {
                    Write-Verbose "Parameters for Windows script (maintenance):"
                    foreach ($param in $windowsParams.GetEnumerator()) {
                        Write-Verbose "- $($param.Key): $($param.Value)"
                    }
                }
                
                $exitCode = Invoke-ScriptContent $windowsScriptContent $windowsParams
                if ($exitCode -ne 0) {
                    Write-Error "Windows package update failed with exit code: $exitCode"
                    exit 1
                }
                Write-Success "Windows package update completed successfully"
            } catch {
                Write-Error "Failed to download or execute Windows setup script: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Error "Windows setup script URL not provided"
            exit 1
        }
    }
    
    # Maintenance mode completion
    Write-Step "Maintenance Complete" "Green"
    Write-Success "✓ Package updates completed successfully"
    Write-Info "Maintenance mode finished. All packages have been updated."
    exit 0
}

# Step 1: Prerequisites Check
if (-not $SkipPrerequisites) {
    Write-Step "Checking Prerequisites"
    
    $prerequisites = @{
        "Azure CLI" = "az"
        "Git" = "git"
        "Git LFS" = "git-lfs"
    }
    
    $missingPrereqs = @()
    
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        Invoke-CommandWithDuration -Description "Checking $($prereq.Key)" -ScriptBlock {
            if (Test-Command $prereq.Value) {
                # Get version information for better visibility
                $version = ""
                try {
                    switch ($prereq.Value) {
                        "az" { $version = (az version --output json 2>$null | ConvertFrom-Json).'azure-cli' }
                        "git" { $version = (git --version 2>$null) -replace "git version ", "" }
                        "git-lfs" { 
                            $lfsOutput = git lfs version 2>$null
                            if ($lfsOutput -match "git-lfs/([0-9]+\.[0-9]+\.[0-9]+)") {
                                $version = $matches[1]
                            }
                        }
                    }
                    if ($version) {
                        Write-Success "$($prereq.Key) is installed (version: $version)"
                    } else {
                        Write-Success "$($prereq.Key) is installed"
                    }
                } catch {
                    Write-Success "$($prereq.Key) is installed"
                }
                return $true
            } else {
                Write-Error "$($prereq.Key) is missing"
                $missingPrereqs += $prereq.Key
                return $false
            }
        }
    }
    
    if ($missingPrereqs.Count -gt 0) {
        Write-Error "Missing prerequisites: $($missingPrereqs -join ', ')"
        Write-Info "Please install the missing prerequisites and run the script again."
        Write-Info "Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
        Write-Info "Git LFS: https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage"
        exit 1
    }
    
    # Configure Git mergetool if not set
    $mergetool = git config --global merge.tool 2>$null
    if (-not $mergetool) {
        Invoke-CommandWithDuration -Description "Configuring VS Code as Git mergetool" -ScriptBlock {
            git config --global merge.tool vscode
            git config --global mergetool.vscode.cmd 'code --wait $MERGED'
            git config --global diff.tool vscode
            git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
            Write-Success "Git mergetool configured"
        }
    }
    
    # Configure Git line endings for cross-platform compatibility
    Invoke-CommandWithDuration -Description "Configuring Git line endings for cross-platform compatibility" -ScriptBlock {
        git config --global core.autocrlf false
        git config --global core.eol lf
        Write-Success "Git line endings configured (LF for Linux/Windows compatibility)"
    }
}

# Step 2: Azure Login & StrangeLoop Installation
Write-Step "Azure Authentication & StrangeLoop Installation"

# Azure login
Write-Info "Checking Azure authentication..."
try {
    Invoke-CommandWithDuration -Description "Checking Azure authentication" -ScriptBlock {
        # Check if already logged in
        $currentAccount = az account show --output json 2>$null | ConvertFrom-Json
        if ($currentAccount -and $currentAccount.user) {
            Write-Success "Already logged into Azure as: $($currentAccount.user.name)"
            Write-Host "  Subscription: $($currentAccount.name)" -ForegroundColor Gray
        } else {
            Write-Info "Not logged in, initiating Azure login..."
            az login --only-show-errors 2>&1 | Out-Null
            Write-Success "Azure login successful"
        }
        
        # Try to set AdsFPS subscription
        $subscriptions = az account list --query "[?name=='AdsFPS Subscription'].{name:name,id:id}" --output json 2>$null | ConvertFrom-Json
        if ($subscriptions) {
            az account set --subscription $subscriptions[0].id
            Write-Success "AdsFPS Subscription activated"
        } else {
            Write-Warning "AdsFPS Subscription not found, using current subscription"
        }
    }
} catch {
    Write-Error "Azure authentication failed. Please run 'az login' manually."
    exit 1
}

# Check StrangeLoop installation
Write-Info "Checking StrangeLoop installation..."
Invoke-CommandWithDuration -Description "Checking StrangeLoop installation" -ScriptBlock {
    if (Test-Command "strangeloop") {
        try {
            $strangeloopVersion = strangeloop --version 2>$null
            if ($strangeloopVersion) {
                Write-Success "StrangeLoop is already installed (version: $strangeloopVersion)"
            } else {
                Write-Success "StrangeLoop is already installed"
            }
        } catch {
            Write-Success "StrangeLoop is already installed"
        }
        return $true
    } else {
        Write-Info "Installing StrangeLoop..."
        try {
            # Download if not exists
            if (-not (Test-Path "strangeloop.msi")) {
                az artifacts universal download --organization "https://msasg.visualstudio.com/" --project "Bing_Ads" --scope project --feed "strangeloop" --name "strangeloop-x86" --version "*" --path . --only-show-errors
            }
            
            # Install
            Write-Info "Starting StrangeLoop installer (please complete manually)..."
            Start-Process "strangeloop.msi" -Wait
            
            # Cleanup
            Remove-Item "strangeloop.msi" -Force -ErrorAction SilentlyContinue
            
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            if (Test-Command "strangeloop") {
                Write-Success "StrangeLoop installed successfully"
            } else {
                Write-Warning "StrangeLoop installation may require terminal restart"
            }
            return $true
        } catch {
            Write-Error "StrangeLoop installation failed: $($_.Exception.Message)"
            exit 1
        }
    }
}

# Step 3: Get Available Loops and Determine Environment Requirements
Write-Step "Loop Analysis & Environment Requirements"

# Get available loops first to help with environment decision
$availableLoops = @()
try {
    Write-Info "Analyzing available StrangeLoop templates..."
    $loopsOutput = strangeloop library loops 2>$null
    if ($loopsOutput) {
        # Parse loops
        $loopsOutput -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -match "^([a-zA-Z0-9-]+)\s+(.+)$") {
                $availableLoops += @{
                    Name = $matches[1]
                    Description = $matches[2]
                }
            }
        }
        Write-Success "Found $($availableLoops.Count) available loop templates"
    } else {
        Write-Warning "Could not retrieve loops list. Environment choice will be manual."
    }
} catch {
    Write-Warning "Could not retrieve loops list: $($_.Exception.Message). Environment choice will be manual."
}

# Categorize loops by platform requirements (based on actual loop configurations)
$linuxRequiredLoops = @("flask-linux", "python-mcp-server", "python-cli", "python-semantic-kernel-agent", "langgraph-agent", "csharp-mcp-server", "csharp-semantic-kernel-agent", "dotnet-aspire")
$windowsCompatibleLoops = @("flask-windows", "ads-snr-basic", "asp-dotnet-framework-api")

$needsLinux = $false
$selectedTemplate = $null

if (-not $SkipDevelopmentTools) {
    Write-Info "StrangeLoop template platform requirements:"
    Write-Host "  • Linux/WSL required: $($linuxRequiredLoops -join ', ')" -ForegroundColor Yellow
    Write-Host "  • Windows compatible: $($windowsCompatibleLoops -join ', ')" -ForegroundColor Green
    Write-Host "  • WSL provides the best development experience for all templates" -ForegroundColor Gray
    
    if ($availableLoops.Count -gt 0) {
        Write-Info "`nSelect a template to determine environment requirements:"
        for ($i = 0; $i -lt $availableLoops.Count; $i++) {
            $loop = $availableLoops[$i]
            $platform = if ($linuxRequiredLoops -contains $loop.Name) { "[WSL Required]" } 
                       elseif ($windowsCompatibleLoops -contains $loop.Name) { "[Windows OK]" } 
                       else { "[WSL Recommended]" }
            Write-Host "  $($i + 1). $($loop.Name) - $($loop.Description) $platform" -ForegroundColor White
        }
        Write-Host "  0. Configure environment manually (no template selection)" -ForegroundColor Gray
        
        # Get user's template choice
        do {
            $templateChoice = Read-Host "`nSelect template for environment setup (0-$($availableLoops.Count))"
            $validChoice = $templateChoice -match '^\d+$' -and [int]$templateChoice -ge 0 -and [int]$templateChoice -le $availableLoops.Count
            if (-not $validChoice) {
                Write-Warning "Please enter a valid number between 0 and $($availableLoops.Count)"
            }
        } while (-not $validChoice)
        
        if ($templateChoice -eq "0") {
            # Manual environment choice
            Write-Info "`nManual environment configuration:"
            $linuxChoice = Get-UserInput "Do you need Linux/WSL support for your development? (y/n)" "y"
            $needsLinux = $linuxChoice -match '^[Yy]'
            $selectedTemplate = $null
        } else {
            # Automatic environment determination based on template
            $selectedTemplate = $availableLoops[[int]$templateChoice - 1]
            Write-Success "Selected template: $($selectedTemplate.Name)"
            
            if ($linuxRequiredLoops -contains $selectedTemplate.Name) {
                $needsLinux = $true
                Write-Success "WSL environment will be configured (required for $($selectedTemplate.Name))"
            } elseif ($windowsCompatibleLoops -contains $selectedTemplate.Name) {
                # Ask user preference for Windows-compatible templates
                Write-Info "`n$($selectedTemplate.Name) can run on both Windows and WSL."
                Write-Host "  • WSL: Full Linux development experience (recommended)" -ForegroundColor Green
                Write-Host "  • Windows: Native Windows development" -ForegroundColor Yellow
                $envChoice = Get-UserInput "Choose environment for $($selectedTemplate.Name) (WSL/Windows)" "WSL"
                $needsLinux = $envChoice -like "WSL*" -or $envChoice -like "wsl*" -or $envChoice -like "Linux*" -or $envChoice -like "linux*"
                
                if ($needsLinux) {
                    Write-Success "WSL environment will be configured for enhanced development experience"
                } else {
                    Write-Success "Windows-only environment will be configured"
                }
            } else {
                # Unknown template, recommend WSL
                $needsLinux = $true
                Write-Success "WSL environment will be configured (recommended for $($selectedTemplate.Name))"
            }
        }
    } else {
        # No loops available, fall back to manual choice
        Write-Warning "Could not retrieve templates for environment decision."
        $linuxChoice = Get-UserInput "`nDo you need Linux/WSL support for your development? (y/n)" "y"
        $needsLinux = $linuxChoice -match '^[Yy]'
        $selectedTemplate = $null
    }
    
    # Platform selection confirmation
    Write-Info "`n=== Platform Configuration Summary ==="
    if ($needsLinux) {
        Write-Host "  Target Platform: Linux/WSL (Ubuntu-24.04)" -ForegroundColor Gray
        Write-Host "  Development Tools: Python, Poetry, pipx, Git (in WSL)" -ForegroundColor Gray
        Write-Host "  Docker: Linux containers" -ForegroundColor Gray
        if ($selectedTemplate) {
            Write-Host "  Selected Template: $($selectedTemplate.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Target Platform: Windows Native" -ForegroundColor Gray
        Write-Host "  Development Tools: Python, Poetry, pipx, Git (Windows)" -ForegroundColor Gray
        Write-Host "  Docker: Windows containers" -ForegroundColor Gray
        if ($selectedTemplate) {
            Write-Host "  Selected Template: $($selectedTemplate.Name)" -ForegroundColor Gray
        }
    }
    
    $confirmPlatform = Get-UserInput "`nProceed with this platform configuration? (y/n)" "y"
    if ($confirmPlatform -notmatch '^[Yy]') {
        Write-Info "Platform setup cancelled by user."
        Write-Info "You can run this script again to choose a different configuration."
        exit 0
    }
    
    # Step 4: Call appropriate OS-specific setup script
    Write-Step "Setting up Development Environment"
    
    if ($needsLinux) {
        Write-Info "Setting up Linux/WSL environment..."
        if ($LinuxScriptUrl) {
            Write-Info "Downloading Linux setup script from: $LinuxScriptUrl"
            try {
                $linuxScriptContent = Get-ScriptFromUrl $LinuxScriptUrl "strangeloop_linux.ps1"
                
                $linuxParams = @{}
                if ($UserName) { $linuxParams.UserName = $UserName }
                if ($UserEmail) { $linuxParams.UserEmail = $UserEmail }
                if ($MaintenanceMode) { $linuxParams.MaintenanceMode = $MaintenanceMode }
                if ($Verbose) { $linuxParams.Verbose = $Verbose }
                
                $exitCode = Invoke-ScriptContent $linuxScriptContent $linuxParams
                if ($exitCode -ne 0) {
                    Write-Error "Linux/WSL setup failed with exit code: $exitCode"
                    exit 1
                }
                Write-Success "Linux/WSL environment setup completed successfully"
            } catch {
                Write-Error "Failed to download or execute Linux setup script: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Error "Linux setup script URL not provided"
            exit 1
        }
    } else {
        Write-Info "Setting up Windows environment..."
        if ($WindowsScriptUrl) {
            Write-Info "Downloading Windows setup script from: $WindowsScriptUrl"
            try {
                $windowsScriptContent = Get-ScriptFromUrl $WindowsScriptUrl "strangeloop_windows.ps1"
                
                $windowsParams = @{}
                if ($MaintenanceMode) { $windowsParams.MaintenanceMode = $MaintenanceMode }
                if ($Verbose) { $windowsParams.Verbose = $Verbose }
                # Windows script doesn't currently take user parameters, but prepared for future
                
                $exitCode = Invoke-ScriptContent $windowsScriptContent $windowsParams
                if ($exitCode -ne 0) {
                    Write-Error "Windows setup failed with exit code: $exitCode"
                    exit 1
                }
                Write-Success "Windows environment setup completed successfully"
            } catch {
                Write-Error "Failed to download or execute Windows setup script: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Error "Windows setup script URL not provided"
            exit 1
        }
    }
}

# Ask user if they want to continue to loop initialization
Write-Info "`nDevelopment environment setup completed successfully!"
Write-Info "Next step: Initialize a StrangeLoop project template"
$continueToLoop = Get-UserInput "Initialize a project now? (y/n)" "y"
if ($continueToLoop -notmatch '^[Yy]') {
    Write-Step "Setup Completed Successfully!"
    Write-Success "StrangeLoop CLI development environment is ready!"
    Write-Info "Run 'strangeloop init --loop <loop-name>' to create a project later."
    exit 0
}

# Step 5: Loop Initialization and Project Setup
Write-Step "Loop Selection & Initialization"

try {
    # Check if user already selected a template in Step 3
    if ($selectedTemplate) {
        Write-Success "Using pre-selected template: $($selectedTemplate.Name)"
        $selectedLoop = $selectedTemplate
    } else {
        # Use the loops we already retrieved, or get them again if needed
        if ($availableLoops.Count -eq 0) {
            Write-Info "Retrieving available loops..."
            $loopsOutput = strangeloop library loops 2>$null
            if (-not $loopsOutput) {
                Write-Error "Could not retrieve loops. Ensure StrangeLoop is properly installed."
                exit 1
            }
            
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
            Write-Warning "No loops found."
            exit 0
        }
        
        # Filter loops based on environment choice
        $filteredLoops = if ($needsLinux) {
            # Show all loops if WSL is available
            $availableLoops
        } else {
            # Show only Windows-compatible loops
            $availableLoops | Where-Object { $windowsCompatibleLoops -contains $_.Name }
        }
        
        if ($filteredLoops.Count -eq 0) {
            Write-Warning "No compatible loops found for your environment choice."
            Write-Info "Consider enabling WSL support to access all templates."
            exit 0
        }
        
        # Display options with platform indicators
        Write-Info "Available loops for your environment:"
        for ($i = 0; $i -lt $filteredLoops.Count; $i++) {
            $loop = $filteredLoops[$i]
            $platform = if ($linuxRequiredLoops -contains $loop.Name) { "[WSL]" } 
                       elseif ($windowsCompatibleLoops -contains $loop.Name) { "[Win]" } 
                       else { "[Any]" }
            Write-Host "  $($i + 1). $($loop.Name) - $($loop.Description) $platform" -ForegroundColor White
        }
        Write-Host "  0. Skip loop initialization" -ForegroundColor Gray
        
        # Get user choice
        do {
            $choice = Read-Host "Select loop (0-$($filteredLoops.Count))"
            $validChoice = $choice -match '^\d+$' -and [int]$choice -ge 0 -and [int]$choice -le $filteredLoops.Count
            if (-not $validChoice) {
                Write-Warning "Please enter a valid number between 0 and $($filteredLoops.Count)"
            }
        } while (-not $validChoice)
        
        if ($choice -eq "0") {
            Write-Info "Skipping loop initialization."
            Write-Step "Setup Completed Successfully!"
            Write-Success "StrangeLoop CLI is ready to use!"
            exit 0
        }
        
        # Initialize selected loop
        $selectedLoop = $filteredLoops[[int]$choice - 1]
        Write-Success "Selected: $($selectedLoop.Name)"
    }
    
    # Get application details with environment-specific defaults
    $defaultAppName = "my-$($selectedLoop.Name)-app"
    $appName = Get-UserInput "Application name" $defaultAppName
    
    if ($needsLinux) {
        # WSL development - use Linux file system
        $defaultAppDir = "/home/`$(whoami)/projects/$appName"
        Write-Info "Using WSL environment for project initialization"
        $appDir = Get-UserInput "Application directory (WSL path)" $defaultAppDir
        
        # Create directory in WSL and check for existing projects
        Write-Info "Creating application directory in WSL: $appDir"
        
        # Check if directory already exists and handle accordingly
        $dirCheckCommand = "if [ -d '$appDir' ]; then echo 'EXISTS'; else echo 'NOT_EXISTS'; fi"
        $dirExists = wsl -- bash -c $dirCheckCommand
        
        $shouldInitialize = $true
        if ($dirExists -eq "EXISTS") {
            Write-Warning "Directory '$appDir' already exists"
            
            # Check if it's already a StrangeLoop project
            $isStrangeLoopCommand = "cd '$appDir' && if [ -d './strangeloop' ]; then echo 'YES'; else echo 'NO'; fi"
            $isStrangeLoopProject = wsl -- bash -c $isStrangeLoopCommand
            
            if ($isStrangeLoopProject -eq "YES") {
                Write-Warning "Directory appears to be an existing StrangeLoop project"
                $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "n"
                if ($overwriteChoice -notmatch '^[Yy]') {
                    Write-Info "Skipping initialization. Using existing project directory."
                    $shouldInitialize = $false
                } else {
                    Write-Info "Cleaning existing project and reinitializing..."
                    $cleanCommand = "cd '$appDir' && rm -rf ./* ./.*[^.] 2>/dev/null || true"
                    wsl -- bash -c $cleanCommand
                }
            } else {
                # Directory exists but not a StrangeLoop project
                $hasFilesCommand = "cd '$appDir' && find . -maxdepth 1 -type f | wc -l"
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
            wsl -- bash -c "mkdir -p '$appDir'"
        }
        
        # Initialize project in WSL (only if needed)
        if ($shouldInitialize) {
            Write-Info "Initializing $($selectedLoop.Name) loop in WSL environment..."
            $initCommand = "cd '$appDir' && strangeloop init --loop $($selectedLoop.Name)"
            wsl -- bash -c $initCommand
        } else {
            Write-Info "Using existing StrangeLoop project directory"
        }
        
        if ($LASTEXITCODE -eq 0 -or -not $shouldInitialize) {
            if ($shouldInitialize) {
                Write-Success "Loop initialized successfully in WSL!"
            } else {
                Write-Success "Using existing StrangeLoop project in WSL!"
            }
            
            # Update settings.yaml with project name
            Write-Info "Updating project settings..."
            $updateCommand = "cd '$appDir' && if [ -f './strangeloop/settings.yaml' ]; then sed -i 's/^name:.*/name: $appName/' './strangeloop/settings.yaml'; fi"
            wsl -- bash -c $updateCommand
            
            # Run strangeloop recurse to apply configuration changes
            Write-Info "Applying configuration changes..."
            $recurseCommand = "cd '$appDir' && strangeloop recurse"
            wsl -- bash -c $recurseCommand
            
            # Provide access instructions
            Write-Info "`nTo access your project:"
            Write-Host "  WSL: cd '$appDir'" -ForegroundColor Yellow
            Write-Host "  Windows: \\wsl.localhost\Ubuntu-24.04$appDir" -ForegroundColor Yellow
            Write-Host "  VS Code: code '$appDir' (from WSL terminal)" -ForegroundColor Yellow
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
                $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "n"
                if ($overwriteChoice -notmatch '^[Yy]') {
                    Write-Info "Skipping initialization. Using existing project directory."
                    $shouldInitialize = $false
                } else {
                    Write-Info "Cleaning existing project and reinitializing..."
                    Get-ChildItem -Path $appDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                # Directory exists but not a StrangeLoop project
                $existingFiles = Get-ChildItem -Path $appDir -Force
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
            
            # Update settings.yaml with project name
            $settingsPath = ".\strangeloop\settings.yaml"
            if (Test-Path $settingsPath) {
                Write-Info "Updating settings.yaml with project name..."
                $content = Get-Content $settingsPath -Raw
                $content = $content -replace "^name:.*", "name: $appName"
                Set-Content $settingsPath $content
                
                # Run strangeloop recurse to apply configuration changes
                Write-Info "Applying configuration changes..."
                strangeloop recurse
                
                Write-Success "Configuration applied successfully"
            }
            
            Write-Info "`nProject created at: $appDir"
            Write-Host "  Open in VS Code: code ." -ForegroundColor Yellow
        } else {
            Write-Error "Loop initialization failed"
            exit 1
        }
    }
    
} catch {
    Write-Error "Loop initialization failed: $($_.Exception.Message)"
    exit 1
}

# Final success message
Write-Step "Setup Completed Successfully!" "Green"
Write-Success "StrangeLoop CLI environment is ready!"
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

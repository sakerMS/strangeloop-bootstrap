# StrangeLoop CLI Setup Script - Simplified & Optimized
# Automated setup following readme.md requirements
# 
# Author: [Sakr Omera/Bing Ads Teams Egypt]
# Version: 1.0
# Created: August 2025
# 
# This script automates the setup of StrangeLoop development environment
# including WSL, Python, Poetry, Git, and Docker configuration.
#
# Prerequisites: Windows 10/11 with PowerShell 5.1+
# Execution Policy: RemoteSigned or Unrestricted required
#
# Usage: .\setup-strangeloop-optimized.ps1 [-SkipPrerequisites] [-SkipDevelopmentTools] [-UserName "Name"] [-UserEmail "email@domain.com"]

param(
    [switch]$SkipPrerequisites,
    [switch]$SkipDevelopmentTools,
    [string]$UserName,
    [string]$UserEmail
)

# Error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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

function Request-TerminalRestart {
    param(
        [string]$Tool,
        [string]$Reason = "PATH changes require a terminal restart"
    )
    
    Write-Host ""
    Write-Host "🔄 Terminal Restart Required for $Tool" -ForegroundColor Yellow
    Write-Host "$Reason" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Close this PowerShell window" -ForegroundColor White
    Write-Host "2. Open a new PowerShell window" -ForegroundColor White
    Write-Host "3. Run this script again to continue the setup" -ForegroundColor White
    Write-Host ""
    Write-Host "The script will detect that $Tool is now available and continue from where it left off." -ForegroundColor Cyan
    Write-Host ""
    
    $restartChoice = Read-Host "Press Enter to exit and restart terminal manually, or type 'continue' to try proceeding anyway"
    if ($restartChoice -notmatch "continue") {
        exit 0
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
            
            # Debug output for Git commands
            if ($Command -match "git config") {
                Write-Host "  Debug: Executing WSL command: $wslCommand" -ForegroundColor DarkGray
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
Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║                StrangeLoop CLI Setup - Simplified             ║
║                     Automated Installation                    ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $Colors.Highlight

if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Error "Execution policy is Restricted. Please change it to RemoteSigned or Unrestricted."
    exit
}

# Step 1: Prerequisites Check
if (-not $SkipPrerequisites) {
    Write-Step "Checking Prerequisites"
    
    $prerequisites = @{
        "Azure CLI" = "az"
        "Git" = "git"
        "Git LFS" = "git-lfs"
        "Docker" = "docker"
    }
    
    $missingPrereqs = @()
    
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Checking $($prereq.Key)..." -ForegroundColor Yellow
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
                    "docker" { 
                        $dockerOutput = docker --version 2>$null
                        if ($dockerOutput -match "Docker version ([0-9]+\.[0-9]+\.[0-9]+)") {
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
        } else {
            Write-Error "$($prereq.Key) is missing"
            $missingPrereqs += $prereq.Key
        }
    }
    
    if ($missingPrereqs.Count -gt 0) {
        Write-Warning "Missing prerequisites detected: $($missingPrereqs -join ', ')"
        Write-Info "Attempting to install missing prerequisites automatically..."
        
        # Install Azure CLI if missing
        if ($missingPrereqs -contains "Azure CLI") {
            Write-Info "Installing Azure CLI...."
            try {
                Invoke-CommandWithDuration -Description "Installing Azure CLI" -ScriptBlock {
                    # Download and install Azure CLI
                    Write-Info "Downloading Azure CLI installer..."
                    $azCliUrl = "https://aka.ms/installazurecliwindows"
                    $azCliInstaller = "$env:TEMP\AzureCLI.msi"
                    
                    Invoke-WebRequest -Uri $azCliUrl -OutFile $azCliInstaller -UseBasicParsing
                    Write-Success "Azure CLI installer downloaded"
                    
                    # Install Azure CLI
                    Write-Info "Installing Azure CLI (this may take a few minutes)..."
                    $process = Start-Process msiexec.exe -ArgumentList "/i", $azCliInstaller, "/quiet", "/norestart" -Wait -NoNewWindow -PassThru
                    
                    if ($process.ExitCode -ne 0) {
                        if ($process.ExitCode -eq 1603) {
                            throw "Azure CLI installation blocked (Exit Code 1603). This typically indicates Group Policy restrictions or insufficient privileges. Try running as Administrator or contact your system administrator."
                        } elseif ($process.ExitCode -eq 1260) {
                            throw "Azure CLI installation blocked by Group Policy (Exit Code 1260). Contact your system administrator to temporarily allow MSI installations."
                        } else {
                            throw "Azure CLI MSI installation failed with exit code: $($process.ExitCode)"
                        }
                    }
                    
                    Write-Success "Azure CLI MSI installation completed successfully"
                    
                    # Cleanup
                    Remove-Item $azCliInstaller -Force -ErrorAction SilentlyContinue
                    
                    # Refresh PATH to pick up Azure CLI
                    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                    $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
                    $env:Path = $machinePath + ";" + $userPath
                    
                    # Wait a moment for the system to settle
                    Start-Sleep -Seconds 3
                    
                    # Verify installation with multiple attempts
                    $installSuccess = $false
                    for ($i = 1; $i -le 3; $i++) {
                        Write-Info "Verifying Azure CLI installation (attempt $i/3)..."
                        if (Test-Command "az") {
                            $installSuccess = $true
                            break
                        }
                        Start-Sleep -Seconds 2
                        # Refresh PATH again
                        $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                        $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
                        $env:Path = $machinePath + ";" + $userPath
                    }
                    
                    if ($installSuccess) {
                        Write-Success "Azure CLI installed successfully"
                        $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
                        if ($azVersion) {
                            Write-Info "Installed version: $azVersion"
                        }
                    } else {
                        Write-Warning "Azure CLI was installed but is not immediately available in the current session."
                        Write-Host ""
                        Write-Host "🔄 Terminal Restart Required" -ForegroundColor Yellow
                        Write-Host "Azure CLI installation was successful, but the PATH changes require a terminal restart." -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "Please:" -ForegroundColor Yellow
                        Write-Host "1. Close this PowerShell window" -ForegroundColor White
                        Write-Host "2. Open a new PowerShell window" -ForegroundColor White
                        Write-Host "3. Run this script again to continue the setup" -ForegroundColor White
                        Write-Host ""
                        Write-Host "The script will detect that Azure CLI is now available and continue from where it left off." -ForegroundColor Cyan
                        exit 0
                    }
                }
            } catch {
                # If the error mentions Group Policy or privileges, try elevated installation
                if ($_.Exception.Message -match "1603|Group Policy|privileges") {
                    Write-Warning "Azure CLI installation failed due to Group Policy restrictions or insufficient privileges"
                    Write-Info "Attempting elevated installation in Administrator PowerShell window..."
                    
                    try {
                        # Create a script to run in elevated session
                        $elevatedScript = @"
Write-Host "Installing Azure CLI (Elevated Session)..." -ForegroundColor Green
Write-Host "Please wait while Azure CLI is being installed..." -ForegroundColor Yellow

try {
    # Download Azure CLI installer
    `$azCliUrl = "https://aka.ms/installazurecliwindows"
    `$azCliInstaller = "`$env:TEMP\AzureCLI.msi"
    
    Write-Host "Downloading Azure CLI installer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri `$azCliUrl -OutFile `$azCliInstaller -UseBasicParsing
    
    # Install Azure CLI with elevated privileges
    Write-Host "Installing Azure CLI (this may take several minutes)..." -ForegroundColor Cyan
    `$process = Start-Process msiexec.exe -ArgumentList "/i", `$azCliInstaller, "/quiet", "/norestart" -Wait -PassThru -NoNewWindow
    
    # Clean up installer
    Remove-Item `$azCliInstaller -Force -ErrorAction SilentlyContinue
    
    if (`$process.ExitCode -eq 0) {
        Write-Host "Azure CLI installed successfully!" -ForegroundColor Green
        "SUCCESS" | Out-File -FilePath "`$env:TEMP\az-install-result.txt" -Encoding UTF8
    } else {
        Write-Host "Azure CLI installation failed with exit code: `$(`$process.ExitCode)" -ForegroundColor Red
        "FAILED:`$(`$process.ExitCode)" | Out-File -FilePath "`$env:TEMP\az-install-result.txt" -Encoding UTF8
    }
} catch {
    Write-Host "Azure CLI installation failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    "FAILED:`$(`$_.Exception.Message)" | Out-File -FilePath "`$env:TEMP\az-install-result.txt" -Encoding UTF8
}

Write-Host "Installation process completed. You can close this window." -ForegroundColor Yellow
Read-Host "Press Enter to close this window"
"@
                        
                        # Save the script to a temporary file
                        $tempScript = "$env:TEMP\install-az-elevated.ps1"
                        $elevatedScript | Out-File -FilePath $tempScript -Encoding UTF8
                        
                        # Remove any existing result file
                        Remove-Item "$env:TEMP\az-install-result.txt" -Force -ErrorAction SilentlyContinue
                        
                        # Launch elevated PowerShell window
                        Write-Host "Please complete the UAC prompt to install Azure CLI with administrator privileges..." -ForegroundColor Yellow
                        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Verb RunAs -Wait
                        
                        # Check result file
                        $resultFile = "$env:TEMP\az-install-result.txt"
                        if (Test-Path $resultFile) {
                            $result = Get-Content $resultFile -ErrorAction SilentlyContinue
                            Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
                            
                            if ($result -eq "SUCCESS") {
                                Write-Success "Azure CLI installed successfully in elevated session"
                                
                                # Refresh PATH and verify installation
                                $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                                $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
                                $env:Path = $machinePath + ";" + $userPath
                                
                                # Wait and verify installation
                                Start-Sleep -Seconds 3
                                for ($i = 1; $i -le 5; $i++) {
                                    Write-Info "Verifying Azure CLI installation (attempt $i/5)..."
                                    if (Test-Command "az") {
                                        Write-Success "Azure CLI is now available"
                                        $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
                                        if ($azVersion) {
                                            Write-Info "Installed version: $azVersion"
                                        }
                                        break
                                    }
                                    Start-Sleep -Seconds 2
                                    # Refresh PATH again
                                    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
                                    $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
                                    $env:Path = $machinePath + ";" + $userPath
                                }
                                
                                if (-not (Test-Command "az")) {
                                    Write-Warning "Azure CLI was installed but is not immediately available in the current session."
                                    Write-Host ""
                                    Write-Host "🔄 Terminal Restart Required" -ForegroundColor Yellow
                                    Write-Host "Azure CLI installation was successful, but the PATH changes require a terminal restart." -ForegroundColor Cyan
                                    Write-Host ""
                                    Write-Host "Please:" -ForegroundColor Yellow
                                    Write-Host "1. Close this PowerShell window" -ForegroundColor White
                                    Write-Host "2. Open a new PowerShell window" -ForegroundColor White
                                    Write-Host "3. Run this script again to continue the setup" -ForegroundColor White
                                    Write-Host ""
                                    Write-Host "The script will detect that Azure CLI is now available and continue from where it left off." -ForegroundColor Cyan
                                    exit 0
                                }
                            } else {
                                throw "Elevated Azure CLI installation failed: $result"
                            }
                        } else {
                            throw "Could not determine Azure CLI installation status"
                        }
                        
                        # Clean up temp script
                        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                        
                    } catch {
                        Write-Error "Elevated Azure CLI installation failed: $($_.Exception.Message)"
                        Write-Host ""
                        Write-Host "📋 Manual Installation Required:" -ForegroundColor Red
                        Write-Host "1. Download Azure CLI from: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
                        Write-Host "2. Right-click the installer and select 'Run as Administrator'" -ForegroundColor Yellow
                        Write-Host "3. Complete the installation" -ForegroundColor Yellow
                        Write-Host "4. Restart your terminal and run this script again" -ForegroundColor Yellow
                        exit 1
                    }
                } else {
                    Write-Error "Azure CLI installation failed: $($_.Exception.Message)"
                    Write-Info "Please install Azure CLI manually:"
                    Write-Info "1. Download from: https://aka.ms/installazurecliwindows"
                    Write-Info "2. Run the installer"
                    Write-Info "3. Restart your terminal and run this script again"
                    exit 1
                }
            }
        }
        
        # Install Docker Desktop if missing
        if ($missingPrereqs -contains "Docker") {
            Write-Info "Installing Docker Desktop..."
            try {
                # First try standard installation
                Write-Info "Downloading Docker Desktop installer..."
                $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
                $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
                
                Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerInstaller -UseBasicParsing
                Write-Success "Docker Desktop installer downloaded"
                
                Write-Info "Installing Docker Desktop (this may take several minutes)..."
                $process = Start-Process $dockerInstaller -ArgumentList "install", "--quiet", "--accept-license" -Wait -PassThru -NoNewWindow
                
                # Cleanup installer
                Remove-Item $dockerInstaller -Force -ErrorAction SilentlyContinue
                
                if ($process.ExitCode -eq 0) {
                    Write-Success "Docker Desktop installed successfully"
                    
                    # Docker Desktop requires startup time
                    Write-Info "Docker Desktop installation completed. Starting Docker Desktop service..."
                    
                    # Try to start Docker Desktop
                    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                    if (Test-Path $dockerDesktopPath) {
                        Start-Process $dockerDesktopPath -NoNewWindow
                        Write-Info "Docker Desktop is starting up. This may take a few minutes..."
                        
                        # Wait for Docker to become available (up to 2 minutes)
                        $maxWaitTime = 120
                        $waitTime = 0
                        $dockerReady = $false
                        
                        while ($waitTime -lt $maxWaitTime -and -not $dockerReady) {
                            Start-Sleep -Seconds 5
                            $waitTime += 5
                            Write-Info "Waiting for Docker to start... ($waitTime/$maxWaitTime seconds)"
                            
                            try {
                                $dockerVersion = docker --version 2>$null
                                if ($dockerVersion) {
                                    $dockerReady = $true
                                    Write-Success "Docker is now available: $dockerVersion"
                                    break
                                }
                            } catch { }
                        }
                        
                        if (-not $dockerReady) {
                            Write-Warning "Docker Desktop was installed but may not be fully ready yet."
                            Write-Host ""
                            Write-Host "🔄 Terminal Restart Recommended" -ForegroundColor Yellow
                            Write-Host "Docker Desktop installation was successful, but may require a terminal restart for full functionality." -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Recommended steps:" -ForegroundColor Yellow
                            Write-Host "1. Close this PowerShell window" -ForegroundColor White
                            Write-Host "2. Open a new PowerShell window" -ForegroundColor White
                            Write-Host "3. Wait for Docker Desktop to complete startup (check system tray)" -ForegroundColor White
                            Write-Host "4. Run this script again to continue the setup" -ForegroundColor White
                            Write-Host ""
                            Write-Host "Alternatively, you can wait a few more minutes and the script will continue automatically." -ForegroundColor Cyan
                            
                            # Give user a choice
                            $continueChoice = Read-Host "`nContinue waiting (c) or restart terminal now (r)? [c/r]"
                            if ($continueChoice -match '^[Rr]') {
                                Write-Info "Please restart your terminal and run this script again."
                                exit 0
                            }
                        }
                    }
                } elseif ($process.ExitCode -eq 1603) {
                    throw "Docker Desktop installation blocked (Exit Code 1603). This typically indicates Group Policy restrictions or insufficient privileges."
                } else {
                    throw "Docker Desktop installation failed with exit code: $($process.ExitCode)"
                }
                
            } catch {
                # If installation fails, try elevated installation
                if ($_.Exception.Message -match "1603|Group Policy|privileges") {
                    Write-Warning "Docker Desktop installation failed due to Group Policy restrictions or insufficient privileges"
                    Write-Info "Attempting elevated installation in Administrator PowerShell window..."
                    
                    try {
                        # Create a script to run in elevated session
                        $elevatedScript = @"
Write-Host "Installing Docker Desktop (Elevated Session)..." -ForegroundColor Green
Write-Host "Please wait while Docker Desktop is being installed..." -ForegroundColor Yellow

try {
    # Download Docker Desktop installer
    `$dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    `$dockerInstaller = "`$env:TEMP\DockerDesktopInstaller.exe"
    
    Write-Host "Downloading Docker Desktop installer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri `$dockerUrl -OutFile `$dockerInstaller -UseBasicParsing
    
    # Install Docker Desktop with elevated privileges
    Write-Host "Installing Docker Desktop (this may take several minutes)..." -ForegroundColor Cyan
    `$process = Start-Process `$dockerInstaller -ArgumentList "install", "--quiet", "--accept-license" -Wait -PassThru -NoNewWindow
    
    # Clean up installer
    Remove-Item `$dockerInstaller -Force -ErrorAction SilentlyContinue
    
    if (`$process.ExitCode -eq 0) {
        Write-Host "Docker Desktop installed successfully!" -ForegroundColor Green
        "SUCCESS" | Out-File -FilePath "`$env:TEMP\docker-install-result.txt" -Encoding UTF8
    } else {
        Write-Host "Docker Desktop installation failed with exit code: `$(`$process.ExitCode)" -ForegroundColor Red
        "FAILED:`$(`$process.ExitCode)" | Out-File -FilePath "`$env:TEMP\docker-install-result.txt" -Encoding UTF8
    }
} catch {
    Write-Host "Docker Desktop installation failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    "FAILED:`$(`$_.Exception.Message)" | Out-File -FilePath "`$env:TEMP\docker-install-result.txt" -Encoding UTF8
}

Write-Host "Installation process completed. You can close this window." -ForegroundColor Yellow
Read-Host "Press Enter to close this window"
"@
                        
                        # Save the script to a temporary file
                        $tempScript = "$env:TEMP\install-docker-elevated.ps1"
                        $elevatedScript | Out-File -FilePath $tempScript -Encoding UTF8
                        
                        # Remove any existing result file
                        Remove-Item "$env:TEMP\docker-install-result.txt" -Force -ErrorAction SilentlyContinue
                        
                        # Launch elevated PowerShell window
                        Write-Host "Please complete the UAC prompt to install Docker Desktop with administrator privileges..." -ForegroundColor Yellow
                        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" -Verb RunAs -Wait
                        
                        # Check result file
                        $resultFile = "$env:TEMP\docker-install-result.txt"
                        if (Test-Path $resultFile) {
                            $result = Get-Content $resultFile -ErrorAction SilentlyContinue
                            Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
                            
                            if ($result -eq "SUCCESS") {
                                Write-Success "Docker Desktop installed successfully in elevated session"
                                Write-Host ""
                                Write-Host "🔄 Terminal Restart Required for Docker" -ForegroundColor Yellow
                                Write-Host "Docker Desktop installation was successful, but requires a terminal restart." -ForegroundColor Cyan
                                Write-Host ""
                                Write-Host "Please:" -ForegroundColor Yellow
                                Write-Host "1. Close this PowerShell window" -ForegroundColor White
                                Write-Host "2. Wait for Docker Desktop to complete startup (check system tray icon)" -ForegroundColor White
                                Write-Host "3. Open a new PowerShell window" -ForegroundColor White
                                Write-Host "4. Run this script again to continue the setup" -ForegroundColor White
                                Write-Host ""
                                Write-Host "The script will detect that Docker is now available and continue from where it left off." -ForegroundColor Cyan
                                exit 0
                            } else {
                                throw "Elevated Docker Desktop installation failed: $result"
                            }
                        } else {
                            throw "Could not determine Docker Desktop installation status"
                        }
                        
                        # Clean up temp script
                        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                        
                    } catch {
                        Write-Error "Elevated Docker Desktop installation failed: $($_.Exception.Message)"
                        Write-Host ""
                        Write-Host "📋 Manual Installation Required:" -ForegroundColor Red
                        Write-Host "1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
                        Write-Host "2. Right-click the installer and select 'Run as Administrator'" -ForegroundColor Yellow
                        Write-Host "3. Complete the installation and restart your computer" -ForegroundColor Yellow
                        Write-Host "4. Run this script again after Docker Desktop is ready" -ForegroundColor Yellow
                        exit 1
                    }
                } else {
                    Write-Error "Docker Desktop installation failed: $($_.Exception.Message)"
                    Write-Info "Please install Docker Desktop manually:"
                    Write-Info "1. Download from: https://www.docker.com/products/docker-desktop/"
                    Write-Info "2. Run the installer"
                    Write-Info "3. Run this script again after installation"
                    exit 1
                }
            }
        }
        
        # Check for remaining missing prerequisites after installation attempts
        $stillMissing = @()
        foreach ($prereq in $missingPrereqs) {
            $command = switch ($prereq) {
                "Azure CLI" { "az" }
                "Git" { "git" }
                "Git LFS" { "git-lfs" }
                "Docker" { "docker" }
            }
            if (-not (Test-Command $command)) {
                $stillMissing += $prereq
            }
        }
        
        if ($stillMissing.Count -gt 0) {
            Write-Error "Still missing prerequisites after installation attempts: $($stillMissing -join ', ')"
            Write-Info "Please install the remaining prerequisites manually and run the script again."
            if ($stillMissing -contains "Git") {
                Write-Info "Git: https://git-scm.com/download/windows"
            }
            if ($stillMissing -contains "Git LFS") {
                Write-Info "Git LFS: https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage"
            }
            exit 1
        }
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

# Step 2.5: Get Available Loops and Determine Environment Requirements
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
    
    if ($needsLinux) {
        Write-Success "✓ WSL will be configured for Linux-based development"
    } else {
        Write-Info "✓ Windows-only development environment selected"
        if ($selectedTemplate -and $linuxRequiredLoops -contains $selectedTemplate.Name) {
            Write-Warning "⚠ Note: $($selectedTemplate.Name) may have limited functionality without WSL"
        }
    }
    
    # Platform selection confirmation
    Write-Info "`n=== Platform Configuration Summary ==="
    if ($needsLinux) {
        Write-Host "  Target Platform: Linux/WSL (Ubuntu-24.04)" -ForegroundColor Green
        Write-Host "  Development Tools: Python, Poetry, pipx, Git (in WSL)" -ForegroundColor Gray
        Write-Host "  Docker: Linux containers" -ForegroundColor Gray
        if ($selectedTemplate) {
            Write-Host "  Selected Template: $($selectedTemplate.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Target Platform: Windows Native" -ForegroundColor Yellow
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
}

# Step 3: Development Environment Setup
if (-not $SkipDevelopmentTools) {
    Write-Step "Development Environment Setup"
    
    # Define Ubuntu distribution variable first
    $ubuntuDistro = "Ubuntu-24.04"
    
    # WSL Setup (only if Linux support is needed)
    if ($needsLinux) {
        Write-Info "Setting up WSL with $ubuntuDistro..."
        
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
        
        # Check for Ubuntu 24.04.1 LTS distribution
        $wslDistros = wsl -l -v 2>$null
        
        # Look for Ubuntu 24.04 distribution
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
                        $foundUbuntu = $true
                        Write-Host "  Found: $cleanLine" -ForegroundColor Green
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
        
        # Install Python environment with version checks
        Write-Info "Setting up Python development environment..."
        
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
        
        # Git configuration
        Write-Info "Configuring Git in WSL..."
        
        # Check existing Git configuration
        $existingName = Get-WSLCommandOutput "git config --global user.name 2>/dev/null" $ubuntuDistro
        $existingEmail = Get-WSLCommandOutput "git config --global user.email 2>/dev/null" $ubuntuDistro
        
        if ($existingName -and $existingEmail) {
            Write-Success "Git is already configured:"
            Write-Host "  Name: $existingName" -ForegroundColor Gray
            Write-Host "  Email: $existingEmail" -ForegroundColor Gray
        } else {
            Write-Info "Setting up Git user configuration..."
            if (-not $UserName) {
                $UserName = Get-UserInput "Enter your full name for Git commits" -Required $true
            }
            if (-not $UserEmail) {
                $UserEmail = Get-UserInput "Enter your email address for Git commits" -Required $true
            }
            
            # Use Git configuration without quotes to avoid escaping issues
            Write-Info "Configuring Git user name: $UserName"
            $gitNameResult = Invoke-WSLCommand "git config --global user.name `"$UserName`"" "Setting Git user name" $ubuntuDistro
            Write-Info "Configuring Git user email: $UserEmail"
            $gitEmailResult = Invoke-WSLCommand "git config --global user.email `"$UserEmail`"" "Setting Git user email" $ubuntuDistro
            
            # Verify the configuration was set
            $verifyName = Get-WSLCommandOutput "git config --global user.name" $ubuntuDistro
            $verifyEmail = Get-WSLCommandOutput "git config --global user.email" $ubuntuDistro
            
            if ($verifyName -eq $UserName -and $verifyEmail -eq $UserEmail) {
                Write-Success "Git user configuration verified successfully"
                Write-Host "  Name: $verifyName" -ForegroundColor Gray
                Write-Host "  Email: $verifyEmail" -ForegroundColor Gray
            } else {
                Write-Warning "Git configuration may not have been set correctly:"
                Write-Host "  Expected Name: $UserName, Got: $verifyName" -ForegroundColor Yellow
                Write-Host "  Expected Email: $UserEmail, Got: $verifyEmail" -ForegroundColor Yellow
            }
        }
        
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
            Invoke-WSLCommand "git lfs install" "Configuring Git LFS" $ubuntuDistro
        }
        
        # Clear sudo password from memory for security
        if ($sudoPassword) {
            $sudoPassword.Dispose()
            Write-Info "Cleared sudo credentials from memory"
        }
    } else {
        Write-Info "Skipping WSL setup - configuring Windows-only environment"
        
        # Windows Python setup
        Write-Info "Checking Windows Python environment..."
        Invoke-CommandWithDuration -Description "Checking Windows Python environment" -ScriptBlock {
            if (Test-Command "python") {
                $pythonVersion = python --version 2>$null
                if ($pythonVersion) {
                    Write-Success "Python is installed: $pythonVersion"
                } else {
                    Write-Success "Python is installed"
                }
            } else {
                Write-Warning "Python not found on Windows PATH"
                Write-Info "Please install Python from: https://www.python.org/downloads/"
                Write-Info "Or install via Microsoft Store: ms-windows-store://search?query=python"
            }
        }
        
        # Check pipx on Windows
        Invoke-CommandWithDuration -Description "Checking/Installing pipx on Windows" -ScriptBlock {
            if (Test-Command "pipx") {
                $pipxVersion = pipx --version 2>$null
                Write-Success "pipx is installed: $pipxVersion"
            } else {
                Write-Info "Installing pipx on Windows..."
                try {
                    python -m pip install --user pipx
                    python -m pipx ensurepath
                    Write-Success "pipx installed successfully"
                } catch {
                    Write-Warning "pipx installation failed. Please install manually: pip install --user pipx"
                }
            }
        }
        
        # Check Poetry on Windows
        Invoke-CommandWithDuration -Description "Checking/Installing Poetry on Windows" -ScriptBlock {
            if (Test-Command "poetry") {
                $poetryVersion = poetry --version 2>$null
                Write-Success "Poetry is installed: $poetryVersion"
            } else {
                Write-Info "Installing Poetry on Windows..."
                try {
                    pipx install poetry
                    poetry config virtualenvs.in-project true
                    Write-Success "Poetry installed and configured"
                } catch {
                    Write-Warning "Poetry installation failed. Please install manually: pipx install poetry"
                }
            }
        }
    }
    
    # Docker configuration (installation handled in prerequisites)
    Write-Info "Configuring Docker..."
    Invoke-CommandWithDuration -Description "Configuring Docker" -ScriptBlock {
        if (Test-Command "docker") {
            try {
                $dockerVersion = docker --version 2>$null
                if ($dockerVersion) {
                    Write-Success "Docker is available ($dockerVersion)"
                } else {
                    Write-Success "Docker is available"
                }
                
                # Configure Docker engine based on development environment
                Write-Info "Configuring Docker engine for your environment..."
                
                # Enhanced Docker engine configuration with multiple methods
                $engineConfigured = $false
                
                # Method 1: Try DockerCli.exe for engine switching
                $dockerCliPath = "C:\Program Files\Docker\Docker\DockerCli.exe"
                if (Test-Path $dockerCliPath) {
                    if ($needsLinux) {
                        Write-Info "Configuring Docker for Linux containers..."
                        try {
                            & $dockerCliPath -SwitchLinuxEngine 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Docker configured for Linux containers"
                                $engineConfigured = $true
                            } else {
                                Write-Info "Standard engine switch failed, trying alternative method..."
                            }
                        } catch {
                            Write-Info "DockerCli engine switch failed, trying alternative method..."
                        }
                    } else {
                        Write-Info "Configuring Docker for Windows containers..."
                        try {
                            & $dockerCliPath -SwitchWindowsEngine 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Docker configured for Windows containers"
                                $engineConfigured = $true
                            } else {
                                Write-Info "Standard engine switch failed, trying alternative method..."
                            }
                        } catch {
                            Write-Info "DockerCli engine switch failed, trying alternative method..."
                        }
                    }
                }
                
                # Method 2: Try Docker Desktop CLI if available
                if (-not $engineConfigured -and (Test-Command "dockerdesktop")) {
                    try {
                        if ($needsLinux) {
                            & dockerdesktop -l 2>$null  # Switch to Linux
                        } else {
                            & dockerdesktop -w 2>$null  # Switch to Windows
                        }
                        if ($LASTEXITCODE -eq 0) {
                            $containerType = if ($needsLinux) { "Linux" } else { "Windows" }
                            Write-Success "Docker configured for $containerType containers using Docker Desktop CLI"
                            $engineConfigured = $true
                        }
                    } catch {
                        Write-Info "Docker Desktop CLI engine switch failed, using manual guidance..."
                    }
                }
                
                # Method 3: Provide manual guidance if automatic switching failed
                if (-not $engineConfigured) {
                    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
                    if (Test-Path $dockerDesktopPath) {
                        if ($needsLinux) {
                            Write-Info "Configuring Docker for Linux containers..."
                            Write-Host "  Please ensure Linux containers are enabled in Docker Desktop settings" -ForegroundColor Yellow
                            Write-Host "  You can switch by right-clicking Docker Desktop system tray icon → Switch to Linux containers" -ForegroundColor Yellow
                            if ($ubuntuDistro) {
                                Write-Host "  Also enable WSL 2 integration for $ubuntuDistro in Docker Desktop → Settings → Resources → WSL Integration" -ForegroundColor Yellow
                            }
                        } else {
                            Write-Info "Configuring Docker for Windows containers..."
                            Write-Host "  Please ensure Windows containers are enabled in Docker Desktop settings" -ForegroundColor Yellow
                            Write-Host "  You can switch by right-clicking Docker Desktop system tray icon → Switch to Windows containers" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Warning "Docker Desktop not found in default location. Please configure engine manually."
                        Write-Info "Expected location: $dockerDesktopPath"
                    }
                }
                
                # Additional configuration for WSL integration
                if ($needsLinux -and $ubuntuDistro) {
                    Write-Info "Ensuring WSL 2 integration is enabled for $ubuntuDistro..."
                    Write-Host "  If Docker commands don't work in WSL, please:" -ForegroundColor Yellow
                    Write-Host "  1. Open Docker Desktop → Settings → Resources → WSL Integration" -ForegroundColor Yellow
                    Write-Host "  2. Enable integration for $ubuntuDistro" -ForegroundColor Yellow
                    Write-Host "  3. Click 'Apply & Restart'" -ForegroundColor Yellow
                }
            } catch {
                Write-Success "Docker is available"
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
        } else {
            Write-Warning "Docker is not available. Please ensure Docker Desktop is running."
            Write-Info "If Docker was just installed, you may need to restart your computer."
        }
    }
    
    # Clear sudo password from memory for security (only if WSL was used)
    if ($needsLinux -and $sudoPassword) {
        $sudoPassword.Dispose()
        Write-Info "Cleared sudo credentials from memory"
    }
    
    # Development environment summary
    Write-Step "Development Environment Summary" "Green"
    if ($needsLinux) {
        Write-Success "✓ WSL Ubuntu-24.04 configured and ready"
        Write-Success "✓ Python development environment set up in WSL"
        Write-Success "✓ Package management tools (pipx, Poetry) installed in WSL"
        Write-Success "✓ Git configuration completed in WSL"
    } else {
        Write-Success "✓ Windows development environment configured"
        Write-Success "✓ Python development tools verified/installed"
        Write-Success "✓ Package management tools (pipx, Poetry) configured"
    }
    Write-Success "✓ Docker network prepared for development"
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

# Step 4: Loop Initialization
Write-Step "Loop Selection & Initialization"

# Step 4: Loop Selection & Initialization
Write-Step "Loop Selection & Initialization"

try {
    # Check if user already selected a template in Step 2.5
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
        $wslUser = Get-WSLCommandOutput "whoami" $ubuntuDistro
        if (-not $wslUser) { $wslUser = "user" }  # fallback if whoami fails
        $defaultAppDir = "/home/$wslUser/projects/$appName"
        Write-Info "Using WSL environment for project initialization"
        $appDir = Get-UserInput "Application directory (WSL path)" $defaultAppDir
        
        # Create directory in WSL
        Write-Info "Creating application directory in WSL: $appDir"
        
        # Check if directory already exists and handle accordingly
        $dirExists = Get-WSLCommandOutput "cd '$appDir' 2>/dev/null && echo 'EXISTS' || echo 'NOT_EXISTS'" $ubuntuDistro
        if ($dirExists -eq "EXISTS") {
            Write-Warning "Directory '$appDir' already exists"
            
            # Check if it's already a StrangeLoop project
            $isStrangeLoopProject = Get-WSLCommandOutput "cd '$appDir' && if [ -d './strangeloop' ]; then echo 'YES'; else echo 'NO'; fi" $ubuntuDistro
            if ($isStrangeLoopProject -eq "YES") {
                Write-Warning "Directory appears to be an existing StrangeLoop project"
                $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "n"
                if ($overwriteChoice -notmatch '^[Yy]') {
                    Write-Info "Skipping initialization. Using existing project directory."
                    $strangeloopDir = "SUCCESS"  # Skip initialization but continue with settings update
                } else {
                    Write-Info "Cleaning existing project and reinitializing..."
                    $cleanResult = Invoke-WSLCommand "cd '$appDir' && rm -rf ./* ./.*[^.] 2>/dev/null || true" "Cleaning existing project" $ubuntuDistro
                    $createDirResult = $true  # Directory already exists, just cleaned
                }
            } else {
                # Directory exists but not a StrangeLoop project
                $hasFiles = Get-WSLCommandOutput "cd '$appDir' && find . -maxdepth 1 -type f | wc -l" $ubuntuDistro
                if ($hasFiles -and [int]$hasFiles -gt 0) {
                    Write-Warning "Directory contains $hasFiles files"
                    $overwriteChoice = Get-UserInput "Directory is not empty. Continue anyway? (y/n)" "n"
                    if ($overwriteChoice -notmatch '^[Yy]') {
                        Write-Error "Cannot initialize in non-empty directory. Please choose a different path or clean the directory manually."
                        exit 1
                    }
                }
                $createDirResult = $true  # Directory exists and user confirmed
            }
        } else {
            $createDirResult = Invoke-WSLCommand "mkdir -p '$appDir'" "Creating project directory" $ubuntuDistro
        }
        
        if ($createDirResult) {
            Write-Success "Directory ready for initialization"
        } else {
            Write-Error "Failed to create directory in WSL"
            exit 1
        }
        
        # Initialize loop in WSL (only if not already a StrangeLoop project)
        if (-not (Get-Variable -Name "strangeloopDir" -ErrorAction SilentlyContinue) -or $strangeloopDir -ne "SUCCESS") {
            Write-Info "Initializing $($selectedLoop.Name) loop in WSL environment..."
            $initResult = Invoke-WSLCommand "cd '$appDir' && strangeloop init --loop $($selectedLoop.Name)" "Initializing StrangeLoop project" $ubuntuDistro
            
            # Check if initialization was actually successful by verifying created files
            $strangeloopDir = Get-WSLCommandOutput "cd '$appDir' && if [ -d './strangeloop' ]; then echo 'SUCCESS'; else echo 'FAILED'; fi" $ubuntuDistro
        } else {
            Write-Info "Using existing StrangeLoop project directory"
        }
        
        if ($strangeloopDir -eq "SUCCESS") {
            Write-Success "Loop initialized successfully in WSL!"
            
            # Show created files
            Write-Info "Files created in WSL:"
            $filesList = Get-WSLCommandOutput "cd '$appDir' && ls -la" $ubuntuDistro
            if ($filesList) {
                $filesList -split "`n" | Where-Object { $_ -and $_ -notmatch "^total" } | ForEach-Object {
                    $line = $_.Trim()
                    if ($line -and $line -notmatch "^\.$" -and $line -notmatch "^\.\.$") {
                        $fileName = ($line -split '\s+')[-1]
                        Write-Host "  $fileName" -ForegroundColor Gray
                    }
                }
            }
            
            # Update settings.yaml with project name in WSL
            Write-Info "Updating settings.yaml with project name in WSL..."
            $updateSettingsResult = Invoke-WSLCommand "cd '$appDir' && if [ -f './strangeloop/settings.yaml' ]; then sed -i 's/^name:.*/name: $appName/' './strangeloop/settings.yaml' && echo 'Settings updated'; else echo 'Settings file not found'; fi" "Updating project settings" $ubuntuDistro
            if ($updateSettingsResult) {
                $settingsCheck = Get-WSLCommandOutput "cd '$appDir' && if [ -f './strangeloop/settings.yaml' ]; then echo 'SUCCESS'; else echo 'NOT_FOUND'; fi" $ubuntuDistro
                if ($settingsCheck -eq "SUCCESS") {
                    Write-Success "Settings.yaml updated with project name: $appName"
                    
                    # Run strangeloop recurse to apply settings changes
                    Write-Info "Running strangeloop recurse to apply configuration changes..."
                    $recurseResult = Invoke-WSLCommand "cd '$appDir' && strangeloop recurse" "Applying configuration changes" $ubuntuDistro
                    if ($recurseResult) {
                        Write-Success "Configuration applied successfully with strangeloop recurse"
                        
                        # Open project in VS Code (WSL context)
                        Write-Info "Opening project in VS Code..."
                        $codeResult = Invoke-WSLCommand "cd '$appDir' && code ." "Opening VS Code" $ubuntuDistro
                        if ($codeResult) {
                            Write-Success "Project opened in VS Code (WSL context)"
                        } else {
                            Write-Warning "Could not open VS Code automatically. You can open it manually with: code '$appDir'"
                        }
                    } else {
                        Write-Warning "strangeloop recurse completed with warnings"
                    }
                } else {
                    Write-Warning "settings.yaml not found in ./strangeloop/ directory"
                }
            } else {
                Write-Warning "Could not update settings.yaml in WSL"
            }
            
            # Provide access instructions
            Write-Info "`nTo access your project:"
            Write-Host "  WSL: cd '$appDir'" -ForegroundColor Yellow
            Write-Host "  Windows: \\wsl.localhost\$ubuntuDistro$appDir" -ForegroundColor Yellow
            Write-Host "  VS Code: code '$appDir' (from WSL terminal)" -ForegroundColor Yellow
        } else {
            Write-Error "Loop initialization failed in WSL - strangeloop directory not created"
            Write-Info "Please check the error messages above and try manual initialization:"
            Write-Info "  wsl -d $ubuntuDistro -- bash -c \"cd '$appDir' && strangeloop init --loop $($selectedLoop.Name)\""
            exit 1
        }
    } else {
        # Windows development - use Windows file system
        $defaultAppDir = "q:\src\$appName"
        Write-Info "Using Windows environment for project initialization"
        $appDir = Get-UserInput "Application directory (Windows path)" $defaultAppDir
        
        # Create directory in Windows
        Write-Info "Creating application directory: $appDir"
        
        # Check if directory already exists and handle accordingly
        if (Test-Path $appDir) {
            Write-Warning "Directory '$appDir' already exists"
            
            # Check if it's already a StrangeLoop project
            $strangeloopPath = Join-Path $appDir "strangeloop"
            if (Test-Path $strangeloopPath) {
                Write-Warning "Directory appears to be an existing StrangeLoop project"
                $overwriteChoice = Get-UserInput "Do you want to reinitialize this project? This will overwrite existing configuration (y/n)" "n"
                if ($overwriteChoice -notmatch '^[Yy]') {
                    Write-Info "Skipping initialization. Using existing project directory."
                    $skipInitialization = $true
                } else {
                    Write-Info "Cleaning existing project and reinitializing..."
                    Get-ChildItem -Path $appDir -Force | Remove-Item -Recurse -Force
                    $skipInitialization = $false
                }
            } else {
                # Directory exists but not a StrangeLoop project
                $fileCount = (Get-ChildItem -Path $appDir -Force | Measure-Object).Count
                if ($fileCount -gt 0) {
                    Write-Warning "Directory contains $fileCount items"
                    $overwriteChoice = Get-UserInput "Directory is not empty. Continue anyway? (y/n)" "n"
                    if ($overwriteChoice -notmatch '^[Yy]') {
                        Write-Error "Cannot initialize in non-empty directory. Please choose a different path or clean the directory manually."
                        exit 1
                    }
                }
                $skipInitialization = $false
            }
        } else {
            New-Item -ItemType Directory -Path $appDir -Force | Out-Null
            $skipInitialization = $false
        }
        
        Write-Success "Directory ready for initialization"
        
        Set-Location $appDir
        
        if (-not $skipInitialization) {
            Write-Info "Initializing $($selectedLoop.Name) loop in Windows environment..."
            
            try {
                strangeloop init --loop $selectedLoop.Name
                Write-Success "Loop initialized successfully!"
            } catch {
                Write-Warning "Loop initialization encountered issues: $($_.Exception.Message)"
                # Check if strangeloop directory was created despite the error
                if (-not (Test-Path ".\strangeloop")) {
                    Write-Error "StrangeLoop initialization failed - no strangeloop directory created"
                    exit 1
                }
                Write-Info "Continuing with setup despite initialization warnings..."
            }
        } else {
            Write-Info "Using existing StrangeLoop project"
        }
        
        Write-Info "Files in project directory:"
        Get-ChildItem -Force | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Gray
        }
        
        # Update settings.yaml with project name
        $settingsPath = ".\strangeloop\settings.yaml"
        if (Test-Path $settingsPath) {
                Write-Info "Updating settings.yaml with project name..."
                try {
                    $settingsContent = Get-Content $settingsPath -Raw
                    # Update the name field in YAML
                    $updatedSettings = $settingsContent -replace '(name:\s*)[^\r\n]*', "`$1$appName"
                    Set-Content $settingsPath -Value $updatedSettings -NoNewline
                    Write-Success "Settings.yaml updated with project name: $appName"
                    
                    # Run strangeloop recurse to apply settings changes
                    Write-Info "Running strangeloop recurse to apply configuration changes..."
                    try {
                        strangeloop recurse
                        Write-Success "Configuration applied successfully with strangeloop recurse"
                        
                        # Open project in VS Code (Windows context)
                        Write-Info "Opening project in VS Code..."
                        try {
                            if (Test-Command "code") {
                                Start-Process "code" -ArgumentList "." -NoNewWindow -Wait:$false
                                Write-Success "Project opened in VS Code"
                            } else {
                                Write-Warning "VS Code 'code' command not found in PATH. Please open VS Code manually."
                                Write-Info "You can open the project by navigating to: $appDir"
                            }
                        } catch {
                            Write-Warning "Could not open VS Code automatically: $($_.Exception.Message)"
                            Write-Info "You can open the project manually by navigating to: $appDir"
                        }
                    } catch {
                        Write-Warning "strangeloop recurse completed with warnings: $($_.Exception.Message)"
                    }
                } catch {
                    Write-Warning "Could not update settings.yaml: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "settings.yaml not found in .\strangeloop\ directory"
            }
    }
    
} catch {
    Write-Error "Loop initialization failed: $($_.Exception.Message)"
    exit 1
}

# Final success message
Write-Step "Setup Completed Successfully!"
Write-Success "StrangeLoop CLI environment is ready!"
if ($needsLinux) {
    Write-Info "Application location (WSL): $appDir"
    Write-Info "Access via Windows: \\wsl.localhost\$ubuntuDistro$appDir"
    Write-Info "You can now start developing with StrangeLoop in your WSL environment!"
} else {
    Write-Info "Application location: $appDir"
    Write-Info "You can now start developing with StrangeLoop!"
}
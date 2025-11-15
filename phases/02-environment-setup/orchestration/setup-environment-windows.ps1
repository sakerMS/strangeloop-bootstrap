# strangeloop Bootstrap - Windows Environment Setup Script
# Version: 2.0.0
# Purpose: Handles Windows-specific environment setup and manages WSL invocation when needed

param(
    [switch]$CheckOnly,
    [switch]$WhatIf, 
    [switch]$NoWSL,
    [switch]$Verbose
)

# Import required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")
. (Join-Path $LibPath "platform\path-functions.ps1")

function Invoke-WindowsEnvironmentSetup {
    <#
    .SYNOPSIS
    Sets up Windows development environment and optionally manages WSL setup
    
    .DESCRIPTION
    This Windows-specific setup script:
    1. Installs Windows development tools (Git, Docker Desktop, Python, Poetry, Git LFS)
    2. Optionally installs and configures WSL
    3. Invokes Linux setup script inside WSL when WSL is enabled
    4. Validates the complete setup
    
    .PARAMETER CheckOnly
    Only validate current setup without making changes
    
    .PARAMETER WhatIf
    Show what would be performed without making any changes
    
    .PARAMETER NoWSL
    Skip WSL installation and configuration (Windows-only mode)
    
    .PARAMETER Verbose
    Show detailed progress information
    
    .RETURNS
    Hashtable with Success, Message, and Details properties
    #>
    param(
        [switch]$CheckOnly,
        [switch]$WhatIf,
        [switch]$NoWSL,
        [switch]$Verbose
    )
    
    try {
        $startTime = Get-Date
        $results = @{}
        $overallSuccess = $true
        
        Write-Step "Windows Environment Setup - Starting..."
        Write-Info "Mode: $(if ($NoWSL) { "Windows-only" } else { "Windows + WSL" })"
        
        if ($WhatIf) {
            Write-Host ""
            Write-Host "=== WINDOWS ENVIRONMENT SETUP (WHAT-IF MODE) ===" -ForegroundColor Yellow
            Write-Host "what if: Would execute the following Windows setup steps:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 1. Windows Development Tools Installation" -ForegroundColor Yellow
            Write-Host "what if:    - Git installation and configuration" -ForegroundColor Yellow
            Write-Host "what if:    - Docker Desktop installation and setup" -ForegroundColor Yellow
            Write-Host "what if:    - Python installation and configuration" -ForegroundColor Yellow
            Write-Host "what if:    - Poetry dependency manager installation" -ForegroundColor Yellow
            Write-Host "what if:    - Git LFS extension installation" -ForegroundColor Yellow
            Write-Host ""
            
            if (-not $NoWSL) {
                Write-Host "what if: 2. WSL Environment Setup" -ForegroundColor Yellow
                Write-Host "what if:    - WSL installation and distribution setup" -ForegroundColor Yellow
                Write-Host "what if:    - Provide instructions for manual Linux environment setup" -ForegroundColor Yellow
                Write-Host "what if:      (User must manually run Linux setup script inside WSL)" -ForegroundColor Yellow
                Write-Host ""
            } else {
                Write-Host "what if: 2. WSL Setup: SKIPPED (--NoWSL flag provided)" -ForegroundColor Yellow
                Write-Host ""
            }
            
            Write-Host "what if: 3. Environment Validation" -ForegroundColor Yellow
            Write-Host "what if:    - Verify all Windows tools are working" -ForegroundColor Yellow
            if (-not $NoWSL) {
                Write-Host "what if:    - Verify WSL distribution is functional" -ForegroundColor Yellow
                Write-Host "what if:    - Display instructions for Linux tool setup" -ForegroundColor Yellow
            }
            Write-Host ""
            
            return @{
                Success = $true
                Message = "What-if completed for Windows environment setup"
                Details = @{
                    Platform = "Windows"
                    WSLMode = -not $NoWSL
                    WhatIf = $true
                }
            }
        }
        
        # Step 1: Windows Development Tools Installation
        Write-Step "Step 1: Windows Development Tools Installation"
        Write-Info "Installing essential Windows development tools..."
        
        # Git Installation
        Write-Info "Installing Git for Windows..."
        $gitParams = @{ 'check-only' = $CheckOnly }
        $gitPath = Join-Path (Split-Path $PSScriptRoot -Parent) "git\windows\install-git-windows.ps1"
        
        if (Test-Path $gitPath) {
            try {
                $gitResult = & $gitPath @gitParams
                if ($gitResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Git installation completed"
                    $results["Git"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Git installation failed"
                    $results["Git"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Git installation error: $($_.Exception.Message)"
                $results["Git"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Git installation script not found: $gitPath"
            $results["Git"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Docker Desktop Installation  
        Write-Info "Installing Docker Desktop..."
        $dockerParams = @{ 'check-only' = $CheckOnly }
        $dockerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "docker\windows\install-docker-windows.ps1"
        
        if (Test-Path $dockerPath) {
            try {
                $dockerResult = & $dockerPath @dockerParams
                if ($dockerResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Docker Desktop installation completed"
                    $results["Docker Desktop"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Docker Desktop installation failed"
                    $results["Docker Desktop"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Docker Desktop installation error: $($_.Exception.Message)"
                $results["Docker Desktop"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Docker installation script not found: $dockerPath"
            $results["Docker Desktop"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Python Installation
        Write-Info "Installing Python for Windows..."
        $pythonParams = @{ 'check-only' = $CheckOnly }
        $pythonPath = Join-Path (Split-Path $PSScriptRoot -Parent) "python\windows\install-python-windows.ps1"
        
        if (Test-Path $pythonPath) {
            try {
                $pythonResult = & $pythonPath @pythonParams
                if ($pythonResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Python installation completed"
                    $results["Python"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Python installation failed"
                    $results["Python"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Python installation error: $($_.Exception.Message)"
                $results["Python"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Python installation script not found: $pythonPath"
            $results["Python"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Poetry Installation
        Write-Info "Installing Poetry dependency manager..."
        $poetryParams = @{ 'check-only' = $CheckOnly }
        $poetryPath = Join-Path (Split-Path $PSScriptRoot -Parent) "poetry\windows\install-poetry-windows.ps1"
        
        if (Test-Path $poetryPath) {
            try {
                $poetryResult = & $poetryPath @poetryParams
                if ($poetryResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Poetry installation completed"
                    $results["Poetry"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Poetry installation failed"
                    $results["Poetry"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Poetry installation error: $($_.Exception.Message)"
                $results["Poetry"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Poetry installation script not found: $poetryPath"
            $results["Poetry"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Git LFS Installation
        Write-Info "Installing Git LFS..."
        $gitLfsParams = @{ 'check-only' = $CheckOnly }
        $gitLfsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "git-lfs\windows\install-git-lfs-windows.ps1"
        
        if (Test-Path $gitLfsPath) {
            try {
                $gitLfsResult = & $gitLfsPath @gitLfsParams
                if ($gitLfsResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Git LFS installation completed"
                    $results["Git LFS"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Git LFS installation failed"
                    $results["Git LFS"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Git LFS installation error: $($_.Exception.Message)"
                $results["Git LFS"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Git LFS installation script not found: $gitLfsPath"
            $results["Git LFS"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Step 2: WSL Environment Setup (conditional)
        if (-not $NoWSL) {
            Write-Step "Step 2: WSL Environment Setup"
            Write-Info "Setting up Windows Subsystem for Linux distribution..."
            
            # WSL Installation and Distribution Setup Only
            Write-Info "Installing and configuring WSL distribution..."
            $wslParams = @{ 'check-only' = $CheckOnly }
            $wslPath = Join-Path (Split-Path $PSScriptRoot -Parent) "wsl-distro\setup-wsl-distro.ps1"
            
            if (Test-Path $wslPath) {
                try {
                    $wslResult = & $wslPath @wslParams
                    if ($wslResult -or $LASTEXITCODE -eq 0) {
                        Write-Success "WSL distribution setup completed"
                        $results["WSL Distribution"] = @{ Success = $true; Message = "Setup successful" }
                        
                        if (-not $CheckOnly) {
                            Write-Info ""
                            Write-Info "=== WSL Development Environment Setup Instructions ===" -ForegroundColor Cyan
                            Write-Info "Your WSL Ubuntu distribution has been set up successfully!"
                            Write-Info ""
                            Write-Info "To complete the Linux development environment setup:"
                            Write-Info "1. Open a new terminal/command prompt"
                            Write-Info "2. Enter WSL: wsl -d Ubuntu-24.04"
                            Write-Info "3. Navigate to this project: cd /mnt/q/src/strangeloop"
                            Write-Info "4. Run the Linux setup script:"
                            Write-Info "   pwsh ./cli/src/strangeloop/bootstrap/phases/02-environment-setup/orchestration/setup-environment-linux.ps1"
                            Write-Info ""
                            Write-Info "This will install all Linux development tools (Git, Docker, Python3, Poetry, Git LFS) inside WSL."
                            Write-Info "================================================================"
                            Write-Info ""
                        }
                    } else {
                        Write-Warning "WSL distribution setup failed"
                        $results["WSL Distribution"] = @{ Success = $false; Message = "Setup failed" }
                        $overallSuccess = $false
                    }
                } catch {
                    Write-Warning "WSL setup error: $($_.Exception.Message)"
                    $results["WSL Distribution"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                    $overallSuccess = $false
                }
            } else {
                Write-Warning "WSL setup script not found: $wslPath"
                $results["WSL Distribution"] = @{ Success = $false; Message = "Script not found" }
                $overallSuccess = $false
            }
        } else {
            Write-Step "Step 2: WSL Environment Setup"
            Write-Info "WSL setup SKIPPED (--NoWSL flag provided)"
            Write-Info "Windows-only development environment mode selected"
            $results["WSL Environment"] = @{ Success = $true; Message = "Skipped (--NoWSL flag)" }
        }
        
        # Step 3: Environment Validation
        Write-Step "Step 3: Windows Environment Validation"
        Write-Info "Validating Windows development environment..."
        
        $validationResults = @{}
        $windowsTools = @("git", "docker", "python", "poetry", "git-lfs")
        
        foreach ($tool in $windowsTools) {
            $toolFound = $false
            try {
                $null = Get-Command $tool -ErrorAction Stop
                Write-Success "$tool is available and working"
                $toolFound = $true
            } catch {
                Write-Warning "$tool is not available in PATH, attempting installation..."
                
                # Refresh PATH environment variable from registry (handles recent installations)
                Write-Info "Attempting PATH refresh without installation..."
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                # Test again after PATH refresh
                try {
                    $null = Get-Command $tool -ErrorAction Stop
                    Write-Success "$tool found after PATH refresh"
                    $toolFound = $true
                } catch {
                    Write-Warning "$tool is not available even after PATH refresh. Please install $tool manually."
                }
            }
            $validationResults[$tool] = $toolFound
        }
        
        # WSL validation (if enabled)
        if (-not $NoWSL) {
            try {
                $wslTest = & wsl --list --verbose 2>$null
                if ($LASTEXITCODE -eq 0 -and $wslTest) {
                    Write-Success "WSL is available and functional"
                    $validationResults["WSL"] = $true
                    
                    Write-Info "Note: WSL development tools should be installed manually by running:"
                    Write-Info "  wsl -d Ubuntu-24.04"
                    Write-Info "  pwsh ./cli/src/strangeloop/bootstrap/phases/02-environment-setup/orchestration/setup-environment-linux.ps1"
                } else {
                    Write-Warning "WSL is not available or not working"
                    $validationResults["WSL"] = $false
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "WSL validation failed: $($_.Exception.Message)"
                $validationResults["WSL"] = $false
                $overallSuccess = $false
            }
        }
        
        # Calculate success rate
        $successCount = ($validationResults.Values | Where-Object { $_ -eq $true }).Count
        $totalCount = $validationResults.Count
        $successRate = if ($totalCount -gt 0) { [math]::Round(($successCount / $totalCount) * 100, 1) } else { 0 }
        
        $results["Environment Validation"] = @{ 
            Success = ($successRate -ge 80)
            Message = "$successRate% tools validated successfully"
            Details = $validationResults
        }
        
        if ($successRate -lt 80) {
            $overallSuccess = $false
        }
        
        # Calculate timing and display summary
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host ""
        Write-Step "Windows Environment Setup Summary"
        Write-Info "Setup mode: $(if ($NoWSL) { "Windows-only" } else { "Windows + WSL" })"
        Write-Info "Execution time: $($duration.TotalSeconds.ToString("F1")) seconds"
        Write-Host ""
        
        # Display results
        foreach ($component in $results.Keys) {
            $result = $results[$component]
            $status = if ($result.Success) { "✓ Success" } else { "✗ Failed" }
            $color = if ($result.Success) { "Green" } else { "Red" }
            Write-Host "  ${component}: " -NoNewline
            Write-Host $status -ForegroundColor $color
            if ($result.Message) {
                Write-Host "    $($result.Message)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        
        if ($overallSuccess) {
            if ($CheckOnly) {
                Write-Success "Windows environment validation completed successfully"
            } else {
                Write-Success "Windows environment setup completed successfully"
            }
        } else {
            if ($CheckOnly) {
                Write-Error "Windows environment validation failed - some components are missing or misconfigured"
            } else {
                Write-Error "Windows environment setup failed - some components could not be installed or configured"
            }
        }
        
        return @{
            Success = $overallSuccess
            Message = if ($overallSuccess) { 
                "Windows environment setup completed successfully" 
            } else { 
                "Windows environment setup failed - check individual component results" 
            }
            Details = @{
                Platform = "Windows"
                WSLMode = -not $NoWSL
                Results = $results
                Duration = $duration.TotalSeconds
                StartTime = $startTime
                EndTime = $endTime
                CheckOnly = $CheckOnly.IsPresent
                ValidationResults = $validationResults
                SuccessRate = $successRate
            }
        }
        
    } catch {
        Write-Error "Windows environment setup failed with error: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Windows environment setup failed: $($_.Exception.Message)"
            Details = @{
                Platform = "Windows"
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Verify we're running on Windows
    $context = Get-ExecutionContext
    if ($context.ExecutionEnvironment -ne "WindowsNative") {
        Write-Error "This script is designed to run on Windows only. Current environment: $($context.ExecutionEnvironment)"
        Write-Info "Use setup-environment-linux.ps1 for Linux/WSL environments"
        exit 1
    }
    
    # Execute Windows environment setup
    $result = Invoke-WindowsEnvironmentSetup -CheckOnly:$CheckOnly -WhatIf:$WhatIf -NoWSL:$NoWSL -Verbose:$Verbose
    
    # Return result object for programmatic use
    return $result
}

# Export functions for module usage
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Invoke-WindowsEnvironmentSetup'
    )
}
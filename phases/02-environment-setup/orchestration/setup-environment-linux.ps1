# strangeloop Bootstrap - Linux Environment Setup Script
# Version: 2.0.0
# Purpose: Standalone Linux/WSL environment setup script

param(
    [switch]$CheckOnly,
    [switch]$WhatIf,
    [switch]$WSLMode,
    [switch]$Verbose
)

# Import required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")
. (Join-Path $LibPath "auth\linux-sudo.ps1")
. (Join-Path $LibPath "package\package-manager.ps1")

function Invoke-LinuxEnvironmentSetup {
    <#
    .SYNOPSIS
    Sets up Linux/WSL development environment with all required tools
    
    .DESCRIPTION
    This Linux-specific setup script:
    1. Updates system packages
    2. Installs Linux development tools (Git, Docker Engine, Python3, Poetry, Git LFS)
    3. Configures services and permissions
    4. Validates the complete setup
    
    Works standalone in both WSL and native Linux environments.
    
    .PARAMETER CheckOnly
    Only validate current setup without making changes
    
    .PARAMETER WhatIf
    Show what would be performed without making any changes
    
    .PARAMETER WSLMode
    Flag indicating this is running in WSL (affects Docker setup)
    
    .PARAMETER Verbose
    Show detailed progress information
    
    .RETURNS
    Hashtable with Success, Message, and Details properties
    #>
    param(
        [switch]$CheckOnly,
        [switch]$WhatIf,
        [switch]$WSLMode,
        [switch]$Verbose
    )
    
    try {
        $startTime = Get-Date
        $results = @{}
        $overallSuccess = $true
        
        Write-Step "Linux Environment Setup - Starting..."
        Write-Info "Environment: Linux"
        
        if ($WhatIf) {
            Write-Host ""
            Write-Host "=== LINUX ENVIRONMENT SETUP (WHAT-IF MODE) ===" -ForegroundColor Yellow
            Write-Host "what if: Would execute the following Linux setup steps:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 1. System Package Updates" -ForegroundColor Yellow
            Write-Host "what if:    - Update package lists (apt update)" -ForegroundColor Yellow
            Write-Host "what if:    - Install base development packages" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 2. Development Tools Installation" -ForegroundColor Yellow
            Write-Host "what if:    - Git installation and configuration" -ForegroundColor Yellow
            Write-Host "what if:    - Docker Engine installation and service setup" -ForegroundColor Yellow
            Write-Host "what if:    - Python3 and pip installation" -ForegroundColor Yellow
            Write-Host "what if:    - Poetry dependency manager installation" -ForegroundColor Yellow
            Write-Host "what if:    - Git LFS extension installation" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 3. Service Configuration" -ForegroundColor Yellow
            Write-Host "what if:    - Start and enable Docker service" -ForegroundColor Yellow
            Write-Host "what if:    - Configure user permissions for Docker" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 4. Environment Validation" -ForegroundColor Yellow
            Write-Host "what if:    - Verify all tools are working" -ForegroundColor Yellow
            Write-Host "what if:    - Test Docker functionality" -ForegroundColor Yellow
            Write-Host ""
            
            return @{
                Success = $true
                Message = "What-if completed for Linux environment setup"
                Details = @{
                    Platform = "Linux"
                    WhatIf = $true
                }
            }
        }
        
        # Step 1: System Package Updates
        Write-Step "Step 1: System Package Updates"
        Write-Info "Updating system packages and installing base dependencies..."
        
        try {
            if ($CheckOnly) {
                Write-Info "Check-only mode: Skipping package updates"
                $results["Package Updates"] = @{ Success = $true; Message = "Skipped (check-only mode)" }
            } else {
                # Update packages using standard Linux package management
                $updateResult = Install-BaseLinuxPackages
                if ($updateResult) {
                    Write-Success "System packages updated successfully"
                    $results["Package Updates"] = @{ Success = $true; Message = "Update successful" }
                } else {
                    Write-Warning "Package updates failed"
                    $results["Package Updates"] = @{ Success = $false; Message = "Update failed" }
                    $overallSuccess = $false
                }
            }
        } catch {
            Write-Warning "Package update error: $($_.Exception.Message)"
            $results["Package Updates"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
            $overallSuccess = $false
        }
        
        # Step 2: Development Tools Installation
        Write-Step "Step 2: Development Tools Installation"
        Write-Info "Installing essential Linux development tools..."
        
        # Git Installation
        Write-Info "Installing Git..."
        $gitParams = @{ 'check-only' = $CheckOnly }
        $gitPath = Join-Path (Split-Path $PSScriptRoot -Parent) "git\linux\install-git-linux.ps1"
        
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
        
        # Git LFS Installation
        Write-Info "Installing Git LFS..."
        $gitLfsParams = @{ 'check-only' = $CheckOnly }
        $gitLfsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "git-lfs\linux\install-git-lfs-linux.ps1"
        
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
        
        # Docker Engine Installation
        Write-Info "Installing Docker Engine..."
        $dockerParams = @{ 'check-only' = $CheckOnly }
        $dockerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "docker\linux\install-docker-linux.ps1"
        
        if (Test-Path $dockerPath) {
            try {
                $dockerResult = & $dockerPath @dockerParams
                if ($dockerResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Docker Engine installation completed"
                    $results["Docker Engine"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Docker Engine installation failed"
                    $results["Docker Engine"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Docker Engine installation error: $($_.Exception.Message)"
                $results["Docker Engine"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Docker installation script not found: $dockerPath"
            $results["Docker Engine"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Python3 Installation
        Write-Info "Installing Python3..."
        $pythonParams = @{ 'check-only' = $CheckOnly }
        $pythonPath = Join-Path (Split-Path $PSScriptRoot -Parent) "python\linux\install-python-linux.ps1"
        
        if (Test-Path $pythonPath) {
            try {
                $pythonResult = & $pythonPath @pythonParams
                if ($pythonResult -or $LASTEXITCODE -eq 0) {
                    Write-Success "Python3 installation completed"
                    $results["Python3"] = @{ Success = $true; Message = "Installation successful" }
                } else {
                    Write-Warning "Python3 installation failed"
                    $results["Python3"] = @{ Success = $false; Message = "Installation failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "Python3 installation error: $($_.Exception.Message)"
                $results["Python3"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Warning "Python installation script not found: $pythonPath"
            $results["Python3"] = @{ Success = $false; Message = "Script not found" }
            $overallSuccess = $false
        }
        
        # Poetry Installation
        Write-Info "Installing Poetry..."
        $poetryParams = @{ 'check-only' = $CheckOnly }
        if ($WhatIf) { $poetryParams['what-if'] = $true }
        $poetryPath = Join-Path (Split-Path $PSScriptRoot -Parent) "poetry\linux\install-poetry-linux.ps1"
        
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
        
        # Step 3: Service Configuration
        Write-Step "Step 3: Service Configuration"
        Write-Info "Configuring services and permissions..."
        
        if (-not $CheckOnly) {
            # Docker service configuration
            Write-Info "Configuring Docker service..."
            try {
                # Check if Docker Desktop integration is being used (has socket but no service)
                $dockerSocketExists = Test-Path "/var/run/docker.sock"
                $dockerServiceCheck = Invoke-SudoCommand -Command "systemctl list-unit-files docker.service"
                $dockerServiceExists = $dockerServiceCheck.Success -and ($dockerServiceCheck.Output -match "docker.service")
                
                if ($dockerSocketExists -and -not $dockerServiceExists) {
                    Write-Info "Docker Desktop WSL integration detected - Docker socket is available"
                    Write-Success "Docker is ready via Docker Desktop integration"
                    $results["Docker Service"] = @{ Success = $true; Message = "Docker Desktop integration" }
                } else {
                    # Try to start and enable Docker service only if it exists
                    $startResult = Invoke-SudoCommand -Command "systemctl start docker"
                    if ($startResult.Success) {
                        Write-Success "Docker service started"
                        
                        $enableResult = Invoke-SudoCommand -Command "systemctl enable docker"
                        if ($enableResult.Success) {
                            Write-Success "Docker service enabled for auto-start"
                            $results["Docker Service"] = @{ Success = $true; Message = "Service configured" }
                        } else {
                            Write-Warning "Failed to enable Docker service: $($enableResult.Output)"
                            $results["Docker Service"] = @{ Success = $false; Message = "Enable failed" }
                            $overallSuccess = $false
                        }
                    } else {
                        Write-Warning "Failed to start Docker service: $($startResult.Output)"
                        $results["Docker Service"] = @{ Success = $false; Message = "Start failed" }
                        $overallSuccess = $false
                    }
                }
            } catch {
                Write-Warning "Docker service configuration error: $($_.Exception.Message)"
                $results["Docker Service"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
            
            # User permissions configuration
            Write-Info "Configuring user permissions..."
            try {
                $currentUser = $env:USER
                if (-not $currentUser) {
                    $currentUser = whoami
                }
                
                $usermodResult = Invoke-SudoCommand -Command "usermod -aG docker $currentUser"
                if ($usermodResult.Success) {
                    Write-Success "User added to docker group"
                    Write-Info "Note: You may need to log out and back in for group changes to take effect"
                    $results["User Permissions"] = @{ Success = $true; Message = "Docker group configured" }
                } else {
                    Write-Warning "Failed to add user to docker group: $($usermodResult.Output)"
                    $results["User Permissions"] = @{ Success = $false; Message = "Group configuration failed" }
                    $overallSuccess = $false
                }
            } catch {
                Write-Warning "User permissions configuration error: $($_.Exception.Message)"
                $results["User Permissions"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
                $overallSuccess = $false
            }
        } else {
            Write-Info "Check-only mode: Skipping service configuration"
            $results["Service Configuration"] = @{ Success = $true; Message = "Skipped (check-only mode)" }
        }
        
        # Step 4: Environment Validation
        Write-Step "Step 4: Linux Environment Validation"
        Write-Info "Validating Linux development environment..."
        
        $validationResults = @{}
        $linuxTools = @("git", "docker", "python3", "poetry", "git-lfs")
        
        foreach ($tool in $linuxTools) {
            $toolFound = $false
            try {
                $null = Get-Command $tool -ErrorAction Stop
                Write-Success "$tool is available and working"
                $toolFound = $true
            } catch {
                Write-Warning "$tool is not available in PATH, attempting installation..."
                
                # Refresh PATH environment variable (Linux/WSL style - handles recent installations)
                Write-Info "Attempting PATH refresh without installation..."
                
                # Add common Linux tool locations to PATH
                $commonPaths = @(
                    "$env:HOME/.local/bin",      # pipx and user installs
                    "/usr/bin",                  # system packages
                    "/usr/local/bin",           # manual installs
                    "/snap/bin"                 # snap packages
                )
                
                foreach ($path in $commonPaths) {
                    if ((Test-Path $path) -and ($env:PATH -notlike "*$path*")) {
                        $env:PATH = "$path" + ":" + $env:PATH
                    }
                }
                
                # Test again after PATH refresh
                try {
                    $null = Get-Command $tool -ErrorAction Stop
                    Write-Success "$tool found after PATH refresh"
                    $toolFound = $true
                } catch {
                    # For specific tools, try direct paths as fallback
                    $directPath = $null
                    switch ($tool) {
                        "poetry" { 
                            $directPath = "$env:HOME/.local/share/pipx/venvs/poetry/bin/poetry"
                            if (-not (Test-Path $directPath)) {
                                $directPath = "$env:HOME/.local/bin/poetry"
                            }
                        }
                        "docker" { $directPath = "/usr/bin/docker" }
                        "git" { $directPath = "/usr/bin/git" }
                        "python3" { $directPath = "/usr/bin/python3" }
                        "git-lfs" { $directPath = "/usr/bin/git-lfs" }
                    }
                    
                    if ($directPath -and (Test-Path $directPath)) {
                        Write-Success "$tool found at direct path: $directPath"
                        $toolFound = $true
                    } else {
                        Write-Warning "$tool is not available even after PATH refresh. Please install $tool manually."
                    }
                }
            }
            $validationResults[$tool] = $toolFound
        }
        
        # Docker functionality test
        Write-Info "Testing Docker functionality..."
        try {
            $null = docker info 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker daemon is accessible"
                $validationResults["Docker Daemon"] = $true
                
                # Test basic Docker functionality
                if (-not $CheckOnly) {
                    Write-Info "Testing Docker container functionality..."
                    $null = docker run --rm hello-world 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Docker container test passed"
                        $validationResults["Docker Functionality"] = $true
                    } else {
                        Write-Warning "Docker container test failed"
                        $validationResults["Docker Functionality"] = $false
                    }
                }
            } else {
                Write-Info "Docker daemon is not running - you may need to start it manually"
                $validationResults["Docker Daemon"] = $false
            }
        } catch {
            Write-Warning "Docker validation failed: $($_.Exception.Message)"
            $validationResults["Docker Daemon"] = $false
        }
        
        # Python functionality test
        Write-Info "Testing Python functionality..."
        try {
            $pythonVersion = python3 --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Python3 is working: $pythonVersion"
                $validationResults["Python3 Version"] = $true
                
                # Test pip
                $null = python3 -m pip --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "pip is working"
                    $validationResults["pip"] = $true
                } else {
                    Write-Warning "pip is not working"
                    $validationResults["pip"] = $false
                }
            } else {
                Write-Warning "Python3 version check failed"
                $validationResults["Python3 Version"] = $false
            }
        } catch {
            Write-Warning "Python validation failed: $($_.Exception.Message)"
            $validationResults["Python3 Version"] = $false
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
        Write-Step "Linux Environment Setup Summary"
        Write-Info "Environment: Linux"
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
                Write-Success "Linux environment validation completed successfully"
            } else {
                Write-Success "Linux environment setup completed successfully"
            }
        } else {
            if ($CheckOnly) {
                Write-Error "Linux environment validation failed - some components are missing or misconfigured"
            } else {
                Write-Error "Linux environment setup failed - some components could not be installed or configured"
            }
        }
        
        return @{
            Success = $overallSuccess
            Message = if ($overallSuccess) { 
                "Linux environment setup completed successfully" 
            } else { 
                "Linux environment setup failed - check individual component results" 
            }
            Details = @{
                Platform = "Linux"
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
        Write-Error "Linux environment setup failed with error: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Linux environment setup failed: $($_.Exception.Message)"
            Details = @{
                Platform = "Linux"
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Verify we're running on Linux/WSL
    $context = Get-ExecutionContext
    if ($context.ExecutionEnvironment -notin @("WSLNative", "LinuxNative")) {
        Write-Error "This script is designed to run on Linux/WSL only. Current environment: $($context.ExecutionEnvironment)"
        Write-Info "Use setup-environment-windows.ps1 for Windows environments"
        exit 1
    }
    
    # Execute Linux environment setup
    $result = Invoke-LinuxEnvironmentSetup -CheckOnly:$CheckOnly -WhatIf:$WhatIf -WSLMode:$WSLMode -Verbose:$Verbose
    
    # Exit with appropriate code
    if ($result.Success) {
        exit 0
    } else {
        Write-Error $result.Message
        exit 1
    }
}

# Export functions for module usage
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Invoke-LinuxEnvironmentSetup'
    )
}
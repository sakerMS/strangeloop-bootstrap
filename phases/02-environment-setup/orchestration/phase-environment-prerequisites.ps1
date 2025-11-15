# strangeloop Bootstrap - Phase 2: Environment Prerequisites Module
# Version: 2.0.0
# Purpose: Consolidated Environment Prerequisites setup for the new 3-phase architecture

param(
    [switch]$CheckOnly,
    [switch]$WhatIf,
    [switch]$NoWSL,
    [string]$ExecutionEngine = "StrangeloopCLI"
)

# Import required modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")
. (Join-Path $LibPath "platform\config-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Invoke-ToolRouter {
    <#
    .SYNOPSIS
    Helper function to invoke tool router scripts with consistent error handling
    
    .PARAMETER ToolName
    Display name of the tool being installed
    
    .PARAMETER RouterPath
    Path to the router script
    
    .PARAMETER Parameters
    Parameters to pass to the router script
    
    .PARAMETER Results
    Reference to results hashtable to update
    
    .PARAMETER OverallSuccess
    Reference to overall success flag to update
    
    .PARAMETER WSLMode
    Whether to pass WSLMode parameter for WSL tunnel execution
    #>
    param(
        [string]$ToolName,
        [string]$RouterPath,
        [hashtable]$Parameters,
        [ref]$Results,
        [ref]$OverallSuccess,
        [switch]$WSLMode
    )
    
    if (-not (Test-Path $RouterPath)) {
        Write-Warning "$ToolName router script not found: $RouterPath"
        $Results.Value["$ToolName Setup"] = @{ Success = $false; Message = "Router script not found" }
        $OverallSuccess.Value = $false
        return
    }
    
    # Add WSLMode parameter if specified
    if ($WSLMode) {
        $Parameters['WSLMode'] = $true
    }
    
    try {
        $result = & $RouterPath @Parameters
        $success = ($result -eq $true) -or ($LASTEXITCODE -eq 0)
        
        if ($success) {
            Write-Success "$ToolName installation completed successfully"
            $Results.Value["$ToolName Setup"] = @{ Success = $true; Message = "Installation completed" }
        } else {
            Write-Warning "$ToolName installation failed"
            $Results.Value["$ToolName Setup"] = @{ Success = $false; Message = "Installation failed" }
            $OverallSuccess.Value = $false
        }
    } catch {
        Write-Warning "$ToolName setup failed: $($_.Exception.Message)"
        $Results.Value["$ToolName Setup"] = @{ Success = $false; Message = "Error: $($_.Exception.Message)" }
        $OverallSuccess.Value = $false
    }
}

function Invoke-EnvironmentPrerequisites {
    <#
    .SYNOPSIS
    Executes Phase 2: Environment Prerequisites setup in the new 3-phase architecture
    
    .DESCRIPTION
    Sets up additional development tools and environment using platform-aware router scripts.
    The router scripts handle all platform-specific logic including:
    - Platform detection (Windows, Linux, macOS, WSL)
    - Git installation and configuration
    - Docker Desktop/Engine installation and setup
    - Python and Poetry installation (platform-specific)
    - Git LFS setup
    - WSL installation and environment setup (conditional on --no-wsl flag)
    - Cross-platform tool validation
    
    This function focuses on orchestrating the router scripts rather than containing platform logic.
    
    .PARAMETER CheckOnly
    Only validate current setup without making changes
    
    .PARAMETER WhatIf
    Show what would be performed without making any changes
    
    .PARAMETER NoWSL
    Skip WSL installation and configuration on Windows (Windows-only development)
    
    .PARAMETER Cli
    CLI mode: When specified, execute individual detailed steps (running from within strangeloop CLI).
    When NOT specified, use strangeloop CLI prereqs command (running from PowerShell directly).
    
    .OUTPUTS
    Hashtable with Success, Phase, Message, and Details properties
    
    .EXAMPLE
    Invoke-EnvironmentPrerequisites
    Run complete Phase 2 environment setup using router scripts
    
    .EXAMPLE
    Invoke-EnvironmentPrerequisites -CheckOnly
    Validate Phase 2 environment prerequisites without installing
    
    .EXAMPLE
    Invoke-EnvironmentPrerequisites -NoWSL
    Run Phase 2 setup but skip WSL installation on Windows
    
    .EXAMPLE
    Invoke-EnvironmentPrerequisites -ExecutionEngine PowerShell
    Run Phase 2 with individual router script calls (when using PowerShell execution engine)
    #>
    param(
        [switch]$CheckOnly,
        [switch]$WhatIf,
        [switch]$NoWSL,
        [string]$ExecutionEngine = "StrangeloopCLI"
    )
    
    try {
        Write-Step "Phase 2: Environment Prerequisites Setup..."
        Write-Info "Setting up additional development tools and environment using platform-aware routers"
        
        # Initialize result tracking
        $results = @{}
        $overallSuccess = $true
        $startTime = Get-Date
        
        # Get phase configuration
        $phaseConfig = Get-BootstrapPhases
        $phase2Config = $phaseConfig["2"]
        
        # Detect current platform
        $currentPlatform = Get-CurrentPlatform
        $platformIsWindows = $currentPlatform -eq "Windows"
        $platformIsLinux = $currentPlatform -eq "Linux" 
        $platformIsMacOS = $currentPlatform -eq "macOS"
        $platformIsWSL = $currentPlatform -eq "WSL"
        
        # StrangeloopCLI Execution Path: Use strangeloop CLI prereqs command (when using StrangeloopCLI)
        if ($ExecutionEngine -eq "StrangeloopCLI") {
            Write-Host ""
            Write-Host "=== PHASE 2: ENVIRONMENT PREREQUISITES (STRANGELOOP CLI MODE) ===" -ForegroundColor Cyan
            Write-Info "Using strangeloop CLI prereqs command for environment setup"
            Write-Info "Platform: $currentPlatform"
            Write-Info "This path uses the strangeloop CLI tool for streamlined prerequisite installation"
            Write-Host ""
            
            if ($WhatIf) {
                Write-Host "what if: StrangeloopCLI Execution Path - Would execute:" -ForegroundColor Yellow
                Write-Host "what if:   strangeloop cli prereqs --force" -ForegroundColor Yellow
                Write-Host "what if: This command handles all environment setup steps automatically" -ForegroundColor Yellow
                Write-Host "what if: Estimated duration: $($phase2Config.EstimatedDurationMinutes) minutes" -ForegroundColor Yellow
                
                return @{
                    Success = $true
                    Phase = "Environment Prerequisites"
                    Message = "What-if completed for Phase 2: Router-based execution"
                    Details = @{
                        ExecutionPath = "StrangeloopCLI Mode"
                        Platform = $currentPlatform
                        Command = "strangeloop cli prereqs --force"
                        EstimatedDuration = "$($phase2Config.EstimatedDurationMinutes) minutes"
                        StartTime = $startTime
                        EndTime = Get-Date
                        Duration = ((Get-Date) - $startTime).TotalSeconds
                    }
                }
            }
            
            if ($CheckOnly) {
                Write-Info "Check-only mode: Validating strangeloop CLI prereqs command availability"
                
                try {
                    # Test if strangeloop CLI is available
                    $strangeloopCheck = strangeloop version 2>&1
                    if ($LASTEXITCODE -eq 0 -and $strangeloopCheck) {
                        Write-Success "strangeloop CLI is available and ready for prereqs command"
                        return @{
                            Success = $true
                            Phase = "Environment Prerequisites"
                            Message = "CLI prereqs command is available"
                            Details = @{
                                ExecutionPath = "StrangeloopCLI Mode (Check Only)"
                                Platform = $currentPlatform
                                CheckOnly = $true
                                StrangeloopVersion = $strangeloopCheck
                            }
                        }
                    } else {
                        Write-Warning "strangeloop CLI is not available or not working"
                        return @{
                            Success = $false
                            Phase = "Environment Prerequisites"
                            Message = "strangeloop CLI prereqs command is not available"
                            Details = @{
                                ExecutionPath = "StrangeloopCLI Mode (Check Only)"
                                Platform = $currentPlatform
                                Error = "CLI not available"
                                CheckOnly = $true
                            }
                        }
                    }
                } catch {
                    Write-Warning "Failed to check strangeloop CLI: $($_.Exception.Message)"
                    return @{
                        Success = $false
                        Phase = "Environment Prerequisites"
                        Message = "Failed to check strangeloop CLI availability"
                        Details = @{
                            ExecutionPath = "StrangeloopCLI Mode (Check Only)"
                            Platform = $currentPlatform
                            Error = $_.Exception.Message
                            CheckOnly = $true
                        }
                    }
                }
            }
            
            # Execute strangeloop CLI prereqs command
            Write-Info "Executing strangeloop CLI prereqs command..."
            Write-Info "This will configure the complete development environment automatically"
            
            try {
                $result = & strangeloop cli prereqs --force
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0) {
                    $endTime = Get-Date
                    $duration = $endTime - $startTime
                    
                    Write-Success "strangeloop CLI prereqs command completed successfully"
                    Write-Info "Environment setup completed via CLI in $($duration.TotalSeconds.ToString("F1")) seconds"
                    
                    return @{
                        Success = $true
                        Phase = "Environment Prerequisites"
                        Message = "Environment setup completed via strangeloop CLI prereqs"
                        Details = @{
                            ExecutionPath = "StrangeloopCLI Mode"
                            Platform = $currentPlatform
                            Command = "strangeloop cli prereqs --force"
                            ExitCode = $exitCode
                            StartTime = $startTime
                            EndTime = $endTime
                            Duration = $duration.TotalSeconds
                        }
                    }
                } else {
                    Write-Warning "strangeloop CLI prereqs command failed with exit code: $exitCode"
                    return @{
                        Success = $false
                        Phase = "Environment Prerequisites"
                        Message = "strangeloop CLI prereqs command failed"
                        Details = @{
                            ExecutionPath = "StrangeloopCLI Mode"
                            Platform = $currentPlatform
                            Command = "strangeloop cli prereqs --force"
                            ExitCode = $exitCode
                            Error = "Command failed with exit code $exitCode"
                        }
                    }
                }
            } catch {
                Write-Error "Failed to execute strangeloop CLI prereqs: $($_.Exception.Message)"
                return @{
                    Success = $false
                    Phase = "Environment Prerequisites"
                    Message = "Failed to execute strangeloop CLI prereqs command"
                    Details = @{
                        ExecutionPath = "StrangeloopCLI Mode"
                        Platform = $currentPlatform
                        Error = $_.Exception.Message
                        StackTrace = $_.ScriptStackTrace
                    }
                }
            }
        } else {
            # PowerShell Engine Mode: Execute router scripts (when using PowerShell execution engine)
            Write-Host ""
            Write-Host "=== PHASE 2: ENVIRONMENT PREREQUISITES (ROUTER MODE) ===" -ForegroundColor Cyan
            Write-Info "Executing environment setup using intelligent platform router"
            Write-Info "Platform detection and routing eliminates Windows vs WSL confusion"
            Write-Host ""
        
        if ($WhatIf) {
            Write-Host "=== PHASE 2: ENVIRONMENT PREREQUISITES (ROUTER MODE - WHAT-IF) ===" -ForegroundColor Yellow
            Write-Host "what if: Would execute the intelligent environment setup router:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 1. Platform Detection and Context Analysis" -ForegroundColor Yellow
            Write-Host "what if:    - Detect exact execution context (Windows, WSL, Linux)" -ForegroundColor Yellow
            Write-Host "what if:    - Determine optimal setup strategy" -ForegroundColor Yellow
            Write-Host "what if:    - Plan Windows vs WSL execution paths" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: 2. Intelligent Routing Decision" -ForegroundColor Yellow
            Write-Host "what if:    - Route to setup-environment-windows.ps1 if on Windows" -ForegroundColor Yellow
            Write-Host "what if:    - Route to setup-environment-linux.ps1 if on Linux/WSL" -ForegroundColor Yellow
            Write-Host "what if:    - Handle WSL invocation from Windows when needed" -ForegroundColor Yellow
            Write-Host ""
            if ($platformIsWindows -and -not $NoWSL) {
                Write-Host "what if: 3. Windows + WSL Setup Strategy" -ForegroundColor Yellow
                Write-Host "what if:    - Setup Windows development tools" -ForegroundColor Yellow
                Write-Host "what if:    - Install and configure WSL environment" -ForegroundColor Yellow
                Write-Host "what if:    - Execute Linux setup inside WSL via:" -ForegroundColor Yellow
                Write-Host "what if:      wsl pwsh <dynamically-resolved-path>/setup-environment-linux.ps1" -ForegroundColor Yellow
                Write-Host ""
            } elseif ($platformIsWindows -and $NoWSL) {
                Write-Host "what if: 3. Windows-Only Setup Strategy" -ForegroundColor Yellow
                Write-Host "what if:    - Setup Windows development tools only" -ForegroundColor Yellow
                Write-Host "what if:    - Skip WSL installation (--NoWSL flag)" -ForegroundColor Yellow
                Write-Host ""
            } else {
                Write-Host "what if: 3. Linux/WSL Setup Strategy" -ForegroundColor Yellow
                Write-Host "what if:    - Setup Linux development tools" -ForegroundColor Yellow
                Write-Host "what if:    - Configure native Linux environment" -ForegroundColor Yellow
                Write-Host ""
            }
            
            Write-Host "what if: 4. Environment Validation" -ForegroundColor Yellow
            Write-Host "what if:    - Validate all installed tools" -ForegroundColor Yellow
            Write-Host "what if:    - Test cross-platform functionality" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "what if: Router advantages:" -ForegroundColor Yellow
            Write-Host "what if:   • Eliminates confusion about Windows vs WSL execution" -ForegroundColor Yellow
            Write-Host "what if:   • Handles WSL invocation automatically when needed" -ForegroundColor Yellow
            Write-Host "what if:   • Provides clear execution context reporting" -ForegroundColor Yellow
            Write-Host "what if:   • Enables platform-specific optimizations" -ForegroundColor Yellow
            Write-Host "what if: Estimated duration: $($phase2Config.EstimatedDurationMinutes) minutes" -ForegroundColor Yellow
            
            return @{
                Success = $true
                Phase = "Environment Prerequisites"
                Message = "What-if completed for Phase 2: Intelligent router-based execution"
                Details = @{
                    ExecutionPath = "Intelligent Router Mode (What-If)"
                    Platform = $currentPlatform
                    EstimatedDuration = "$($phase2Config.EstimatedDurationMinutes) minutes"
                    WSLMode = if ($platformIsWindows) { if ($NoWSL) { "Disabled" } else { "Enabled" } } else { "Not Applicable" }
                    StartTime = $startTime
                    EndTime = Get-Date
                    Duration = ((Get-Date) - $startTime).TotalSeconds
                }
            }
        }
        
        Write-Host ""
        Write-Host "=== PHASE 2: ENVIRONMENT PREREQUISITES ===" -ForegroundColor Cyan
        Write-Info "Intelligent router-based development environment setup"
        Write-Info "Estimated duration: $($phase2Config.EstimatedDurationMinutes) minutes"
        Write-Host ""
        
        # Execute the intelligent environment setup router
        Write-Step "Executing Intelligent Environment Setup Router"
        Write-Info "The router will detect execution context and route to appropriate platform script"
        
        try {
            # Build router parameters
            $routerParams = @{}
            if ($CheckOnly) { $routerParams['CheckOnly'] = $true }
            if ($WhatIf) { $routerParams['WhatIf'] = $true }
            if ($NoWSL) { $routerParams['NoWSL'] = $true }
            
            # Execute the main router
            $routerPath = Join-Path $PSScriptRoot "setup-environment-router.ps1"
            
            if (-not (Test-Path $routerPath)) {
                throw "Environment setup router not found: $routerPath"
            }
            
            Write-Info "Executing router: $(Split-Path $routerPath -Leaf)"
            $routerResult = & $routerPath @routerParams
            $routerExitCode = $LASTEXITCODE
            
            # Process router results
            if ($routerExitCode -eq 0 -and (($routerResult -is [hashtable] -and $routerResult.Success) -or $routerResult -eq $true)) {
                Write-Success "Environment setup completed successfully via intelligent router"
                
                $endTime = Get-Date
                $duration = $endTime - $startTime
                
                return @{
                    Success = $true
                    Phase = "Environment Prerequisites"
                    Message = "Environment setup completed successfully using intelligent router"
                    Details = @{
                        ExecutionPath = "Intelligent Router Mode"
                        Platform = $currentPlatform
                        RouterResult = $routerResult
                        Duration = $duration.TotalSeconds
                        StartTime = $startTime
                        EndTime = $endTime
                        CheckOnly = $CheckOnly.IsPresent
                    }
                }
            } else {
                $errorMessage = if ($routerResult -is [hashtable] -and $routerResult.Message) { 
                    $routerResult.Message 
                } else { 
                    "Router execution failed with exit code: $routerExitCode" 
                }
                
                Write-Error "Environment setup router failed: $errorMessage"
                
                return @{
                    Success = $false
                    Phase = "Environment Prerequisites"
                    Message = "Environment setup failed: $errorMessage"
                    Details = @{
                        ExecutionPath = "Intelligent Router Mode"
                        Platform = $currentPlatform
                        RouterResult = $routerResult
                        ExitCode = $routerExitCode
                        Error = $errorMessage
                    }
                }
            }
            
        } catch {
            Write-Error "Environment setup router execution failed: $($_.Exception.Message)"
            
            return @{
                Success = $false
                Phase = "Environment Prerequisites"
                Message = "Router execution failed: $($_.Exception.Message)"
                Details = @{
                    ExecutionPath = "Intelligent Router Mode"
                    Platform = $currentPlatform
                    Error = $_.Exception.Message
                    StackTrace = $_.ScriptStackTrace
                }
            }
        }
        
        } # End PowerShell Engine Mode else block
        
    } catch {
        Write-Error "Phase 2 (Environment Prerequisites) failed with error: $($_.Exception.Message)"
        return @{
            Success = $false
            Phase = "Environment Prerequisites"
            Message = "Phase 2 failed with error: $($_.Exception.Message)"
            Details = @{
                ExecutionPath = "Router Mode"
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

function Test-EnvironmentPrerequisites {
    <#
    .SYNOPSIS
    Tests if all environment prerequisites are properly installed and configured
    
    .DESCRIPTION
    Validates Phase 2 components without making any changes using router scripts
    
    .OUTPUTS
    Hashtable with validation results
    #>
    param()
    
    return Invoke-EnvironmentPrerequisites -CheckOnly
}

function Get-EnvironmentPrerequisitesStatus {
    <#
    .SYNOPSIS
    Gets the current status of all environment prerequisites
    
    .DESCRIPTION
    Returns detailed status information about each environment prerequisite component
    
    .OUTPUTS
    Hashtable with detailed status information
    #>
    param()
    
    $currentPlatform = Get-CurrentPlatform
    $status = @{
        Platform = $currentPlatform
        Git = @{ Installed = $false; Version = $null }
        Docker = @{ Installed = $false; Version = $null }
        Python = @{ Installed = $false; Version = $null }
        Poetry = @{ Installed = $false; Version = $null }
    }
    
    # Add WSL status for Windows
    if ($currentPlatform -eq "Windows") {
        $status.WSL = @{ Installed = $false; Version = $null; Distribution = $null }
    }
    
    try {
        # Check Git
        try {
            $gitVersion = git --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitVersion) {
                $status.Git.Installed = $true
                if ($gitVersion -match "git version (\d+\.\d+\.\d+)") {
                    $status.Git.Version = $matches[1]
                }
            }
        } catch {
            # Git not available
        }
        
        # Check Docker
        try {
            $dockerVersion = docker --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
                $status.Docker.Installed = $true
                if ($dockerVersion -match "Docker version (\d+\.\d+\.\d+)") {
                    $status.Docker.Version = $matches[1]
                }
            }
        } catch {
            # Docker not available
        }
        
        # Check Python (platform-specific)
        try {
            if ($currentPlatform -eq "Windows") {
                $pythonVersion = python --version 2>$null
            } else {
                $pythonVersion = python3 --version 2>$null
            }
            
            if ($LASTEXITCODE -eq 0 -and $pythonVersion) {
                $status.Python.Installed = $true
                if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
                    $status.Python.Version = $matches[1]
                }
            }
        } catch {
            # Python not available
        }
        
        # Check Poetry
        try {
            $poetryVersion = poetry --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $poetryVersion) {
                $status.Poetry.Installed = $true
                if ($poetryVersion -match "Poetry \(version (\d+\.\d+\.\d+)\)") {
                    $status.Poetry.Version = $matches[1]
                }
            }
        } catch {
            # Poetry not available
        }
        
        # Check WSL (Windows only)
        if ($currentPlatform -eq "Windows") {
            try {
                $wslList = wsl --list --verbose 2>$null
                if ($LASTEXITCODE -eq 0 -and $wslList) {
                    $status.WSL.Installed = $true
                    if ($wslList -match "Ubuntu|Debian|SUSE") {
                        $wslLines = $wslList -split "`n"
                        foreach ($line in $wslLines) {
                            if ($line -match "(Ubuntu|Debian|SUSE).*Running") {
                                $status.WSL.Distribution = $matches[1]
                                break
                            }
                        }
                    }
                }
            } catch {
                # WSL not available
            }
        }
        
    } catch {
        Write-Warning "Error checking environment prerequisites status: $($_.Exception.Message)"
    }
    
    return $status
}

# Export functions when used as a module
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Invoke-EnvironmentPrerequisites',
        'Test-EnvironmentPrerequisites', 
        'Get-EnvironmentPrerequisitesStatus'
    )
}

# If called directly (not imported as module), execute main function
if ($MyInvocation.InvocationName -ne '.') {
    # Execute the main function with provided parameters
    $result = Invoke-EnvironmentPrerequisites -CheckOnly:$CheckOnly -WhatIf:$WhatIf -NoWSL:$NoWSL -ExecutionEngine $ExecutionEngine
    
    # Exit with appropriate code
    if ($result.Success) {
        exit 0
    } else {
        Write-Error $result.Message
        exit 1
    }
}
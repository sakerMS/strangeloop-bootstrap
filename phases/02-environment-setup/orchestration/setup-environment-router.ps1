# strangeloop Bootstrap - Phase 2 Environment Setup Router
# Version: 2.0.0  
# Purpose: Intelligent router that eliminates Windows vs WSL execution confusion

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
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Invoke-EnvironmentSetupRouter {
    <#
    .SYNOPSIS
    Intelligent router for Phase 2 environment setup that eliminates Windows vs WSL confusion
    
    .DESCRIPTION
    This router:
    1. Detects the exact execution context (Windows native, WSL native, Linux native)
    2. Routes to the appropriate platform-specific setup script
    3. Handles WSL invocation from Windows when needed
    4. Provides clear feedback about what's happening where
    
    .PARAMETER CheckOnly
    Only validate current setup without making changes
    
    .PARAMETER WhatIf
    Show what would be performed without making any changes
    
    .PARAMETER NoWSL
    Skip WSL installation and configuration on Windows
    
    .PARAMETER Verbose
    Show detailed execution context information
    
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
        Write-Step "Phase 2 Environment Setup Router - Analyzing execution context..."
        
        # Get detailed execution context
        $detectedContext = Get-ExecutionContext
        $setupStrategy = Get-RecommendedSetupStrategy -NoWSL:$NoWSL
        
        if ($Verbose) {
            Write-ExecutionContextReport -Context $detectedContext
        } else {
            Write-Info "Detected execution environment: $($detectedContext.ExecutionEnvironment)"
            Write-Info "Recommended approach: $($detectedContext.RecommendedApproach)"
        }
        
        # Display strategy and warnings
        if ($setupStrategy.Warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "Important Notes:" -ForegroundColor Yellow
            foreach ($warning in $setupStrategy.Warnings) {
                Write-Warning $warning
            }
            Write-Host ""
        }
        
        # WhatIf mode - show execution plan
        if ($WhatIf) {
            Write-Host ""
            Write-Host "=== EXECUTION PLAN (WHAT-IF MODE) ===" -ForegroundColor Yellow
            Write-Host "what if: Primary script: $($setupStrategy.PrimaryScript)" -ForegroundColor Yellow
            Write-Host "what if: Setup scope: $($setupStrategy.SetupScope)" -ForegroundColor Yellow
            
            if ($setupStrategy.WSLInvocation) {
                Write-Host "what if: WSL invocation required: Yes" -ForegroundColor Yellow
            } else {
                Write-Host "what if: WSL invocation required: No" -ForegroundColor Yellow
            }
            
            Write-Host ""
            Write-Host "what if: Execution steps:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $setupStrategy.ExecutionSteps.Count; $i++) {
                Write-Host "what if:   $($i + 1). $($setupStrategy.ExecutionSteps[$i])" -ForegroundColor Yellow
            }
            
            return @{
                Success = $true
                Message = "What-if execution plan completed"
                Details = @{
                    ExecutionContext = $detectedContext
                    SetupStrategy = $setupStrategy
                    WhatIf = $true
                }
            }
        }
        
        # Route to appropriate implementation
        $result = $null
        $scriptPath = ""
        
        switch ($detectedContext.ExecutionEnvironment) {
            "WindowsNative" {
                Write-Step "Routing to Windows environment setup..."
                $scriptPath = Join-Path $PSScriptRoot "setup-environment-windows.ps1"
                
                if (-not (Test-Path $scriptPath)) {
                    throw "Windows setup script not found: $scriptPath"
                }
                
                # Build parameters for Windows script
                $windowsParams = @{}
                if ($CheckOnly) { $windowsParams['CheckOnly'] = $true }
                if ($WhatIf) { $windowsParams['WhatIf'] = $true }
                if ($NoWSL) { $windowsParams['NoWSL'] = $true }
                if ($Verbose) { $windowsParams['Verbose'] = $true }
                
                Write-Info "Executing Windows environment setup script..."
                $result = & $scriptPath @windowsParams
                $exitCode = $LASTEXITCODE
            }
            
            { $_ -in @("WSLNative", "LinuxNative") } {
                Write-Step "Routing to Linux environment setup..."
                
                # Check if PowerShell is available in the current environment
                if ($detectedContext.ExecutionEnvironment -eq "WSLNative") {
                    # We're in WSL - check if PowerShell is available
                    $pwshAvailable = $null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)
                    
                    if (-not $pwshAvailable) {
                        Write-Warning "PowerShell not available in WSL environment"
                        Write-Info "Falling back to Windows script to install PowerShell in WSL first..."
                        
                        # Route to Windows script instead to handle WSL PowerShell installation
                        $scriptPath = Join-Path $PSScriptRoot "setup-environment-windows.ps1"
                        
                        # Build parameters for Windows script  
                        $windowsParams = @{}
                        if ($CheckOnly) { $windowsParams['CheckOnly'] = $true }
                        if ($WhatIf) { $windowsParams['WhatIf'] = $true }
                        if ($Verbose) { $windowsParams['Verbose'] = $true }
                        
                        Write-Info "Executing Windows environment setup script to handle WSL PowerShell setup..."
                        $result = & $scriptPath @windowsParams
                        $exitCode = $LASTEXITCODE
                    } else {
                        # PowerShell is available - proceed with Linux script
                        $scriptPath = Join-Path $PSScriptRoot "setup-environment-linux.ps1"
                        
                        if (-not (Test-Path $scriptPath)) {
                            throw "Linux setup script not found: $scriptPath"
                        }
                        
                        # Build parameters for Linux script
                        $linuxParams = @{}
                        if ($CheckOnly) { $linuxParams['CheckOnly'] = $true }
                        if ($WhatIf) { $linuxParams['WhatIf'] = $true }
                        if ($Verbose) { $linuxParams['Verbose'] = $true }
                        
                        # Add context information
                        if ($detectedContext.ExecutionEnvironment -eq "WSLNative") {
                            $linuxParams['WSLMode'] = $true
                        }
                        
                        Write-Info "Executing Linux environment setup script..."
                        $result = & $scriptPath @linuxParams
                        $exitCode = $LASTEXITCODE
                    }
                } else {
                    # LinuxNative - should have PowerShell or we proceed anyway
                    $scriptPath = Join-Path $PSScriptRoot "setup-environment-linux.ps1"
                    
                    if (-not (Test-Path $scriptPath)) {
                        throw "Linux setup script not found: $scriptPath"
                    }
                    
                    # Build parameters for Linux script
                    $linuxParams = @{}
                    if ($CheckOnly) { $linuxParams['CheckOnly'] = $true }
                    if ($WhatIf) { $linuxParams['WhatIf'] = $true }
                    if ($Verbose) { $linuxParams['Verbose'] = $true }
                    
                    Write-Info "Executing Linux environment setup script..."
                    $result = & $scriptPath @linuxParams
                    $exitCode = $LASTEXITCODE
                }
            }
            
            default {
                throw "Unsupported execution environment: $($detectedContext.ExecutionEnvironment)"
            }
        }
        
        # Process results
        $success = $false
        $errorMessage = ""
        
        if ($result -is [hashtable] -and $result.ContainsKey('Success')) {
            # Script returned a proper result object
            $success = $result.Success
            $errorMessage = if ($result.Message) { $result.Message } else { "Unknown error" }
        } elseif ($result -eq $true) {
            # Script returned simple boolean true
            $success = $true
        } elseif ($exitCode -eq 0) {
            # Script exited successfully but may not have returned a result
            $success = $true
        } else {
            # Script failed
            $success = $false
            $errorMessage = "Unknown error from $($setupStrategy.PrimaryScript)"
        }
        
        if ($success) {
            Write-Success "Environment setup completed successfully via $($setupStrategy.PrimaryScript)"
            
            return @{
                Success = $true
                Message = "Environment setup completed successfully"
                Details = @{
                    ExecutionContext = $detectedContext
                    SetupStrategy = $setupStrategy
                    ScriptPath = $scriptPath
                    Result = $result
                    ExitCode = $exitCode
                }
            }
        } else {
            Write-Error "Environment setup failed: $errorMessage"
            
            return @{
                Success = $false
                Message = "Environment setup failed: $errorMessage"
                Details = @{
                    ExecutionContext = $detectedContext
                    SetupStrategy = $setupStrategy
                    ScriptPath = $scriptPath
                    Result = $result
                    ExitCode = $exitCode
                }
            }
        }
        
    } catch {
        Write-Error "Environment setup router failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Router failed: $($_.Exception.Message)"
            Details = @{
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
        }
    }
}

function Test-EnvironmentSetupRequirements {
    <#
    .SYNOPSIS
    Tests if all requirements for environment setup are met
    
    .RETURNS
    PSCustomObject with test results
    #>
    
    $results = [PSCustomObject]@{
        CanProceed = $true
        Issues = @()
        Context = $null
        Recommendations = @()
    }
    
    try {
        # Get execution context
        $context = Get-ExecutionContext
        $results.Context = $context
        
        # Test requirements based on context
        switch ($context.ExecutionEnvironment) {
            "WindowsNative" {
                # Check if Windows setup script exists
                $windowsScript = Join-Path $PSScriptRoot "setup-environment-windows.ps1"
                if (-not (Test-Path $windowsScript)) {
                    $results.Issues += "Windows setup script not found: $windowsScript"
                    $results.CanProceed = $false
                }
                
                # Check PowerShell version
                if ($PSVersionTable.PSVersion.Major -lt 5) {
                    $results.Issues += "PowerShell 5.0 or higher required"
                    $results.CanProceed = $false
                }
                
                # WSL availability check (if not using NoWSL)
                if (-not $context.CanInvokeWSL) {
                    $results.Recommendations += "WSL not available - environment will be Windows-only unless WSL is installed"
                }
            }
            
            { $_ -in @("WSLNative", "LinuxNative") } {
                # Check if Linux setup script exists
                $linuxScript = Join-Path $PSScriptRoot "setup-environment-linux.ps1"
                if (-not (Test-Path $linuxScript)) {
                    $results.Issues += "Linux setup script not found: $linuxScript"
                    $results.CanProceed = $false
                }
                
                # Check bash availability for some operations
                if (-not (Test-Command "bash")) {
                    $results.Issues += "bash shell not available - some operations may fail"
                }
            }
            
            default {
                $results.Issues += "Unknown execution environment: $($context.ExecutionEnvironment)"
                $results.CanProceed = $false
            }
        }
        
    } catch {
        $results.Issues += "Error testing requirements: $($_.Exception.Message)"
        $results.CanProceed = $false
    }
    
    return $results
}

function Write-EnvironmentSetupHelp {
    <#
    .SYNOPSIS
    Displays help information about environment setup routing
    #>
    
    Write-Host ""
    Write-Host "=== PHASE 2 ENVIRONMENT SETUP ROUTER HELP ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This router intelligently detects your execution context and routes to the appropriate setup script:" -ForegroundColor White
    Write-Host ""
    Write-Host "Execution Contexts:" -ForegroundColor Yellow
    Write-Host "  • WindowsNative  - Running on Windows (routes to setup-environment-windows.ps1)" -ForegroundColor Gray
    Write-Host "  • WSLNative      - Running in WSL (routes to setup-environment-linux.ps1)" -ForegroundColor Gray  
    Write-Host "  • LinuxNative    - Running on Linux (routes to setup-environment-linux.ps1)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Setup Strategies:" -ForegroundColor Yellow
    Write-Host "  • Windows Only    - Sets up Windows development environment only" -ForegroundColor Gray
    Write-Host "  • Windows + WSL   - Sets up both Windows and WSL environments" -ForegroundColor Gray
    Write-Host "  • Linux Only      - Sets up Linux/WSL environment only" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -CheckOnly        - Validate setup without making changes" -ForegroundColor Gray
    Write-Host "  -WhatIf           - Show execution plan without running" -ForegroundColor Gray
    Write-Host "  -NoWSL            - Skip WSL setup on Windows (Windows-only mode)" -ForegroundColor Gray
    Write-Host "  -Verbose          - Show detailed execution context report" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\setup-environment-router.ps1                    # Auto-detect and setup" -ForegroundColor Gray
    Write-Host "  .\setup-environment-router.ps1 -WhatIf           # Show what would happen" -ForegroundColor Gray
    Write-Host "  .\setup-environment-router.ps1 -NoWSL            # Windows-only setup" -ForegroundColor Gray
    Write-Host "  .\setup-environment-router.ps1 -CheckOnly        # Validate current setup" -ForegroundColor Gray
    Write-Host "  .\setup-environment-router.ps1 -Verbose          # Show detailed context" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Check for help parameter
    if ($args -contains "-Help" -or $args -contains "-?" -or $args -contains "--help") {
        Write-EnvironmentSetupHelp
        exit 0
    }
    
    # Test requirements first
    $requirements = Test-EnvironmentSetupRequirements
    if (-not $requirements.CanProceed) {
        Write-Error "Cannot proceed with environment setup:"
        foreach ($issue in $requirements.Issues) {
            Write-Error "  • $issue"
        }
        exit 1
    }
    
    # Show recommendations if any
    if ($requirements.Recommendations.Count -gt 0) {
        Write-Host "Recommendations:" -ForegroundColor Yellow
        foreach ($rec in $requirements.Recommendations) {
            Write-Warning $rec
        }
        Write-Host ""
    }
    
    # Execute the router
    $result = Invoke-EnvironmentSetupRouter -CheckOnly:$CheckOnly -WhatIf:$WhatIf -NoWSL:$NoWSL -Verbose:$Verbose
    
    # Return the result object for parent scripts to process
    # Also set exit code for compatibility
    if ($result.Success) {
        $result  # Return the result object
        exit 0
    } else {
        Write-Error $result.Message
        $result  # Return the result object even on failure
        exit 1
    }
}

# Export functions for module usage
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        'Invoke-EnvironmentSetupRouter',
        'Test-EnvironmentSetupRequirements',
        'Write-EnvironmentSetupHelp'
    )
}
# strangeloop Bootstrap - Environment Setup Orchestrator
# Version: 3.0.0 - Simplified Platform Router

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
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Invoke-EnvironmentSetup {
    <#
    .SYNOPSIS
    Simple platform-specific environment setup orchestrator
    
    .DESCRIPTION
    Detects the platform and routes to the appropriate setup script:
    - Windows: setup-environment-windows.ps1 
    - Linux/WSL: setup-environment-linux.ps1
    #>
    param(
        [switch]$CheckOnly,
        [switch]$WhatIf,
        [switch]$NoWSL,
        [switch]$Verbose
    )
    
    try {
        Write-Step "Phase 2: Environment Setup (Platform Router)"
        
        $startTime = Get-Date
        $context = Get-ExecutionContext
        $currentPlatform = $context.ExecutionEnvironment
        
        Write-Info "Detected platform: $currentPlatform"
        
        # Determine target script based on platform
        $targetScript = ""
        $platformName = ""
        
        if ($currentPlatform -eq "WindowsNative") {
            $targetScript = Join-Path $PSScriptRoot "setup-environment-windows.ps1"
            $platformName = "Windows"
        }
        elseif ($currentPlatform -in @("WSLNative", "LinuxNative")) {
            $targetScript = Join-Path $PSScriptRoot "setup-environment-linux.ps1"
            $platformName = "Linux"
        }
        else {
            throw "Unsupported platform: $currentPlatform"
        }
        
        Write-Info "Target platform: $platformName"
        Write-Info "Target script: $(Split-Path $targetScript -Leaf)"
        
        # Verify target script exists
        if (-not (Test-Path $targetScript)) {
            throw "Platform setup script not found: $targetScript"
        }
        
        if ($WhatIf) {
            Write-Host ""
            Write-Host "=== ENVIRONMENT SETUP PLAN (WHAT-IF) ===" -ForegroundColor Yellow
            Write-Host "what if: Platform: $platformName" -ForegroundColor Yellow
            Write-Host "what if: Would execute: $(Split-Path $targetScript -Leaf)" -ForegroundColor Yellow
            Write-Host "what if: Parameters:" -ForegroundColor Yellow
            if ($CheckOnly) { Write-Host "what if:   - CheckOnly mode" -ForegroundColor Yellow }
            if ($NoWSL) { Write-Host "what if:   - NoWSL flag" -ForegroundColor Yellow }
            if ($Verbose) { Write-Host "what if:   - Verbose output" -ForegroundColor Yellow }
            Write-Host ""
            return @{
                Success = $true
                Message = "What-if completed for $platformName environment setup"
                Platform = $platformName
                TargetScript = $targetScript
            }
        }
        
        # Build parameters for platform script
        $scriptParams = @{}
        if ($CheckOnly) { $scriptParams['CheckOnly'] = $true }
        if ($WhatIf) { $scriptParams['WhatIf'] = $true }
        if ($Verbose) { $scriptParams['Verbose'] = $true }
        
        # Windows-specific parameters
        if ($platformName -eq "Windows") {
            if ($NoWSL) { $scriptParams['NoWSL'] = $true }
        }
        
        # Execute platform-specific setup
        Write-Info "Executing $platformName environment setup..."
        
        try {
            $result = & $targetScript @scriptParams
            
            if ($result -and $result.Success) {
                $endTime = Get-Date
                $duration = $endTime - $startTime
                
                Write-Success "Environment setup completed successfully"
                Write-Info "Total duration: $($duration.TotalSeconds.ToString('F1')) seconds"
                
                return @{
                    Success = $true
                    Message = "$platformName environment setup completed successfully"
                    Platform = $platformName
                    Duration = $duration.TotalSeconds
                    Details = $result.Details
                }
            } else {
                $errorMessage = if ($result -and $result.Message) { $result.Message } else { "Setup failed with unknown error" }
                Write-Error "Environment setup failed: $errorMessage"
                
                return @{
                    Success = $false
                    Message = "$platformName environment setup failed: $errorMessage"
                    Platform = $platformName
                    Details = if ($result) { $result.Details } else { @{} }
                }
            }
            
        } catch {
            Write-Error "Failed to execute platform setup script: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = "Failed to execute platform setup: $($_.Exception.Message)"
                Platform = $platformName
                Error = $_.Exception.Message
            }
        }
        
    } catch {
        Write-Error "Environment setup orchestration failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = "Orchestration failed: $($_.Exception.Message)"
            Error = $_.Exception.Message
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $result = Invoke-EnvironmentSetup -CheckOnly:$CheckOnly -WhatIf:$WhatIf -NoWSL:$NoWSL -Verbose:$Verbose
    
    if ($result.Success) {
        exit 0
    } else {
        Write-Error $result.Message
        exit 1
    }
}
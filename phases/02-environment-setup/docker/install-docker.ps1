# strangeloop Setup - Docker Installation Router
# Version: 2.0.0
# Routes to platform-specific Docker installation implementation with enhanced WSL handling

param(
    [switch]${check-only},
    [bool]$AutoStart = $true,
    [switch]${what-if},
    [switch]$WSLMode = $false,
    [switch]${requires-wsl} = $false
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

try {
    Write-Info "Docker Installation Router - analyzing execution context..."
    
    # Get detailed execution context
    $detectedContext = Get-ExecutionContext
    $currentPlatform = $detectedContext.ExecutionEnvironment
    
    Write-Info "Detected execution context: $currentPlatform"
    if ($WSLMode) {
        Write-Info "WSLMode override enabled - forcing Linux implementation"
    }
    if (${requires-wsl}) {
        Write-Info "WSL integration required for this setup"
    }
    
    # Determine routing strategy based on execution context and parameters
    $routingDecision = @{
        TargetScript = ""
        ExecutionMethod = ""
        Reasoning = ""
        WSLInvocation = $false
    }
    
    if ($currentPlatform -eq "WindowsNative") {
        if ($WSLMode) {
            # Windows host but need to setup WSL environment
            $routingDecision.TargetScript = Join-Path $PSScriptRoot "linux\install-docker-linux.ps1"
            $routingDecision.ExecutionMethod = "WSLTunnel"
            $routingDecision.Reasoning = "Windows host targeting WSL environment"
            $routingDecision.WSLInvocation = $true
        } else {
            # Standard Windows Docker Desktop installation
            $routingDecision.TargetScript = Join-Path $PSScriptRoot "windows\install-docker-windows.ps1"
            $routingDecision.ExecutionMethod = "Direct"
            $routingDecision.Reasoning = "Windows host, Windows Docker Desktop"
            $routingDecision.WSLInvocation = $false
        }
    }
    elseif ($currentPlatform -in @("WSLNative", "LinuxNative")) {
        # Linux/WSL environment - always use Linux implementation
        $routingDecision.TargetScript = Join-Path $PSScriptRoot "linux\install-docker-linux.ps1"
        $routingDecision.ExecutionMethod = "Direct"
        $routingDecision.Reasoning = "Linux/WSL environment, Docker Engine"
        $routingDecision.WSLInvocation = $false
    }
    else {
        throw "Unsupported execution context: $currentPlatform"
    }
    
    Write-Info "Routing decision: $($routingDecision.Reasoning)"
    Write-Info "Target script: $(Split-Path $routingDecision.TargetScript -Leaf)"
    Write-Info "Execution method: $($routingDecision.ExecutionMethod)"
    
    # Verify target script exists
    if (-not (Test-Path $routingDecision.TargetScript)) {
        throw "Target script not found: $($routingDecision.TargetScript)"
    }
    
    # Build parameters to forward
    $forwardParams = @{}
    if (${check-only}) { $forwardParams['check-only'] = $true }
    if (${what-if}) { $forwardParams['what-if'] = $true }
    if ($AutoStart) { $forwardParams['AutoStart'] = $AutoStart }
    
    # Add WSL-specific parameters
    if ($routingDecision.WSLInvocation -or $WSLMode -or ($currentPlatform -in @("WSLNative", "LinuxNative"))) {
        $forwardParams['WSLMode'] = $true
    }
    
    # Execute based on routing decision
    if ($routingDecision.ExecutionMethod -eq "WSLTunnel") {
        # Execute Linux script via WSL from Windows
        Write-Info "Executing Docker setup in WSL environment from Windows..."
        
        # Convert Windows path to WSL path for the script
        $windowsScriptPath = $routingDecision.TargetScript
        $wslScriptPath = $windowsScriptPath -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/' | ForEach-Object { $_.ToLower() }
        
        Write-Info "WSL script path: $wslScriptPath"
        
        # Build parameter string for WSL execution
        $paramString = ""
        foreach ($key in $forwardParams.Keys) {
            if ($forwardParams[$key] -is [bool] -and $forwardParams[$key]) {
                $paramString += " -$key"
            } elseif ($forwardParams[$key] -is [string]) {
                $paramString += " -$key '$($forwardParams[$key])'"
            }
        }
        
        # Execute in WSL
        $wslCommand = "pwsh '$wslScriptPath'$paramString"
        Write-Info "WSL command: $wslCommand"
        
        $result = & wsl -- bash -c $wslCommand
        $exitCode = $LASTEXITCODE
        
    } else {
        # Direct execution
        Write-Info "Executing: $(Split-Path $routingDecision.TargetScript -Leaf)"
        $result = & $routingDecision.TargetScript @forwardParams
        $exitCode = $LASTEXITCODE
    }
    
    # Return the result
    if ($exitCode -eq 0) {
        Write-Success "Docker installation routing completed successfully"
        exit 0
    } else {
        Write-Error "Docker installation failed with exit code: $exitCode"
        exit $exitCode
    }
    
} catch {
    Write-Error "Docker installation router failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}


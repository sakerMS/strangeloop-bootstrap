# strangeloop Setup - Poetry Installation Router
# Version: 2.0.0
# Routes to platform-specific Poetry installation implementation

param(
    [switch]${check-only},
    [switch]${what-if},
    [switch]$WSLMode = $false
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

try {
    Write-Info "Poetry Installation Router - detecting platform..."
    
    # Detect current platform
    $currentPlatform = Get-CurrentPlatform
    $platformIsWindows = $currentPlatform -eq "Windows"
    $platformIsWSL = $currentPlatform -eq "WSL" 
    $platformIsLinux = $currentPlatform -eq "Linux"
    
    Write-Info "Detected platform: $currentPlatform"
    
    # Override platform detection if WSLMode is explicitly set
    if ($WSLMode -and $platformIsWindows) {
        Write-Info "WSLMode override: routing to Linux implementation from Windows"
        $platformIsLinux = $true
        $platformIsWindows = $false
    }
    
    # Route to appropriate platform-specific script
    if ($platformIsWindows) {
        $targetScript = Join-Path $PSScriptRoot "windows\install-poetry-windows.ps1"
        Write-Info "Routing to Windows Poetry installation"
    } elseif ($platformIsWSL -or $platformIsLinux) {
        $targetScript = Join-Path $PSScriptRoot "linux\install-poetry-linux.ps1"
        Write-Info "Routing to Linux Poetry installation"
    } else {
        Write-Error "Unsupported platform: $currentPlatform"
        exit 1
    }
    
    # Verify target script exists
    if (-not (Test-Path $targetScript)) {
        Write-Error "Platform-specific script not found: $targetScript"
        exit 1
    }
    
    # Build parameters to forward
    $forwardParams = @{}
    if (${check-only}) { $forwardParams['check-only'] = $true }
    if (${what-if}) { $forwardParams['what-if'] = $true }
    
    # Forward WSLMode parameter when routing from Windows to Linux
    if ($WSLMode -or ($platformIsWindows -and ($platformIsWSL -or $platformIsLinux))) {
        $forwardParams['WSLMode'] = $true
    }
    
    # Execute platform-specific script
    Write-Info "Executing: $targetScript"
    $result = & $targetScript @forwardParams
    $exitCode = $LASTEXITCODE
    
    # Return the result
    if ($exitCode -eq 0) {
        Write-Success "Poetry installation routing completed successfully"
        exit 0
    } else {
        Write-Error "Poetry installation failed with exit code: $exitCode"
        exit $exitCode
    }
    
} catch {
    Write-Error "Poetry installation router failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

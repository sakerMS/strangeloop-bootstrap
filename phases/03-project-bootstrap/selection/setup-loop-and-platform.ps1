# strangeloop Setup - Enhanced Loop Selection and Target Platform Decision
# Version: 1.0.0
# Phase 3 Step 1: Loop Selection & Target Platform Decision
# Purpose: Select strangeloop template and determine target platform

param(
    [string]${loop-name},
    [switch]${what-if},
    [switch]${check-only},
    [switch]${no-wsl}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
$PhasesSharedPath = Join-Path $BootstrapRoot "phases\shared"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")
. (Join-Path $PhasesSharedPath "loop-functions.ps1")
. (Join-Path $LibPath "display\display-functions.ps1")

function Invoke-LoopSelectionAndPlatformDecision {
    param(
        [string]$ProvidedLoopName,
        [switch]${what-if},
        [switch]${check-only},
        [switch]${no-wsl}
    )
    
    Write-Step "Loop Selection and Target Platform Decision (Phase 3 Step 1)..."
    Write-Info "Selecting strangeloop template and determining target platform"
    
    # Use the consolidated discovery and selection function
    return Invoke-LoopDiscoveryAndSelection -ProvidedLoopName $ProvidedLoopName -WhatIf:${what-if} -NoWSL:${no-wsl}
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically
    $params = @{}
    if (${loop-name}) { $params['ProvidedLoopName'] = ${loop-name} }
    if (${what-if}) { $params['what-if'] = $true }
    if (${check-only}) { $params['check-only'] = $true }
    if (${no-wsl}) { $params['no-wsl'] = $true }
    
    $result = Invoke-LoopSelectionAndPlatformDecision @params
    
    return $result
}

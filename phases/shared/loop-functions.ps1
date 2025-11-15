# strangeloop Setup - Shared Loop Functions
# Version: 1.0.0

# Loop management and platform detection functions

function Get-AvailableLoops {
    <#
    .SYNOPSIS
        Returns an array of available loop names, optionally filtered by platform
    
    .DESCRIPTION
        Gets the list of available loop names from the known loops registry.
        Can filter loops based on current platform and NoWSL preference.
        
        Performance: Uses caching to avoid repeated CLI calls. First call may take 
        several seconds due to 'strangeloop library loops' command, subsequent 
        calls are fast (cached for 5 minutes).
    
    .PARAMETER FilterByPlatform
        Whether to filter loops based on current platform compatibility
    
    .PARAMETER NoWSL
        If true, only return Windows-compatible loops (excludes WSL-only loops)
    
    .PARAMETER CurrentPlatform
        Override the current platform detection (Windows or WSL)
    
    .RETURNS
        Array of loop names
    #>
    param(
        [switch]$FilterByPlatform,
        [switch]$NoWSL,
        [string]$CurrentPlatform
    )
    
    $knownLoops = Get-KnownLoops
    $allLoops = @($knownLoops.Keys | Sort-Object)
    
    # If no filtering requested, return all loops
    if (-not $FilterByPlatform) {
        return $allLoops
    }
    
    # Determine current platform if not provided
    if (-not $CurrentPlatform) {
        $CurrentPlatform = if (Get-Command "Get-CurrentPlatform" -ErrorAction SilentlyContinue) {
            Get-CurrentPlatform
        } else {
            "Windows"  # Default fallback
        }
    }
    
    $filteredLoops = @()
    
    foreach ($loopName in $allLoops) {
        $loopMetadata = $knownLoops[$loopName]
        $loopPlatform = $loopMetadata.Platform
        
        $shouldInclude = $false
        
        if ($CurrentPlatform -eq "WSL") {
            # In WSL, show WSL-compatible loops (WSL and Dual platform loops)
            $shouldInclude = ($loopPlatform -eq "WSL" -or $loopPlatform -eq "Dual")
        } elseif ($CurrentPlatform -eq "Windows") {
            if ($NoWSL) {
                # Windows with NoWSL: only show Windows-only loops
                $shouldInclude = ($loopPlatform -eq "Windows")
            } else {
                # Windows without NoWSL: show all compatible loops (Windows, WSL, and Dual)
                $shouldInclude = ($loopPlatform -eq "Windows" -or $loopPlatform -eq "WSL" -or $loopPlatform -eq "Dual")
            }
        }
        
        if ($shouldInclude) {
            $filteredLoops += $loopName
        }
    }
    
    return $filteredLoops
}

function Get-LoopMetadata {
    <#
    .SYNOPSIS
        Gets metadata for a specific loop
    
    .PARAMETER LoopName
        The name of the loop to get metadata for
    
    .RETURNS
        Hashtable with loop metadata (Platform, Description)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    $knownLoops = Get-KnownLoops
    if ($knownLoops.ContainsKey($LoopName)) {
        return $knownLoops[$LoopName]
    }
    
    return $null
}

# Global cache for loop discovery to avoid repeated CLI calls
$Global:LoopDiscoveryCache = $null
$Global:LoopDiscoveryCacheTimestamp = $null
$Global:LoopDiscoveryCacheExpiryMinutes = 5  # Cache for 5 minutes

function Get-KnownLoops {
    <#
    .SYNOPSIS
        Returns the registry of all known strangeloop loops with their platform requirements
    
    .DESCRIPTION
        Dynamically builds the registry from available loops and centralized platform configuration.
        This function discovers loops using 'strangeloop library loops' and determines their
        platform requirements from the centralized bootstrap_config.yaml.
        
        Uses caching to avoid repeated CLI calls and improve performance.
        
        Platform types:
        - WSL: Requires WSL environment only
        - Windows: Requires Windows environment only  
        - Dual: Supports both WSL and Windows environments
    #>
    
    # Check if we have a valid cache
    if ($Global:LoopDiscoveryCache -and $Global:LoopDiscoveryCacheTimestamp) {
        $cacheAge = (Get-Date) - $Global:LoopDiscoveryCacheTimestamp
        if ($cacheAge.TotalMinutes -lt $Global:LoopDiscoveryCacheExpiryMinutes) {
            Write-Verbose "Using cached loop discovery results (age: $([math]::Round($cacheAge.TotalMinutes, 1)) minutes)"
            return $Global:LoopDiscoveryCache
        }
    }
    
    Write-Verbose "Discovering loops from strangeloop CLI (cache miss or expired)..."
    $registry = @{}
    
    try {
        # Get available loops from strangeloop CLI
        $cliOutput = strangeloop library loops 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Check if this is a CLI prerequisites error
            if ($cliOutput -match "CLI prerequisites are out of date" -or $cliOutput -match "run.*strangeloop cli prereqs") {
                Write-Error "strangeloop CLI prerequisites are out of date"
                Write-Error "Please run: strangeloop cli prereqs"
                Write-Error "CLI Error: $cliOutput"
                throw "CLI prerequisites check failed - cannot discover loops without updated prerequisites"
            } else {
                # Other CLI errors - fallback to known loops
                Write-Warning "strangeloop CLI not available (exit code: $LASTEXITCODE), using fallback loop registry"
                Write-Warning "CLI Output: $cliOutput"
                return Get-FallbackKnownLoops
            }
        }
        
        $loopsList = $cliOutput
        
        if ($loopsList) {
            $lines = $loopsList -split "`n" | Where-Object { $_.Trim() -ne "" }
            
            foreach ($line in $lines) {
                $line = $line.Trim()
                
                # Skip ASCII art lines and empty lines
                if ($line -match '^[/_\\\s\(\)\-\.,`]*$' -or $line -eq "" -or $line.Length -lt 3) {
                    continue
                }
                
                # Parse loop line format: "loop-name    description"
                if ($line -match '^([a-zA-Z0-9\-_]+)\s+(.+)$') {
                    $loopName = $matches[1].Trim()
                    $originalDescription = $matches[2].Trim()
                    
                    # Get platform from centralized configuration if available
                    $platform = if (Get-Command "Get-PlatformForLoop" -ErrorAction SilentlyContinue) {
                        Get-PlatformForLoop -LoopName $loopName
                    } else {
                        Get-FallbackPlatform -LoopName $loopName
                    }
                    
                    $registry[$loopName] = @{
                        Platform = $platform
                        Description = $originalDescription
                    }
                }
            }
            
            # If we got some loops from CLI, enhance with any missing ones from fallback
            if ($registry.Count -gt 0) {
                $fallbackLoops = Get-FallbackKnownLoops
                foreach ($fallbackLoop in $fallbackLoops.Keys) {
                    if (-not $registry.ContainsKey($fallbackLoop)) {
                        $registry[$fallbackLoop] = $fallbackLoops[$fallbackLoop]
                        # Update platform from centralized config if available
                        if (Get-Command "Get-PlatformForLoop" -ErrorAction SilentlyContinue) {
                            $registry[$fallbackLoop].Platform = Get-PlatformForLoop -LoopName $fallbackLoop
                        }
                    }
                }
            }
        }
    }
    catch {
        # Re-throw CLI prerequisites errors, only fallback for other errors
        if ($_.Exception.Message -match "CLI prerequisites check failed") {
            throw
        } else {
            Write-Warning "Error discovering loops: $($_.Exception.Message). Using fallback registry."
            $registry = Get-FallbackKnownLoops
        }
    }
    
    # Cache the results if we got a valid registry
    if ($registry -and $registry.Count -gt 0) {
        $Global:LoopDiscoveryCache = $registry
        $Global:LoopDiscoveryCacheTimestamp = Get-Date
        Write-Verbose "Cached loop discovery results (found $($registry.Count) loops)"
    }
    
    return $registry
}

function Clear-LoopDiscoveryCache {
    <#
    .SYNOPSIS
        Clears the cached loop discovery results to force fresh CLI lookup.
    
    .DESCRIPTION
        This function is useful when you want to refresh the loop list without waiting
        for the cache to expire (e.g., after updating loop library or configuration).
    #>
    
    $Global:LoopDiscoveryCache = $null
    $Global:LoopDiscoveryCacheTimestamp = $null
    Write-Verbose "Loop discovery cache cleared"
}

function Get-FallbackPlatform {
    <#
    .SYNOPSIS
        Fallback platform detection when centralized configuration is not available
    
    .DESCRIPTION
        This function provides basic platform detection based on common naming patterns
        when the centralized configuration is not available. It uses heuristics rather
        than hardcoded lists to minimize maintenance overhead.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    # Use naming pattern heuristics for platform detection
    # Windows-specific patterns: framework, windows, ads-snr
    if ($LoopName -match '(framework|windows|ads-snr)') {
        return 'Windows'
    }
    # Linux/WSL-specific patterns: linux, fast-api, mcp-server
    elseif ($LoopName -match '(linux|fast-api|mcp-server|semantic-kernel|langgraph)') {
        return 'WSL'
    }
    # Default to WSL for unknown loops (most loops are WSL-based)
    else {
        return 'WSL'
    }
}

function Get-FallbackKnownLoops {
    <#
    .SYNOPSIS
        Fallback registry when strangeloop CLI is not available
    
    .DESCRIPTION
        Provides a minimal set of known loops for fallback purposes only.
        This should only be used when the strangeloop CLI is not available.
        Platform detection uses centralized configuration when possible.
        Only includes loops that actually exist in the strangeloop library.
    #>
    
    # Minimal set of actual loops for fallback - matches strangeloop CLI output
    $coreLoops = @{
        'asp-dotnet-framework-api' = 'ASP.NET Framework API'
        'ads-snr-basic' = 'AdsSnR basic service'
        'python-fast-api-linux' = 'FastAPI web application for Linux'
    }
    
    # Build registry using centralized platform detection
    $registry = @{}
    foreach ($loopName in $coreLoops.Keys) {
        # Use centralized config if available, otherwise pattern-based fallback
        $platform = if (Get-Command "Get-PlatformForLoop" -ErrorAction SilentlyContinue) {
            Get-PlatformForLoop -LoopName $loopName
        } else {
            Get-FallbackPlatform -LoopName $loopName
        }
        
        $registry[$loopName] = @{
            Platform = $platform
            Description = $coreLoops[$loopName]
        }
    }
    
    return $registry
}

function Get-LoopRequirements {
    <#
    .SYNOPSIS
        Gets platform requirements for a specific loop
    
    .PARAMETER LoopName
        The name of the loop to get requirements for
    
    .RETURNS
        Hashtable with Platform and Description properties, or $null if loop not found
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    $knownLoops = Get-KnownLoops
    if ($knownLoops.ContainsKey($LoopName)) {
        return $knownLoops[$LoopName]
    }
    
    return $null
}

function Test-LoopAndGetRequirements {
    <#
    .SYNOPSIS
        Validates a loop name and returns discovery-like results
    
    .PARAMETER LoopName
        The name of the loop to validate
    
    .RETURNS
        Hashtable with discovery results if valid, $null if invalid
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    $knownLoops = Get-KnownLoops
    
    if ($knownLoops.ContainsKey($LoopName)) {
        $requirements = $knownLoops[$LoopName]
        
        Write-Host "✓ Pre-validated loop: $LoopName" -ForegroundColor Green
        Write-Host "✓ Target platform: $($requirements.Platform)" -ForegroundColor Green
        
        return @{
            Success = $true
            SelectedLoop = $LoopName
            EnvironmentRequirements = @{
                SelectedLoop = $LoopName
                Platform = $requirements.Platform
            }
            AvailableLoops = @($knownLoops.Keys)
            SkippedDiscovery = $true
        }
    } else {
        Write-Error "Loop '$LoopName' not found in the known loops registry."
        Write-Host ""
        Write-Host "Available loops:" -ForegroundColor Yellow
        $knownLoops.Keys | Sort-Object | ForEach-Object { 
            $loop = $knownLoops[$_]
            Write-Host "  • $_ (Platform: $($loop.Platform)) - $($loop.Description)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\setup-strangeloop.ps1 -loop-name 'csharp-mcp-server'  # Use correct loop name" -ForegroundColor Gray
        Write-Host "  .\setup-strangeloop.ps1                                 # Interactive selection" -ForegroundColor Gray
        Write-Host "  .\setup-strangeloop.ps1 -help                           # Show all options" -ForegroundColor Gray
        Write-Host ""
        return $null
    }
}

function Get-LoopsByPlatform {
    <#
    .SYNOPSIS
        Gets loops grouped by platform
    
    .PARAMETER TargetPlatform
        Optional platform filter ('Windows' or 'WSL')
    
    .RETURNS
        Array of loop names for the specified platform, or hashtable grouped by platform
    #>
    param(
        [ValidateSet('Windows', 'WSL')]
        [string]$TargetPlatform
    )
    
    $knownLoops = Get-KnownLoops
    
    if ($TargetPlatform) {
        return $knownLoops.Keys | Where-Object { $knownLoops[$_].Platform -eq $TargetPlatform }
    } else {
        $platforms = @{
            'Windows' = @()
            'WSL' = @()
        }
        
        foreach ($loopName in $knownLoops.Keys) {
            $loop = $knownLoops[$loopName]
            $platforms[$loop.Platform] += $loopName
        }
        
        return $platforms
    }
}

function Test-PathPlatformCompatibility {
    <#
    .SYNOPSIS
        Tests if a project path is compatible with a loop's platform requirements
    
    .PARAMETER ProjectPath
        The project path to validate
    
    .PARAMETER LoopName
        The loop name to check compatibility for
    
    .RETURNS
        Hashtable with IsCompatible, SuggestedPath, and Platform properties
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    $requirements = Get-LoopRequirements -LoopName $LoopName
    if (-not $requirements) {
        throw "Unknown loop: $LoopName"
    }
    
    $isWindowsPath = $ProjectPath -match '^[A-Za-z]:\\'
    $isWSLPath = $ProjectPath.StartsWith('/') -or $ProjectPath.Contains('/home/')
    $requiresWSL = ($requirements.Platform -eq "WSL")
    $requiresWindows = ($requirements.Platform -eq "Windows")
    
    $result = @{
        IsCompatible = $true
        SuggestedPath = $ProjectPath
        Platform = $requirements.Platform
    }
    
    if ($requiresWSL -and $isWindowsPath) {
        # WSL loop with Windows path - suggest WSL path
        $projectName = Split-Path $ProjectPath -Leaf
        $result.IsCompatible = $false
        try {
            $wslUser = & wsl -- whoami 2>$null
            if ($wslUser) {
                $result.SuggestedPath = "/home/$($wslUser.Trim())/AdsSnR_Containers/services/$projectName"
            } else {
                $result.SuggestedPath = "/home/\$USER/AdsSnR_Containers/services/$projectName"
            }
        } catch {
            $result.SuggestedPath = "/home/\$USER/AdsSnR_Containers/services/$projectName"
        }
    } elseif ($requiresWindows -and $isWSLPath) {
        # Windows loop with WSL path - suggest Windows path
        $projectName = Split-Path $ProjectPath -Leaf
        $result.IsCompatible = $false
        $result.SuggestedPath = "Q:\src\AdsSnR_Containers\services\$projectName"
    }
    
    return $result
}

function Get-EnvironmentRequirements {
    <#
    .SYNOPSIS
        Gets environment requirements for a specific loop
    
    .DESCRIPTION
        Returns the platform requirements for a specified loop in a format 
        compatible with the discovery module results
    
    .PARAMETER LoopName
        The name of the loop to get environment requirements for
    
    .RETURNS
        Hashtable with Platform property, or throws error if loop not found
    
    .EXAMPLE
        Get-EnvironmentRequirements -LoopName 'python-mcp-server'
        Returns: @{ Platform = 'WSL' }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName
    )
    
    $requirements = Get-LoopRequirements -LoopName $LoopName
    if (-not $requirements) {
        throw "Unknown loop: $LoopName. Use Get-KnownLoops to see available loops."
    }
    
    return @{
        Platform = $requirements.Platform
    }
}

function Invoke-LoopDiscoveryAndSelection {
    <#
    .SYNOPSIS
        Performs complete loop discovery and selection workflow
    
    .PARAMETER ProvidedLoopName
        Optional pre-selected loop name
    
    .PARAMETER WhatIf
        Preview mode - shows what would be done without executing
    
    .PARAMETER NoWSL
        Skip WSL-specific configurations and filter loops for Windows-only compatibility
    
    .RETURNS
        Hashtable with Success, SelectedLoop, TargetPlatform, and other metadata
    
    .DESCRIPTION
        This is the main orchestrator function that combines loop discovery, selection,
        and target platform decision into a single workflow. It uses functions from the
        display-functions.ps1 and platform-functions.ps1 modules.
    #>
    param(
        [string]$ProvidedLoopName,
        [switch]$WhatIf,
        [switch]$NoWSL
    )
    
    if ($WhatIf) {
        Write-Host "what if: Would perform loop discovery and selection:" -ForegroundColor Yellow
        if ($NoWSL) {
            Write-Host "what if:   - Discover available strangeloop templates (Windows-only compatibility)" -ForegroundColor Yellow
        } else {
            Write-Host "what if:   - Discover available strangeloop templates (platform-filtered)" -ForegroundColor Yellow
        }
        Write-Host "what if:   - Present interactive loop selection (if no loop provided)" -ForegroundColor Yellow
        Write-Host "what if:   - Analyze platform requirements for selected loop" -ForegroundColor Yellow
        Write-Host "what if:   - Present platform choice options (Windows/WSL)" -ForegroundColor Yellow
        Write-Host "what if:   - Make final target platform decision" -ForegroundColor Yellow
        Write-Host "what if:   - Return structured selection results" -ForegroundColor Yellow
        return @{
            Success = $true
            SelectedLoop = "example-loop"
            TargetPlatform = "Windows"
            LoopMetadata = @{ Platform = "Both"; Description = "Example loop" }
        }
    }
    
    try {
        # The required display and platform functions should already be imported by the calling script
        # No need to import them again here
        
        # Discover available loops
        Write-Host ""
        Write-Host "🔍 Loop Discovery" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────" -ForegroundColor DarkCyan
        
        Write-Info "Discovering available strangeloop templates..."
        $availableLoops = Get-AvailableLoops -FilterByPlatform -NoWSL:$NoWSL
        
        if (-not $availableLoops -or $availableLoops.Count -eq 0) {
            Write-Error "No strangeloop templates found"
            return @{
                Success = $false
                Error = "No loops available"
                Phase = "Loop Discovery"
            }
        }
        
        Write-Success "Found $($availableLoops.Count) available templates"
        
        # Loop selection
        Write-Host ""
        Write-Host "🎯 Loop Selection" -ForegroundColor Cyan
        Write-Host "────────────────────────────────" -ForegroundColor DarkCyan
        
        $selectedLoop = $null
        $loopMetadata = $null
        
        if ($ProvidedLoopName) {
            Write-Info "Validating provided loop: $ProvidedLoopName"
            
            if ($availableLoops -contains $ProvidedLoopName) {
                $selectedLoop = $ProvidedLoopName
                $loopMetadata = Get-LoopMetadata -LoopName $selectedLoop
                Write-Success "Loop validated: $selectedLoop"
            } else {
                Write-Error "Invalid loop name: '$ProvidedLoopName'"
                Write-Info "Available loops: $($availableLoops -join ', ')"
                return @{
                    Success = $false
                    Error = "Invalid loop name provided"
                    AvailableLoops = $availableLoops
                }
            }
        } else {
            # Interactive loop selection
            Write-Info "Presenting interactive loop selection..."
            $selectedLoop = Show-InteractiveLoopSelection -AvailableLoops $availableLoops
            
            if (-not $selectedLoop) {
                Write-Warning "No loop selected by user"
                return @{
                    Success = $false
                    Error = "User cancelled loop selection"
                    AvailableLoops = $availableLoops
                }
            }
            
            $loopMetadata = Get-LoopMetadata -LoopName $selectedLoop
        }
        
        # Target Platform decision
        Write-Host ""
        Write-Host "🏗️ Target Platform Decision" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────" -ForegroundColor DarkCyan
        
        $platformRequirement = Get-PlatformForLoop -LoopName $selectedLoop
        $targetPlatform = $null
        
        Write-Info "Analyzing platform requirements for loop: $selectedLoop"
        Write-Info "Loop platform requirement: $platformRequirement"
        
        if ($platformRequirement -eq "Windows") {
            Write-Info "Loop requires Windows platform - no choice needed"
            $targetPlatform = "Windows"
        } elseif ($platformRequirement -eq "WSL") {
            Write-Info "Loop requires WSL platform - no choice needed"
            $targetPlatform = "WSL"
        } else {
            # Loop supports both platforms - let user choose
            Write-Info "Loop supports both platforms - presenting platform choice"
            
            $targetPlatform = Show-PlatformChoice
            
            if (-not $targetPlatform) {
                Write-Warning "No platform selected by user"
                return @{
                    Success = $false
                    Error = "User cancelled platform selection"
                    SelectedLoop = $selectedLoop
                    LoopMetadata = $loopMetadata
                }
            }
        }
        
        # Validate compatibility
        $isCompatible = Test-PlatformCompatibility -LoopName $selectedLoop -TargetPlatform $targetPlatform
        if (-not $isCompatible) {
            Write-Error "Platform incompatibility detected"
            return @{
                Success = $false
                Error = "Selected platform is not compatible with loop requirements"
                SelectedLoop = $selectedLoop
                TargetPlatform = $targetPlatform
                LoopMetadata = $loopMetadata
            }
        }
        
        # Success
        Write-Host ""
        Write-Host "🎯 Selection Complete:" -ForegroundColor Green
        Write-Host "═══════════════════════════════" -ForegroundColor Green
        Write-Host "  Selected Loop: $selectedLoop" -ForegroundColor White
        Write-Host "  Target Platform: $targetPlatform" -ForegroundColor White
        Write-Host "  Platform Requirement: $platformRequirement" -ForegroundColor Gray
        
        Write-Success "Loop discovery and selection completed successfully"
        
        return @{
            Success = $true
            SelectedLoop = $selectedLoop
            TargetPlatform = $targetPlatform
            PlatformRequirement = $platformRequirement
            LoopMetadata = $loopMetadata
            AvailableLoops = $availableLoops
            Phase = "Loop Discovery and Selection"
            Message = "Selected '$selectedLoop' for '$targetPlatform' platform"
        }
        
    } catch {
        Write-Error "Loop discovery and selection failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Phase = "Loop Discovery and Selection"
        }
    }
}

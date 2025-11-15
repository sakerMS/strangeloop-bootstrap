# Unified Platform Management Module
# Version: 3.0.0
# Purpose: Comprehensive platform detection, configuration, and cross-platform operations

# Global cache for platform configuration to avoid repeated YAML parsing
$Global:PlatformConfigCache = $null

#region Core Platform Detection

function Get-ExecutionContext {
    <#
    .SYNOPSIS
    Determines the exact execution context to eliminate Windows vs WSL confusion
    
    .DESCRIPTION
    Returns detailed information about where this script is running:
    - WindowsNative: Running in Windows PowerShell/pwsh
    - WSLFromWindows: Running in WSL but invoked from Windows
    - WSLNative: Running directly in WSL environment  
    - LinuxNative: Running on native Linux (not WSL)
    
    .RETURNS
    PSCustomObject with detailed execution context information
    #>
    
    $context = [PSCustomObject]@{
        ExecutionEnvironment = ""      # WindowsNative, WSLFromWindows, WSLNative, LinuxNative
        HostPlatform = ""              # Windows, Linux
        IsWSL = $false                 # True if any WSL involvement
        IsNativeLinux = $false         # True if native Linux (not WSL)
        CanInvokeWSL = $false          # True if can invoke WSL commands
        WSLDistribution = ""           # Name of WSL distribution if applicable
        RecommendedApproach = ""       # How to handle environment setup
        PlatformDetails = @{}          # Additional platform information
    }
    
    try {
        # Primary detection: Check if we're in WSL
        $inWSL = $false
        $wslDistribution = ""
        
        # Method 1: Check WSL environment variables
        if ($env:WSL_DISTRO_NAME) {
            $inWSL = $true
            $wslDistribution = $env:WSL_DISTRO_NAME
        }
        # Method 2: Check WSL_INTEROP
        elseif ($env:WSL_INTEROP) {
            $inWSL = $true
        }
        # Method 3: Check /proc/version for WSL signature
        elseif (Test-Path "/proc/version") {
            try {
                $procVersion = Get-Content "/proc/version" -ErrorAction SilentlyContinue
                if ($procVersion -match "Microsoft|WSL") {
                    $inWSL = $true
                    # Try to get distribution from os-release
                    if (Test-Path "/etc/os-release") {
                        $osRelease = Get-Content "/etc/os-release" -ErrorAction SilentlyContinue
                        $nameLine = $osRelease | Where-Object { $_ -match '^NAME=' } | Select-Object -First 1
                        if ($nameLine -match 'NAME="?([^"]*)"?') {
                            $wslDistribution = $matches[1]
                        }
                    }
                }
            } catch {
                # Error reading /proc/version, continue with other detection
            }
        }
        
        # Determine execution context
        if ($inWSL) {
            $context.IsWSL = $true
            $context.WSLDistribution = $wslDistribution
            $context.HostPlatform = "Linux"
            
            # Check if this WSL was invoked from Windows via wsl command
            if ($env:WSLENV -or $env:WSL_INTEROP) {
                $context.ExecutionEnvironment = "WSLNative"
                $context.RecommendedApproach = "LinuxScript"
            } else {
                $context.ExecutionEnvironment = "WSLNative"  
                $context.RecommendedApproach = "LinuxScript"
            }
        }
        # Check if we're on native Linux (not WSL)
        elseif ((Test-Path "/etc/os-release") -and (-not $inWSL)) {
            $context.ExecutionEnvironment = "LinuxNative"
            $context.HostPlatform = "Linux"
            $context.IsNativeLinux = $true
            $context.RecommendedApproach = "LinuxScript"
        }
        # Windows environment
        elseif ($env:OS -eq "Windows_NT" -or $IsWindows) {
            $context.ExecutionEnvironment = "WindowsNative"
            $context.HostPlatform = "Windows"
            
            # Check if WSL is available on this Windows system
            try {
                $null = & wsl --status 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $context.CanInvokeWSL = $true
                    $context.RecommendedApproach = "WindowsScriptWithWSL"
                } else {
                    $context.RecommendedApproach = "WindowsScriptOnly"
                }
            } catch {
                $context.RecommendedApproach = "WindowsScriptOnly"
            }
        }
        else {
            $context.ExecutionEnvironment = "Unknown"
            $context.HostPlatform = "Unknown"
            $context.RecommendedApproach = "Fallback"
        }
        
        # Get additional platform details
        $context.PlatformDetails = Get-DetailedPlatformInfo -ContextInfo $context
        
        return $context
        
    } catch {
        throw "Failed to determine execution context: $($_.Exception.Message)"
    }
}

function Get-CurrentPlatform {
    <#
    .SYNOPSIS
    Simple platform detection - returns Windows or WSL
    
    .DESCRIPTION
    Simplified version that returns just "Windows" or "WSL" for basic platform decisions.
    For detailed context, use Get-ExecutionContext instead.
    
    .RETURNS
    String: "Windows" or "WSL" based on current environment
    #>
    
    # Check for WSL environment variables
    if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) {
        return "WSL"
    }
    
    # Check if we're running in WSL by examining the kernel
    if (Test-Path "/proc/version") {
        try {
            $version = Get-Content "/proc/version" -ErrorAction SilentlyContinue
            if ($version -match "Microsoft|WSL") {
                return "WSL"
            }
        }
        catch {
            # Ignore errors reading /proc/version
        }
    }
    
    # If we can't detect WSL, assume Windows
    return "Windows"
}

function Get-DetailedPlatformInfo {
    <#
    .SYNOPSIS
    Gets detailed platform information based on execution context
    
    .PARAMETER ContextInfo
    The execution context object from Get-ExecutionContext
    
    .RETURNS
    Hashtable with detailed platform information
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ContextInfo
    )
    
    $details = @{
        OSName = ""
        OSVersion = ""
        Architecture = ""
        KernelVersion = ""
        Available = @{
            WSL = $false
            Docker = $false
            Git = $false
            Python = $false
            Poetry = $false
        }
    }
    
    try {
        switch ($ContextInfo.ExecutionEnvironment) {
            "WindowsNative" {
                # Windows-specific details
                try {
                    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                    if ($osInfo) {
                        $details.OSName = $osInfo.Caption
                        $details.OSVersion = "Build $($osInfo.BuildNumber)"
                        $details.Architecture = $osInfo.OSArchitecture
                    }
                } catch {
                    $details.OSName = "Windows"
                    $details.OSVersion = [System.Environment]::OSVersion.VersionString
                    $details.Architecture = $env:PROCESSOR_ARCHITECTURE
                }
                
                # Check tool availability on Windows
                $details.Available.WSL = Test-Command "wsl"
                $details.Available.Docker = Test-Command "docker"
                $details.Available.Git = Test-Command "git"
                $details.Available.Python = Test-Command "python"
                $details.Available.Poetry = Test-Command "poetry"
            }
            
            { $_ -in @("WSLNative", "WSLFromWindows", "LinuxNative") } {
                # Linux/WSL-specific details
                if (Test-Path "/etc/os-release") {
                    try {
                        $osReleaseContent = Get-Content "/etc/os-release" -ErrorAction SilentlyContinue
                        $osRelease = @{}
                        foreach ($line in $osReleaseContent) {
                            if ($line -match '^([^=]+)=(.*)$') {
                                $key = $matches[1]
                                $value = $matches[2] -replace '^"(.*)"$', '$1'  # Remove quotes
                                $osRelease[$key] = $value
                            }
                        }
                        $details.OSName = $osRelease['NAME']
                        $details.OSVersion = $osRelease['VERSION']
                    } catch {
                        $details.OSName = "Linux"
                        $details.OSVersion = "Unknown"
                    }
                }
                
                # Get architecture
                try {
                    $details.Architecture = & uname -m 2>/dev/null
                } catch {
                    $details.Architecture = "Unknown"
                }
                
                # Get kernel version
                try {
                    $details.KernelVersion = & uname -r 2>/dev/null
                } catch {
                    $details.KernelVersion = "Unknown"
                }
                
                # Check tool availability on Linux
                $details.Available.Docker = Test-Command "docker"
                $details.Available.Git = Test-Command "git"
                $details.Available.Python = (Test-Command "python3") -or (Test-Command "python")
                $details.Available.Poetry = Test-Command "poetry"
            }
        }
        
    } catch {
        Write-Warning "Error getting detailed platform info: $($_.Exception.Message)"
    }
    
    return $details
}

function Test-Command {
    <#
    .SYNOPSIS
    Tests if a command is available in the current environment
    
    .PARAMETER CommandName
    Name of the command to test
    
    .RETURNS
    Boolean indicating if command is available
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )
    
    try {
        $null = Get-Command $CommandName -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-WSLAvailable {
    <#
    .SYNOPSIS
    Tests if WSL is available on the current Windows system.
    
    .RETURNS
    Boolean: $true if WSL is available, $false otherwise
    #>
    
    try {
        # Try to run a simple WSL command
        & wsl --status 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

#endregion

#region Configuration-Based Platform Management

function Get-PlatformForLoop {
    <#
    .SYNOPSIS
    Determines the appropriate platform (Windows or WSL) for a given loop name.
    
    .PARAMETER LoopName
    The name of the loop to check platform requirements for.
    
    .RETURNS
    String: "Windows" or "WSL" based on configuration
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LoopName
    )

    try {
        # Use cached configuration if available
        if (-not $Global:PlatformConfigCache) {
            $Global:PlatformConfigCache = Initialize-PlatformConfig
        }
        
        # Determine platform based on loop category
        if ($Global:PlatformConfigCache.WindowsLoops -contains $LoopName) {
            return "Windows"
        }
        elseif ($Global:PlatformConfigCache.WSLLoops -contains $LoopName) {
            return "WSL"
        }
        elseif ($Global:PlatformConfigCache.DualLoops -contains $LoopName) {
            # For dual-platform loops, detect current environment
            return Get-CurrentPlatform
        }
        
        # Default to WSL if not found in any category
        return "WSL"
    }
    catch {
        Write-Warning "Error reading platform configuration: $($_.Exception.Message). Defaulting to WSL."
        return "WSL"
    }
}

function Initialize-PlatformConfig {
    <#
    .SYNOPSIS
    Initializes and caches the platform configuration from YAML file.
    
    .RETURNS
    Hashtable with WindowsLoops, WSLLoops, and DualLoops arrays
    #>
    
    try {
        # Load platform configuration from YAML
        # Find the bootstrap root directory by looking for the config directory
        $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $bootstrapRoot = $currentPath
        
        # Navigate up to find the bootstrap root (where config directory exists)
        while ($bootstrapRoot -and -not (Test-Path (Join-Path $bootstrapRoot "config\bootstrap_config.yaml"))) {
            $parent = Split-Path $bootstrapRoot
            if ($parent -eq $bootstrapRoot) { break }  # Reached filesystem root
            $bootstrapRoot = $parent
        }
        
        $configPath = Join-Path $bootstrapRoot "config\bootstrap_config.yaml"
        if (-not (Test-Path $configPath)) {
            Write-Warning "Bootstrap config file not found at $configPath, using fallback configuration"
            return @{
                WindowsLoops = @('asp-dotnet-framework-api', 'ads-snr-basic')
                WSLLoops = @('python-fast-api-linux', 'python-mcp-server', 'python-semantic-kernel-agent', 'langgraph-agent', 'csharp-mcp-server', 'csharp-semantic-kernel-agent', 'csharp-dotnet-aspire', 'falcon-linux-byo-app')
                DualLoops = @()
            }
        }
        
        # Read YAML content and extract platform configuration  
        $yamlContent = Get-Content $configPath -Raw
        
        # Define the platform categories with their associated loops
        $windowsLoops = @()
        $wslLoops = @()
        $dualLoops = @()
        
        # Extract windows_loops section
        if ($yamlContent -match '(?s)windows_loops:\s*\n((?:\s*-\s*[^\n]*\n)*)')  {
            $windowsSection = $matches[1]
            $windowsLoops = $windowsSection -split '\n' | Where-Object { $_ -match '^\s*-\s*"?([^"]+)"?' } | ForEach-Object { 
                if ($_ -match '^\s*-\s*"?([^"]+)"?') { $matches[1].Trim() }
            }
        }
        
        # Extract wsl_preferred_loops section  
        if ($yamlContent -match '(?s)wsl_preferred_loops:\s*\n((?:\s*-\s*[^\n]*\n)*)')  {
            $wslSection = $matches[1]
            $wslLoops = $wslSection -split '\n' | Where-Object { $_ -match '^\s*-\s*"?([^"]+)"?' } | ForEach-Object { 
                if ($_ -match '^\s*-\s*"?([^"]+)"?') { $matches[1].Trim() }
            }
        }
        
        # Extract dual_platform_loops section
        if ($yamlContent -match '(?s)dual_platform_loops:\s*\n((?:\s*-\s*[^\n]*\n)*)')  {
            $dualSection = $matches[1]
            $dualLoops = $dualSection -split '\n' | Where-Object { $_ -match '^\s*-\s*"?([^"]+)"?' } | ForEach-Object { 
                if ($_ -match '^\s*-\s*"?([^"]+)"?') { $matches[1].Trim() }
            }
        }
        
        return @{
            WindowsLoops = $windowsLoops
            WSLLoops = $wslLoops
            DualLoops = $dualLoops
        }
    }
    catch {
        Write-Warning "Error reading platform configuration: $($_.Exception.Message). Using fallback configuration."
        return @{
            WindowsLoops = @('asp-dotnet-framework-api', 'ads-snr-basic')
            WSLLoops = @('python-fast-api-linux', 'python-mcp-server', 'python-semantic-kernel-agent', 'langgraph-agent', 'csharp-mcp-server', 'csharp-semantic-kernel-agent', 'csharp-dotnet-aspire', 'falcon-linux-byo-app')
            DualLoops = @()
        }
    }
}

function Clear-PlatformConfigCache {
    <#
    .SYNOPSIS
    Clears the cached platform configuration to force reload from YAML file.
    
    .DESCRIPTION
    This function is useful when the bootstrap_config.yaml file has been updated
    and you want to reload the configuration without restarting the session.
    #>
    
    $Global:PlatformConfigCache = $null
    Write-Verbose "Platform configuration cache cleared"
}

function Get-PlatformDefaultPath {
    <#
    .SYNOPSIS
    Gets the default project path for a given platform.
    
    .PARAMETER Platform
    The platform ("Windows" or "WSL") to get the default path for.
    
    .RETURNS
    String: The default project path for the platform
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Windows", "WSL")]
        [string]$Platform
    )
    
    try {
        # Find the bootstrap root directory by looking for the config directory
        $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $bootstrapRoot = $currentPath
        
        # Navigate up to find the bootstrap root (where config directory exists)
        while ($bootstrapRoot -and -not (Test-Path (Join-Path $bootstrapRoot "config\bootstrap_config.yaml"))) {
            $parent = Split-Path $bootstrapRoot
            if ($parent -eq $bootstrapRoot) { break }  # Reached filesystem root
            $bootstrapRoot = $parent
        }
        
        $configPath = Join-Path $bootstrapRoot "config\bootstrap_config.yaml"
        if (-not (Test-Path $configPath)) {
            # Fallback defaults
            if ($Platform -eq "Windows") {
                return "Q:\src\AdsSnR_Containers\services"
            }
            else {
                return "/home/$env:USERNAME/AdsSnR_Containers/services"
            }
        }
        
        $yamlContent = Get-Content $configPath -Raw
        
        # Extract default_paths section using regex
        if ($yamlContent -match '(?s)default_paths:\s*\n((?:\s*\w+:.*\n)*)') {
            $defaultPathsSection = $matches[1]
            
            if ($Platform -eq "Windows") {
                if ($defaultPathsSection -match 'windows:\s*"?([^"\n]+)"?') {
                    return $matches[1].Trim()
                }
            }
            elseif ($Platform -eq "WSL") {
                if ($defaultPathsSection -match 'wsl:\s*"?([^"\n]+)"?') {
                    $wslPath = $matches[1].Trim()
                    # Expand environment variables in WSL path
                    if ($wslPath -match '\$USER') {
                        $user = $env:USER
                        if (-not $user) {
                            $user = $env:USERNAME
                        }
                        $wslPath = $wslPath -replace '\$USER', $user
                    }
                    return $wslPath
                }
            }
        }
        
        # Fallback defaults if parsing failed
        if ($Platform -eq "Windows") {
            return "Q:\src\AdsSnR_Containers\services"
        }
        else {
            return "/home/$env:USERNAME/AdsSnR_Containers/services"
        }
        
    } catch {
        Write-Warning "Error reading platform configuration: $($_.Exception.Message). Using fallback defaults."
        
        if ($Platform -eq "Windows") {
            return "Q:\src\AdsSnR_Containers\services"
        }
        else {
            return "/home/$env:USERNAME/AdsSnR_Containers/services"
        }
    }
}

function Test-PathPlatform {
    <#
    .SYNOPSIS
    Determines platform type based on path patterns.
    
    .PARAMETER Path
    The path to analyze.
    
    .RETURNS
    String: "Windows", "WSL", or "Unknown"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        # Find the bootstrap root directory by looking for the config directory
        $currentPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        $bootstrapRoot = $currentPath
        
        # Navigate up to find the bootstrap root (where config directory exists)
        while ($bootstrapRoot -and -not (Test-Path (Join-Path $bootstrapRoot "config\bootstrap_config.yaml"))) {
            $parent = Split-Path $bootstrapRoot
            if ($parent -eq $bootstrapRoot) { break }  # Reached filesystem root
            $bootstrapRoot = $parent
        }
        
        $configPath = Join-Path $bootstrapRoot "config\bootstrap_config.yaml"
        if (-not (Test-Path $configPath)) {
            return "Unknown"
        }
        
        $yamlContent = Get-Content $configPath -Raw
        
        # Extract path_patterns section using regex
        if ($yamlContent -match '(?s)path_patterns:\s*\n((?:\s*\w+_indicators:.*\n(?:\s*-.*\n)*)*)')  {
            $pathPatternsSection = $matches[1]
            
            # Check WSL indicators
            if ($pathPatternsSection -match '(?s)wsl_indicators:\s*\n((?:\s*-\s*"?[^"\n]+"?\s*\n)*)') {
                $wslIndicators = $matches[1]
                $wslPatterns = $wslIndicators -split '\n' | Where-Object { $_ -match '^\s*-\s*"?([^"]+)"?' } | ForEach-Object { 
                    if ($_ -match '^\s*-\s*"?([^"]+)"?') { $matches[1].Trim() }
                }
                
                foreach ($pattern in $wslPatterns) {
                    if ($Path -match $pattern) {
                        return "WSL"
                    }
                }
            }
            
            # Check Windows indicators
            if ($pathPatternsSection -match '(?s)windows_indicators:\s*\n((?:\s*-\s*"?[^"\n]+"?\s*\n)*)') {
                $windowsIndicators = $matches[1]
                $windowsPatterns = $windowsIndicators -split '\n' | Where-Object { $_ -match '^\s*-\s*"?([^"]+)"?' } | ForEach-Object { 
                    if ($_ -match '^\s*-\s*"?([^"]+)"?') { $matches[1].Trim() }
                }
                
                foreach ($pattern in $windowsPatterns) {
                    if ($Path -match $pattern) {
                        return "Windows"
                    }
                }
            }
        }
        
        return "Unknown"
        
    } catch {
        Write-Warning "Error reading path patterns: $($_.Exception.Message)"
        return "Unknown"
    }
}

function Test-PlatformCompatibility {
    <#
    .SYNOPSIS
        Tests if the selected platform is compatible with the loop requirements
    
    .PARAMETER LoopName
        The name of the loop to check
    
    .PARAMETER TargetPlatform
        The target platform to validate ('Windows' or 'WSL')
    
    .RETURNS
        $true if compatible, $false if not
    
    .DESCRIPTION
        This function validates that the selected platform can run the specified loop.
        It uses the centralized platform configuration to determine compatibility.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$LoopName,
        
        [Parameter(Mandatory)]
        [string]$TargetPlatform
    )
    
    try {
        $platformRequirement = Get-PlatformForLoop -LoopName $LoopName
        
        # Check compatibility
        switch ($platformRequirement) {
            "Windows" { return $TargetPlatform -eq "Windows" }
            "WSL" { return $TargetPlatform -eq "WSL" }
            default { return $true }  # Both platforms supported
        }
    }
    catch {
        Write-Warning "Could not determine platform compatibility for loop '$LoopName': $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Advanced Platform Operations

function Get-WSLDistributions {
    <#
    .SYNOPSIS
    Gets list of available WSL distributions from Windows
    
    .RETURNS
    Array of WSL distribution information
    #>
    
    $distributions = @()
    
    try {
        if (Test-Command "wsl") {
            $wslList = & wsl --list --verbose 2>$null
            if (($LASTEXITCODE -eq 0) -and $wslList) {
                $lines = $wslList -split "`n" | Where-Object { $_ -match '\S' }
                
                foreach ($line in $lines) {
                    # Skip header line
                    if ($line -match "NAME|----") { continue }
                    
                    # Parse distribution info
                    if ($line -match '^\s*(\*?)\s*(\S+)\s+(\S+)\s+(\d+)') {
                        $distributions += [PSCustomObject]@{
                            Name = $matches[2]
                            State = $matches[3]
                            Version = $matches[4]
                            IsDefault = $matches[1] -eq "*"
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error getting WSL distributions: $($_.Exception.Message)"
    }
    
    return $distributions
}

function Get-RecommendedSetupStrategy {
    <#
    .SYNOPSIS
    Determines the recommended setup strategy based on execution context and user preferences
    
    .PARAMETER NoWSL
    Flag indicating WSL should be skipped
    
    .RETURNS
    PSCustomObject with recommended strategy details
    #>
    param(
        [switch]$NoWSL
    )
    
    $context = Get-ExecutionContext
    
    $strategy = [PSCustomObject]@{
        PrimaryScript = ""           # Which main script to run
        WSLInvocation = $false       # Whether WSL invocation is needed
        SetupScope = ""              # WindowsOnly, LinuxOnly, or Both
        ExecutionSteps = @()         # Ordered list of execution steps
        Warnings = @()               # Any warnings or considerations
    }
    
    switch ($context.ExecutionEnvironment) {
        "WindowsNative" {
            if ($NoWSL) {
                $strategy.PrimaryScript = "setup-environment-windows.ps1"
                $strategy.SetupScope = "WindowsOnly"
                $strategy.ExecutionSteps = @(
                    "Run Windows environment setup script",
                    "Install Windows development tools",
                    "Configure Windows-only environment"
                )
            } else {
                $strategy.PrimaryScript = "setup-environment-windows.ps1"
                $strategy.WSLInvocation = $true
                $strategy.SetupScope = "Both"
                $strategy.ExecutionSteps = @(
                    "Run Windows environment setup script",
                    "Install Windows development tools",
                    "Install and configure WSL",
                    "Invoke Linux setup script in WSL using dynamically resolved path",
                    "Verify both environments"
                )
                
                if (-not $context.CanInvokeWSL) {
                    $strategy.Warnings += "WSL not available - will install WSL first"
                }
            }
        }
        
        { $_ -in @("WSLNative", "LinuxNative") } {
            $strategy.PrimaryScript = "setup-environment-linux.ps1"
            $strategy.SetupScope = "LinuxOnly"
            $strategy.ExecutionSteps = @(
                "Run Linux environment setup script",
                "Install Linux development tools",
                "Configure Linux/WSL environment"
            )
            
            if ($context.ExecutionEnvironment -eq "WSLNative") {
                $strategy.Warnings += "Running in WSL - Docker will connect to Windows Docker Desktop if available"
            }
        }
        
        default {
            $strategy.Warnings += "Unknown execution environment - using fallback strategy"
            $strategy.PrimaryScript = "setup-environment-router.ps1"
            $strategy.SetupScope = "Auto"
        }
    }
    
    return $strategy
}

function Invoke-CrossPlatformCommand {
    <#
    .SYNOPSIS
    Executes a command with cross-platform awareness, handling WSL context intelligently
    
    .DESCRIPTION
    This function determines whether to execute a command directly or via WSL based on:
    - Current execution environment (whether already in WSL)
    - Target path platform (Windows vs Linux/WSL paths)
    - Command requirements
    
    .PARAMETER Command
    The command to execute (e.g., "git status", "test -d /path")
    
    .PARAMETER WorkingDirectory
    Optional working directory for the command
    
    .PARAMETER UseWSLPaths
    Force interpretation of paths as WSL paths
    
    .RETURNS
    Object with Success, Output, ExitCode, and Error properties
    
    .EXAMPLE
    Invoke-CrossPlatformCommand -Command "git status" -WorkingDirectory "/home/user/repo"
    
    .EXAMPLE
    Invoke-CrossPlatformCommand -Command "test -d /home/user" -UseWSLPaths
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [string]$WorkingDirectory,
        
        [switch]$UseWSLPaths
    )
    
    try {
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        # Determine if we need WSL execution based on context
        $needsWSL = $false
        if (-not $isRunningInWSL) {
            # Running on Windows - check if we need WSL
            if ($UseWSLPaths) {
                $needsWSL = $true
            } elseif ($WorkingDirectory -and ($WorkingDirectory.StartsWith('/') -or $WorkingDirectory.Contains('/home/'))) {
                $needsWSL = $true
            }
        }
        
        $result = @{
            Success = $false
            Output = $null
            ExitCode = -1
            Error = $null
        }
        
        if ($needsWSL) {
            # Execute via WSL from Windows
            $wslCommand = if ($WorkingDirectory) {
                "cd '$WorkingDirectory' && $Command"
            } else {
                $Command
            }
            
            $output = & wsl -- bash -c $wslCommand 2>&1
            $exitCode = $LASTEXITCODE
            
            $result.Output = $output
            $result.ExitCode = $exitCode
            $result.Success = ($exitCode -eq 0)
            
        } else {
            # Execute directly (either in WSL or Windows native)
            if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
                Push-Location $WorkingDirectory
                try {
                    $output = Invoke-Expression $Command 2>&1
                    $exitCode = $LASTEXITCODE
                } finally {
                    Pop-Location
                }
            } else {
                $output = Invoke-Expression $Command 2>&1
                $exitCode = $LASTEXITCODE
            }
            
            $result.Output = $output
            $result.ExitCode = $exitCode
            $result.Success = ($exitCode -eq 0)
        }
        
        return $result
        
    } catch {
        return @{
            Success = $false
            Output = $null
            ExitCode = -1
            Error = $_.Exception.Message
        }
    }
}

#endregion

#region Reporting and Utilities

function Write-ExecutionContextReport {
    <#
    .SYNOPSIS
    Displays a detailed report of the current execution context
    
    .PARAMETER Context
    The execution context object (optional - will detect if not provided)
    #>
    param(
        [PSCustomObject]$Context
    )
    
    if (-not $Context) {
        $Context = Get-ExecutionContext
    }
    
    Write-Host ""
    Write-Host "=== EXECUTION CONTEXT REPORT ===" -ForegroundColor Cyan
    Write-Host "Execution Environment: " -NoNewline
    Write-Host $Context.ExecutionEnvironment -ForegroundColor Yellow
    Write-Host "Host Platform: " -NoNewline  
    Write-Host $Context.HostPlatform -ForegroundColor Yellow
    Write-Host "Is WSL: " -NoNewline
    Write-Host $Context.IsWSL -ForegroundColor $(if ($Context.IsWSL) { "Green" } else { "Gray" })
    Write-Host "Can Invoke WSL: " -NoNewline
    Write-Host $Context.CanInvokeWSL -ForegroundColor $(if ($Context.CanInvokeWSL) { "Green" } else { "Gray" })
    
    if ($Context.WSLDistribution) {
        Write-Host "WSL Distribution: " -NoNewline
        Write-Host $Context.WSLDistribution -ForegroundColor Yellow
    }
    
    Write-Host "Recommended Approach: " -NoNewline
    Write-Host $Context.RecommendedApproach -ForegroundColor Green
    
    # Platform details
    $details = $Context.PlatformDetails
    if ($details.OSName) {
        Write-Host ""
        Write-Host "Platform Details:" -ForegroundColor Cyan
        Write-Host "  OS: $($details.OSName) $($details.OSVersion)"
        Write-Host "  Architecture: $($details.Architecture)"
        if ($details.KernelVersion) {
            Write-Host "  Kernel: $($details.KernelVersion)"
        }
    }
    
    # Tool availability
    Write-Host ""
    Write-Host "Tool Availability:" -ForegroundColor Cyan
    foreach ($tool in $details.Available.Keys) {
        $available = $details.Available[$tool]
        $status = if ($available) { "✓" } else { "✗" }
        $color = if ($available) { "Green" } else { "Red" }
        Write-Host "  $tool`: " -NoNewline
        Write-Host $status -ForegroundColor $color
    }
    
    Write-Host ""
}

function Get-PlatformDetails {
    <#
    .SYNOPSIS
    Gets detailed platform information including OS version, architecture, and WSL details.
    (Simplified version - for comprehensive details use Get-ExecutionContext)
    
    .RETURNS
    PSCustomObject: Basic platform information
    #>
    
    try {
        $platformInfo = [PSCustomObject]@{
            Name = ""
            Version = ""
            Architecture = ""
            IsWSL = $false
            WSLDistribution = ""
        }
        
        # Detect if we're in WSL
        $isWSL = $false
        $wslDistro = ""
        
        if ($env:WSL_DISTRO_NAME) {
            $isWSL = $true
            $wslDistro = $env:WSL_DISTRO_NAME
        } elseif ($env:WSL_INTEROP -or (Test-Path "/proc/version")) {
            try {
                $version = Get-Content "/proc/version" -ErrorAction SilentlyContinue
                if ($version -match "Microsoft|WSL") {
                    $isWSL = $true
                    # Try to get distribution name from os-release
                    if (Test-Path "/etc/os-release") {
                        $osReleaseContent = Get-Content "/etc/os-release" -ErrorAction SilentlyContinue
                        foreach ($line in $osReleaseContent) {
                            if ($line -match '^NAME="?([^"]*)"?$') {
                                $wslDistro = $matches[1]
                                break
                            }
                        }
                    }
                }
            } catch {
                # Ignore errors
            }
        }
        
        if ($isWSL) {
            # WSL environment
            $platformInfo.Name = "WSL"
            $platformInfo.IsWSL = $true
            $platformInfo.WSLDistribution = $wslDistro
            
            # Get Linux distribution info
            if (Test-Path "/etc/os-release") {
                try {
                    $osReleaseContent = Get-Content "/etc/os-release" -ErrorAction SilentlyContinue
                    $osRelease = @{}
                    foreach ($line in $osReleaseContent) {
                        if ($line -match '^([^=]+)=(.*)$') {
                            $key = $matches[1]
                            $value = $matches[2] -replace '^"(.*)"$', '$1'  # Remove quotes
                            $osRelease[$key] = $value
                        }
                    }
                    
                    if ($osRelease.ContainsKey('VERSION')) {
                        $platformInfo.Version = $osRelease['VERSION']
                    } elseif ($osRelease.ContainsKey('VERSION_ID')) {
                        $platformInfo.Version = $osRelease['VERSION_ID']
                    } else {
                        $platformInfo.Version = "Unknown"
                    }
                } catch {
                    $platformInfo.Version = "Unknown"
                }
            } else {
                $platformInfo.Version = "Unknown"
            }
            
            # Get architecture 
            try {
                $arch = uname -m 2>/dev/null
                $platformInfo.Architecture = $arch
            } catch {
                $platformInfo.Architecture = "Unknown"
            }
        } else {
            # Windows environment
            $platformInfo.Name = "Windows"
            $platformInfo.IsWSL = $false
            
            # Get Windows version
            try {
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($osInfo) {
                    $platformInfo.Version = "$($osInfo.Caption) (Build $($osInfo.BuildNumber))"
                    $platformInfo.Architecture = $osInfo.OSArchitecture
                } else {
                    # Fallback method
                    $platformInfo.Version = [System.Environment]::OSVersion.VersionString
                    $platformInfo.Architecture = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
                }
            } catch {
                $platformInfo.Version = "Unknown"
                $platformInfo.Architecture = "Unknown"
            }
        }
        
        return $platformInfo
    } catch {
        throw "Failed to get platform details: $($_.Exception.Message)"
    }
}

#endregion

# Export functions for module usage
if (Get-Module -Name $MyInvocation.MyCommand.Name -ErrorAction SilentlyContinue) {
    Export-ModuleMember -Function @(
        # Core detection functions
        'Get-ExecutionContext',
        'Get-CurrentPlatform',
        'Get-DetailedPlatformInfo',
        'Test-Command',
        'Test-WSLAvailable',
        
        # Configuration-based functions
        'Get-PlatformForLoop',
        'Initialize-PlatformConfig',
        'Clear-PlatformConfigCache',
        'Get-PlatformDefaultPath',
        'Test-PathPlatform',
        'Test-PlatformCompatibility',
        
        # Advanced operations
        'Get-WSLDistributions',
        'Get-RecommendedSetupStrategy',
        'Invoke-CrossPlatformCommand',
        
        # Utilities and reporting
        'Write-ExecutionContextReport',
        'Get-PlatformDetails'
    )
}
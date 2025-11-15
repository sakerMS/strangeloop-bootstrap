# strangeloop Bootstrap - Tool Router Base
# Version: 1.0.0
# Common functionality for all tool installation routers

function New-ToolRouter {
    <#
    .SYNOPSIS
    Creates a standardized tool installation router
    
    .PARAMETER ToolName
    Name of the tool being installed
    
    .PARAMETER WindowsScript
    Path to Windows-specific installation script
    
    .PARAMETER LinuxScript  
    Path to Linux-specific installation script
    
    .PARAMETER DefaultVersion
    Default version to install if not specified
    
    .PARAMETER SupportedPlatforms
    Array of supported platforms ('Windows', 'Linux', 'WSL')
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        
        [Parameter(Mandatory)]
        [string]$WindowsScript,
        
        [Parameter(Mandatory)]
        [string]$LinuxScript,
        
        [string]$DefaultVersion = "latest",
        
        [string[]]$SupportedPlatforms = @('Windows', 'Linux', 'WSL')
    )
    
    return @{
        ToolName = $ToolName
        WindowsScript = $WindowsScript
        LinuxScript = $LinuxScript
        DefaultVersion = $DefaultVersion
        SupportedPlatforms = $SupportedPlatforms
    }
}

function Invoke-ToolRouter {
    <#
    .SYNOPSIS
    Executes a tool installation using the router pattern
    
    .PARAMETER Router
    Router configuration object from New-ToolRouter
    
    .PARAMETER Parameters
    Parameters to pass to the platform-specific script
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Router,
        
        [hashtable]$Parameters = @{}
    )
    
    try {
        Write-Info "$($Router.ToolName) Installation Router - detecting platform..."
        
        # Detect current platform
        $currentPlatform = Get-CurrentPlatform
        $platformIsWindows = $currentPlatform -eq "Windows"
        $platformIsWSL = $currentPlatform -eq "WSL" 
        $platformIsLinux = $currentPlatform -eq "Linux"
        
        Write-Info "Detected platform: $currentPlatform"
        
        # Check if platform is supported
        if ($currentPlatform -notin $Router.SupportedPlatforms) {
            throw "$($Router.ToolName) is not supported on platform: $currentPlatform"
        }
        
        # Override platform detection if WSLMode is explicitly set
        if ($Parameters.WSLMode -and $platformIsWindows) {
            Write-Info "WSLMode override: routing to Linux implementation from Windows"
            $platformIsLinux = $true
            $platformIsWindows = $false
        }
        
        # Route to appropriate platform-specific script
        $targetScript = ""
        if ($platformIsWindows) {
            $targetScript = $Router.WindowsScript
            Write-Info "Routing to Windows $($Router.ToolName) installation"
        } elseif ($platformIsWSL -or $platformIsLinux) {
            $targetScript = $Router.LinuxScript
            Write-Info "Routing to Linux $($Router.ToolName) installation"
        } else {
            throw "Unsupported platform: $currentPlatform"
        }
        
        # Verify target script exists
        if (-not (Test-Path $targetScript)) {
            throw "Platform-specific script not found: $targetScript"
        }
        
        # Execute the target script with parameters
        Write-Info "Executing: $(Split-Path $targetScript -Leaf)"
        $result = & $targetScript @Parameters
        $exitCode = $LASTEXITCODE
        
        # Return standardized result
        if ($exitCode -eq 0 -or $result -eq $true) {
            Write-Success "$($Router.ToolName) installation completed successfully"
            return @{
                Success = $true
                Tool = $Router.ToolName
                Platform = $currentPlatform
                Script = $targetScript
                Result = $result
            }
        } else {
            Write-Error "$($Router.ToolName) installation failed"
            return @{
                Success = $false
                Tool = $Router.ToolName
                Platform = $currentPlatform
                Script = $targetScript
                Result = $result
                ExitCode = $exitCode
            }
        }
        
    } catch {
        Write-Error "$($Router.ToolName) installation router failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Tool = $Router.ToolName
            Error = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
        }
    }
}

function Test-ToolInstallation {
    <#
    .SYNOPSIS
    Standard tool installation validation
    
    .PARAMETER ToolName
    Name of the tool to validate
    
    .PARAMETER Command
    Command to run for version check
    
    .PARAMETER VersionPattern
    Regex pattern to extract version from command output
    
    .PARAMETER MinVersion
    Minimum required version (optional)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        
        [Parameter(Mandatory)]
        [string]$Command,
        
        [string]$VersionPattern = "(\d+\.\d+\.\d+)",
        
        [string]$MinVersion = $null
    )
    
    try {
        $output = Invoke-Expression "$Command 2>&1"
        if ($LASTEXITCODE -eq 0 -and $output) {
            if ($output -match $VersionPattern) {
                $version = $matches[1]
                
                if ($MinVersion -and (Compare-Version $version $MinVersion) -lt 0) {
                    return @{
                        Installed = $true
                        Version = $version
                        Compliant = $false
                        Message = "$ToolName version $version is below minimum required version $MinVersion"
                    }
                }
                
                return @{
                    Installed = $true
                    Version = $version
                    Compliant = $true
                    Message = "$ToolName $version is installed and compliant"
                }
            } else {
                return @{
                    Installed = $true
                    Version = "unknown"
                    Compliant = $false
                    Message = "$ToolName is installed but version could not be determined"
                }
            }
        } else {
            return @{
                Installed = $false
                Version = $null
                Compliant = $false
                Message = "$ToolName is not installed or not accessible"
            }
        }
    } catch {
        return @{
            Installed = $false
            Version = $null
            Compliant = $false
            Message = "Error checking $ToolName`: $($_.Exception.Message)"
        }
    }
}

function Compare-Version {
    <#
    .SYNOPSIS
    Compares two semantic version strings
    
    .RETURNS
    -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2
    #>
    param(
        [string]$Version1,
        [string]$Version2
    )
    
    try {
        $v1 = [System.Version]::Parse($Version1)
        $v2 = [System.Version]::Parse($Version2)
        return $v1.CompareTo($v2)
    } catch {
        # Fallback to string comparison if version parsing fails
        return [string]::Compare($Version1, $Version2)
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-ToolRouter',
    'Invoke-ToolRouter', 
    'Test-ToolInstallation',
    'Compare-Version'
)
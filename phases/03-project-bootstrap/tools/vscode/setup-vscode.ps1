# strangeloop Setup - VS Code Integration Module
# Version: 1.0.0


param(
    [string]${project-path},
    [string]${project-name},
    [string]${loop-name},
    [string]$TargetPlatform = "Windows",
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")

function Test-VSCodeInstallation {
    <#
    .SYNOPSIS
    Tests if VS Code is installed and accessible
    
    .OUTPUTS
    Boolean indicating if VS Code is available
    #>
    
    try {
        # Check if 'code' command is available
        $codeVersion = & code --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $codeVersion) {
            return $true
        }
        
        # Check common installation paths
        $commonPaths = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "$env:PROGRAMFILES\Microsoft VS Code\Code.exe",
            "${env:PROGRAMFILES(X86)}\Microsoft VS Code\Code.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                return $true
            }
        }
        
        return $false
    } catch {
        return $false
    }
}

function Get-VSCodeExtensions {
    <#
    .SYNOPSIS
    Gets list of installed VS Code extensions
    
    .OUTPUTS
    Array of installed extension IDs
    #>
    
    try {
        $extensions = & code --list-extensions 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $extensions
        }
        return @()
    } catch {
        return @()
    }
}

function Install-VSCodeExtension {
    <#
    .SYNOPSIS
    Installs a VS Code extension
    
    .PARAMETER ExtensionId
    The extension ID to install
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ExtensionId,
        [switch]${what-if}
    )
    
    try {
        if (${what-if}) {
            Write-Host "what if: Would install VS Code extension: $ExtensionId" -ForegroundColor Yellow
            return $true
        } else {
            {
                Write-Progress "Installing VS Code extension: $ExtensionId"
            }
            
            $result = & code --install-extension $ExtensionId --force 2>&1
            if ($LASTEXITCODE -eq 0) {
                {
                    Write-Success "Extension installed: $ExtensionId"
                }
                return $true
            } else {
                {
                    Write-Warning "Failed to install extension $ExtensionId`: $result"
                }
                return $false
            }
        }
    } catch {
        {
            Write-Warning "Error installing extension $ExtensionId`: $($_.Exception.Message)"
        }
        return $false
    }
}

function Get-RecommendedExtensions {
    <#
    .SYNOPSIS
    Gets recommended extensions based on loop type
    
    .PARAMETER LoopName
    The name of the loop
    
    .OUTPUTS
    Array of recommended extension IDs
    #>
    param(
        [string]$LoopName
    )
    
    $baseExtensions = @(
        "ms-vscode.PowerShell",            # PowerShell support
        "ms-azuretools.vscode-azureresourcegroups"  # Azure tools
    )
    
    $loopSpecificExtensions = @()
    
    switch -Regex ($LoopName) {
        "python|flask" {
            $loopSpecificExtensions += @(
                "ms-python.python",
                "ms-python.autopep8",
                "ms-python.flake8",
                "ms-python.pylint"
            )
        }
        "csharp|dotnet|asp" {
            $loopSpecificExtensions += @(
                "ms-dotnettools.csharp",
                "ms-dotnettools.vscode-dotnet-runtime"
                # Note: Removed ms-vscode.vscode-nuget-package-manager as it doesn't exist
            )
        }
        "mcp" {
            $loopSpecificExtensions += @(
                # MCP projects typically use JSON configuration
            )
        }
        "langgraph|agent" {
            $loopSpecificExtensions += @(
                "ms-python.python",
                "ms-toolsai.jupyter"
            )
        }
    }
    
    return $baseExtensions + $loopSpecificExtensions
}

function Open-ProjectInVSCode {
    <#
    .SYNOPSIS
    Opens a project directory in VS Code
    
    .PARAMETER ProjectPath
    Full path to the project directory (Windows path or WSL path)
    
    .PARAMETER RequiresWSL
    Whether this is a WSL project
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        [switch]$RequiresWSL,
        [switch]${what-if}
    )
    
    try {
        if (${what-if}) {
            if ($RequiresWSL) {
                Write-Host "what if: Would open WSL project in VS Code: $ProjectPath" -ForegroundColor Yellow
                Write-Host "what if: Would execute 'wsl -- bash -c \"cd '$ProjectPath' && code .\"'" -ForegroundColor Yellow
            } else {
                Write-Host "what if: Would open Windows project in VS Code: $ProjectPath" -ForegroundColor Yellow
                Write-Host "what if: Would execute 'code \"$ProjectPath\"'" -ForegroundColor Yellow
            }
            return $true
        }
        if ($RequiresWSL) {
            # Open WSL project in VS Code
            {
                Write-Progress "Opening WSL project in VS Code..."
            }
            
            # Handle different path formats for WSL
            $wslPath = $ProjectPath -replace '^WSL: ', ''
            
            # If it's a Windows path, suggest using WSL home directory instead
            if ($wslPath -match '^[A-Za-z]:') {
                Write-Warning "Windows path provided for WSL loop. WSL projects should be in WSL filesystem."
                # Extract just the project name from the Windows path
                $projectName = Split-Path $wslPath -Leaf
                try {
                    # Detect if we're running inside WSL or from Windows
                    $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                    
                    if ($isRunningInWSL) {
                        # Running inside WSL - use direct commands
                        $wslUser = whoami 2>$null
                    } else {
                        # Running from Windows - use wsl command
                        $wslUser = & wsl -- whoami 2>$null
                    }
                    
                    if ($wslUser) {
                        $wslPath = "/home/$($wslUser.Trim())/AdsSnR_Containers/services/$projectName"
                    } else {
                        $wslPath = "/home/\$USER/AdsSnR_Containers/services/$projectName"
                    }
                } catch {
                    $wslPath = "/home/\$USER/AdsSnR_Containers/services/$projectName"
                }
                Write-Host "   Using WSL path: $wslPath" -ForegroundColor Yellow
            }
            
            # Convert $USER variable to absolute path if needed
            if ($wslPath.Contains('$USER')) {
                # Get the absolute path from WSL by expanding the $USER variable
                # Detect if we're running inside WSL or from Windows
                $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                
                if ($isRunningInWSL) {
                    # Running inside WSL - use direct bash command
                    $absolutePath = bash -c "echo `"$wslPath`"" 2>$null
                } else {
                    # Running from Windows - use wsl command
                    $absolutePath = wsl -- bash -c "echo `"$wslPath`"" 2>$null
                }
                
                if ($LASTEXITCODE -eq 0 -and $absolutePath) {
                    $expandedPath = $absolutePath.Trim()
                    Write-Host "   Expanded WSL path: $expandedPath" -ForegroundColor Gray
                    # Use the expanded absolute path for the code command
                    $wslPath = $expandedPath
                } else {
                    {
                        Write-Warning "Could not expand WSL path, using original: $wslPath"
                    }
                }
            }
            
            # Use the default WSL distribution
            try {
                {
                    Write-Progress "Opening project in VS Code..."
                }
                
                # Detect if we're running inside WSL or from Windows
                $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                
                if ($isRunningInWSL) {
                    # Running inside WSL - use direct bash command
                    Write-Host "   Running bash command: cd '$wslPath' && code ." -ForegroundColor Gray
                    $result = bash -c "cd '$wslPath' && code ." 2>&1
                } else {
                    # Running from Windows - use wsl command
                    Write-Host "   Running WSL command: cd '$wslPath' && code ." -ForegroundColor Gray
                    # Use default WSL distribution (no -d parameter)
                    $result = wsl -- bash -c "cd '$wslPath' && code ." 2>&1
                }
                
                $success = ($LASTEXITCODE -eq 0)
            } catch {
                $success = $false
                $result = "Failed to open VS Code: $($_.Exception.Message)"
            }
        } else {
            # Open Windows project in VS Code (preserve current directory)
            {
                Write-Progress "Opening project in VS Code..."
            }
            
            # Use direct command execution to ensure proper path handling
            try {
                # Quote the path to handle spaces and special characters
                $quotedPath = "`"$ProjectPath`""
                
                # Use Invoke-Expression to properly execute the command
                $output = Invoke-Expression "code $quotedPath" 2>&1
                
                # Check if the command executed without errors
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                    $result = "VS Code started successfully"
                    $success = $true
                } else {
                    $result = "VS Code command failed with exit code: $LASTEXITCODE"
                    $success = $false
                }
            } catch {
                $result = "Failed to start VS Code: $($_.Exception.Message)"
                $success = $false
            }
        }
        
        if ($success -or ($result -match "successfully")) {
            {
                Write-Success "Project opened in VS Code"
            }
            return $true
        } else {
            {
                Write-Warning "Failed to open project in VS Code: $result"
            }
            return $false
        }
    } catch {
        {
            Write-Warning "Error opening project in VS Code: $($_.Exception.Message)"
        }
        return $false
    }
}

function Get-VSCodeOpeningPreference {
    <#
    .SYNOPSIS
    Prompts user whether to open the project in VS Code
    
    .OUTPUTS
    Boolean indicating whether to open VS Code
    #>
    
    Write-Host ""
    Write-Host "📝 " -ForegroundColor Blue -NoNewline
    $response = Read-UserPrompt -Prompt "Open project in VS Code?" -ValidValues @("y","n")
    
    return Test-YesResponse $response
}

function Initialize-VSCodeIntegration {
    <#
    .SYNOPSIS
    Main function to setup VS Code integration
    
    .PARAMETER project-path
    Parent directory path where the project was created
    
    .PARAMETER project-name
    Name of the project (subdirectory within project-path)
    
    .PARAMETER loop-name
    Name of the loop template
    
    .PARAMETER Platform
    Target platform (Windows or WSL)
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [string]${project-path},
        [string]${project-name},
        [string]${loop-name},
        [string]$TargetPlatform = "Windows",
        [switch]${what-if}
    )
    
    Write-Step "Setting up VS Code Integration..."
    
    if (${what-if}) {
        Write-Host "what if: Would check VS Code installation" -ForegroundColor Yellow
        Write-Host "what if: Would get list of currently installed VS Code extensions" -ForegroundColor Yellow
        if ($TargetPlatform -eq "WSL") {
            Write-Host "what if: Would install WSL extension for VS Code" -ForegroundColor Yellow
        }
        if (${loop-name}) {
            $recommendedExtensions = Get-RecommendedExtensions -LoopName ${loop-name}
            Write-Host "what if: Would install these VS Code extensions: $($recommendedExtensions -join ', ')" -ForegroundColor Yellow
        }
        if (${project-path} -and ${project-name}) {
            Write-Host "what if: Would open project in VS Code" -ForegroundColor Yellow
        }
        return $true
    }
    
    # Debug: Show what parameters were received
    Write-Host "📋 VSCode Integration Parameters:" -ForegroundColor Cyan
    Write-Host "   ProjectPath: ${project-path}" -ForegroundColor Gray
    Write-Host "   ProjectName: ${project-name}" -ForegroundColor Gray
    Write-Host "   LoopName: ${loop-name}" -ForegroundColor Gray
    Write-Host "   Target Platform: $TargetPlatform" -ForegroundColor Gray
    
    try {
        # Test VS Code installation
        Write-Progress "Checking VS Code installation..."
        
        if (-not (Test-VSCodeInstallation)) {
            Write-Warning "VS Code is not installed or not accessible via 'code' command"
            Write-Info "Please ensure VS Code is installed and added to PATH"
            return $false
        }
        
        Write-Success "VS Code is available"
        
        # Get current extensions
        $installedExtensions = Get-VSCodeExtensions
        
        # Install WSL extension if running on WSL platform
        if ($TargetPlatform -eq "WSL") {
            $wslExtension = "ms-vscode-remote.remote-wsl"
            if ($wslExtension -notin $installedExtensions) {
                Write-Progress "Installing WSL extension for VS Code..."
                if (${what-if}) {
                    $wslInstallResult = Install-VSCodeExtension -ExtensionId $wslExtension -what-if
                } else {
                    $wslInstallResult = Install-VSCodeExtension -ExtensionId $wslExtension
                }
                if (-not $wslInstallResult) {
                    Write-Warning "Failed to install WSL extension, but continuing..."
                }
            } else {
                Write-Success "WSL extension already installed"
            }
        }
        
        # Install recommended extensions based on loop type
        if (${loop-name}) {
            $recommendedExtensions = Get-RecommendedExtensions -LoopName ${loop-name}
            
            foreach ($extension in $recommendedExtensions) {
                if ($extension -notin $installedExtensions) {
                    if (${what-if}) {
                        $null = Install-VSCodeExtension -ExtensionId $extension -what-if
                    } else {
                        $null = Install-VSCodeExtension -ExtensionId $extension
                    }
                    # Continue even if some extensions fail to install
                }
            }
        }
        
        # Open project directory in VS Code if path is provided and user wants to
        if (${project-path} -and ${project-name}) {

            # Assign to local variables for easier handling
            $projectPath = $null
            $projectName = $null
            if ($PSBoundParameters.ContainsKey('project-path')) { $projectPath = $PSBoundParameters['project-path'] }
            if ($PSBoundParameters.ContainsKey('project-name')) { $projectName = $PSBoundParameters['project-name'] }

            # New logic: Check if project-path already ends with project-name before concatenating
            $fullProjectPath = $projectPath  # Default fallback
            
            if ($projectPath -and $projectName) {
                # Check if project path already ends with project name to avoid duplication
                $pathEndsWithProjectName = if ($TargetPlatform -eq "WSL") {
                    $projectPath.TrimEnd('/').EndsWith($projectName)
                } else {
                    $projectPath.TrimEnd('\').EndsWith($projectName)
                }
                
                if ($pathEndsWithProjectName) {
                    # Project path already contains project name, use as-is
                    $fullProjectPath = $projectPath
                    Write-Host "   Project path already contains project name: $fullProjectPath" -ForegroundColor Green
                } else {
                    # Construct full path by concatenating project-path + project-name
                    $concatenatedPath = if ($TargetPlatform -eq "WSL") {
                        $cleanProjectPath = $projectPath.TrimEnd('/')
                        $cleanProjectName = $projectName.TrimStart('/')
                        "$cleanProjectPath/$cleanProjectName"
                    } else {
                        Join-Path $projectPath $projectName
                    }
                    
                    # Test if the concatenated path exists
                    $concatenatedPathExists = if ($TargetPlatform -eq "WSL") {
                        $pathExistsInWSL = wsl test -d "$concatenatedPath" 2>$null
                        ($LASTEXITCODE -eq 0)
                    } else {
                        Test-Path $concatenatedPath
                    }
                    
                    if ($concatenatedPathExists) {
                        # Use the concatenated path if it exists
                        $fullProjectPath = $concatenatedPath
                        Write-Host "   Using concatenated path (exists): $fullProjectPath" -ForegroundColor Green
                    } else {
                        # Fall back to project-path only if concatenated path doesn't exist
                        $fullProjectPath = $projectPath
                        Write-Host "   Concatenated path doesn't exist: $concatenatedPath" -ForegroundColor Yellow
                        Write-Host "   Falling back to project-path: $fullProjectPath" -ForegroundColor Yellow
                    }
                }
            }
            
            # Check if the path exists using platform-appropriate method
            $pathExists = $false
            if ($TargetPlatform -eq "WSL") {
                # For WSL platform, test path existence in WSL
                try {
                    # Detect if we're running inside WSL or from Windows
                    $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version") -or
                                     ($env:PATH -and $env:PATH.Contains('/usr/bin'))
                    
                    if ($isRunningInWSL) {
                        # Already in WSL, use direct Linux commands
                        $testResult = test -d "$fullProjectPath" 2>&1
                        $pathExists = ($LASTEXITCODE -eq 0)
                        
                        # If test -d fails, try with ls as an alternative check
                        if (-not $pathExists) {
                            $lsResult = ls -d "$fullProjectPath" 2>&1
                            $pathExists = ($LASTEXITCODE -eq 0)
                        }
                    } else {
                        # Running from Windows, use wsl command
                        $wslResult = wsl test -d "$fullProjectPath" 2>&1
                        $pathExists = ($LASTEXITCODE -eq 0)
                        
                        # If test -d fails, try with ls as an alternative check
                        if (-not $pathExists) {
                            $lsResult = wsl ls -d "$fullProjectPath" 2>&1
                            $pathExists = ($LASTEXITCODE -eq 0)
                        }
                    }
                } catch {
                    Write-Debug "WSL path validation failed: $_"
                    $pathExists = $false
                }
            } else {
                # For Windows platform, use PowerShell Test-Path
                $pathExists = Test-Path $fullProjectPath
            }

            $shouldOpenVSCode = Get-VSCodeOpeningPreference

            if ($pathExists) {
                if ($shouldOpenVSCode) {
                    Write-Host "🚀 Opening project in VS Code: $fullProjectPath" -ForegroundColor Green
                    $params = @{
                        ProjectPath = $fullProjectPath
                        RequiresWSL = ($TargetPlatform -eq "WSL")
                    }
                    if (${what-if}) { $params['what-if'] = ${what-if} }
                    
                    $openResult = Open-ProjectInVSCode @params
                    if (-not $openResult) {
                        Write-Warning "Failed to open project in VS Code, but setup completed"
                    }
                } else {
                    Write-Info "Skipping VS Code project opening"
                }
            } else {
                Write-Warning "Project path does not exist: $fullProjectPath"
                Write-Info "Platform: $TargetPlatform"
                if ($TargetPlatform -eq "WSL") {
                    # Detect if we're running inside WSL or from Windows
                    $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                    
                    Write-Info "Tip: For WSL projects, ensure the path exists in the WSL filesystem"
                    if ($isRunningInWSL) {
                        Write-Info "You can check with: ls -la `"$fullProjectPath`""
                        Write-Info "Or check parent directory: ls -la `"$(Split-Path $fullProjectPath -Parent)`""
                    } else {
                        Write-Info "You can check with: wsl ls -la `"$fullProjectPath`""
                        Write-Info "Or check parent directory: wsl ls -la `"$(Split-Path $fullProjectPath -Parent)`""
                    }
                } else {
                    Write-Info "You can check with: Test-Path '$fullProjectPath'"
                }
            }
        } elseif (${project-path} -and -not ${project-name}) {
            # Handle case where project-path is already the full path to the project
            Write-Info "Using provided project path as full project directory"
            $fullProjectPath = ${project-path}
            
            # Check path existence based on the platform
            $pathExists = $false
            if ($TargetPlatform -eq "WSL") {
                # For WSL platform, test path existence in WSL
                try {
                    # Detect if we're running inside WSL or from Windows
                    $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                    
                    if ($isRunningInWSL) {
                        # Running inside WSL - use direct Linux commands
                        $testResult = test -d "$fullProjectPath" 2>&1
                        $pathExists = ($LASTEXITCODE -eq 0)
                        
                        # If test -d fails, try with ls as an alternative check
                        if (-not $pathExists) {
                            $lsResult = ls -d "$fullProjectPath" 2>&1
                            $pathExists = ($LASTEXITCODE -eq 0)
                        }
                    } else {
                        # Running from Windows - use wsl command with proper path quoting
                        $wslResult = wsl test -d "$fullProjectPath" 2>&1
                        $pathExists = ($LASTEXITCODE -eq 0)
                        
                        # If test -d fails, try with ls as an alternative check
                        if (-not $pathExists) {
                            $lsResult = wsl ls -d "$fullProjectPath" 2>&1
                            $pathExists = ($LASTEXITCODE -eq 0)
                        }
                    }
                } catch {
                    Write-Debug "WSL path validation failed: $_"
                    $pathExists = $false
                }
            } else {
                # For Windows platform, use PowerShell Test-Path
                $pathExists = Test-Path $fullProjectPath
            }
            
            # Verify the path exists
            if ($pathExists) {
                $shouldOpenVSCode = Get-VSCodeOpeningPreference

                if ($shouldOpenVSCode) {
                    Write-Host "🚀 Opening project in VS Code: $fullProjectPath" -ForegroundColor Green
                    $params = @{
                        ProjectPath = $fullProjectPath
                        RequiresWSL = ($TargetPlatform -eq "WSL")
                    }
                    if (${what-if}) { $params['what-if'] = ${what-if} }
                    
                    $openResult = Open-ProjectInVSCode @params
                    if (-not $openResult) {
                        Write-Warning "Failed to open project in VS Code, but setup completed"
                    }
                } else {
                    Write-Info "Skipping VS Code project opening"
                }
            } else {
                Write-Warning "Project path does not exist: $fullProjectPath"
                Write-Info "Platform: $TargetPlatform"
                if ($TargetPlatform -eq "WSL") {
                    # Detect if we're running inside WSL or from Windows
                    $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                    
                    Write-Info "Tip: For WSL projects, ensure the path exists in the WSL filesystem"
                    if ($isRunningInWSL) {
                        Write-Info "You can check with: ls -la `"$fullProjectPath`""
                        Write-Info "Or check parent directory: ls -la `"$(Split-Path $fullProjectPath -Parent)`""
                    } else {
                        Write-Info "You can check with: wsl ls -la `"$fullProjectPath`""
                        Write-Info "Or check parent directory: wsl ls -la `"$(Split-Path $fullProjectPath -Parent)`""
                    }
                } else {
                    Write-Info "You can check with: Test-Path '$fullProjectPath'"
                }
            }
        } else {
            Write-Warning "No project path provided to VSCode integration"
        }
        
        Write-Success "VS Code integration setup completed"
        return @{
            Success = $true
            Message = "VS Code integration setup completed"
        }
        
    } catch {
        Write-Error "VS Code integration setup failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $params = @{
        'project-path' = ${project-path}
        'project-name' = ${project-name}
        'loop-name' = ${loop-name}
        TargetPlatform = $TargetPlatform
    }
    if (${what-if}) { $params['what-if'] = ${what-if} }
    
    $result = Initialize-VSCodeIntegration @params
    
    if ($result) {
        Write-Success "VS Code integration completed successfully"
        return $result
    } else {
        Write-Error "VS Code integration failed"
        return $false
    }
}

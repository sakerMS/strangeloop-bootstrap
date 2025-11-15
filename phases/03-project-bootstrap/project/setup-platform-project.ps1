# strangeloop Setup - Target Platform-Specific Project Setup
# Version: 1.0.0
# Phase 3 Step 2: Project Setup (Target Platform-Specific)
# Purpose: Create and configure project on chosen platform

param(
    [string]${project-name},
    [string]${loop-name},
    [string]${project-path},
    [string]$TargetPlatform,
    [hashtable]$LoopData,
    [switch]${what-if},
    [switch]${check-only}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Initialize-PlatformSpecificProject {
    param(
        [string]$ProjectName,
        [string]$LoopName,
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [hashtable]$LoopSelectionData,
        [switch]${what-if},
        [switch]${check-only}
    )
    
    Write-Step "Target Platform-Specific Project Setup (Phase 3 Step 2)..."
    Write-Info "Creating and configuring project on target platform: $TargetPlatform"
    
    if (${what-if}) {
        Write-Host "what if: Would perform target platform-specific project setup:" -ForegroundColor Yellow
        Write-Host "what if:   - Create project using loop '$LoopName' on target platform: $TargetPlatform" -ForegroundColor Yellow
        Write-Host "what if:   - Setup inventory metadata (service_tree_id, is_production, ado_area_path)" -ForegroundColor Yellow
        Write-Host "what if:   - Initialize Git repository" -ForegroundColor Yellow
        Write-Host "what if:   - Configure target platform-specific paths and tools" -ForegroundColor Yellow
        Write-Host "what if:   - Install target platform-specific dependencies" -ForegroundColor Yellow
        Write-Host "what if:   - Setup target platform-specific configuration" -ForegroundColor Yellow
        return @{
            Success = $true
            ProjectPath = "/example/path"
            ProjectName = "example-project"
            LoopName = "example-loop"
            Platform = $TargetPlatform
        }
    }
    
    try {
        Write-Host ""
        Write-Host "🚀 Step 2.1: Project Creation" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────" -ForegroundColor DarkCyan
        
        # Determine execution context and command structure
        $platformContext = Get-PlatformContext -TargetPlatform $TargetPlatform
        
        # Create project using the original project initialization module
        $projectParams = @{}
        if ($ProjectName) { $projectParams['project-name'] = $ProjectName }
        if ($LoopName) { $projectParams['loop-name'] = $LoopName }
        if ($ProjectPath) { $projectParams['project-path'] = $ProjectPath }
        if ($TargetPlatform) { $projectParams['TargetPlatform'] = $TargetPlatform }
        if (${what-if}) { $projectParams['what-if'] = $true }
        if (${check-only}) { $projectParams['check-only'] = $true }
        
        # Call the original project initialization module
        $originalProjectPath = Join-Path $PSScriptRoot "project\initialize-project.ps1"
        if (Test-Path $originalProjectPath) {
            Write-Info "Initializing project using strangeloop template..."
            $projectResult = & $originalProjectPath @projectParams
            
            if ($projectResult -and ($projectResult.Success -or $projectResult -eq $true)) {
                Write-Success "Project created successfully"
                
                # Extract project details from result
                $actualProjectPath = if ($projectResult.ProjectPath) { $projectResult.ProjectPath } else { $ProjectPath }
                $actualProjectName = if ($projectResult.ProjectName) { $projectResult.ProjectName } else { $ProjectName }
                $actualLoopName = if ($projectResult.LoopName) { $projectResult.LoopName } else { $LoopName }
                
                # Extract GitContext for proper Git integration
                $gitContext = if ($projectResult.GitContext) { $projectResult.GitContext } else { $null }
                
                # Debug GitContext extraction
                Write-Info "🔍 DEBUG: ProjectResult has GitContext: $($projectResult.GitContext -ne $null)"
                if ($projectResult.GitContext) {
                    Write-Info "🔍 DEBUG: GitContext.IsGitControlled: $($projectResult.GitContext.IsGitControlled)"
                    Write-Info "🔍 DEBUG: GitContext.LocalBranch: $($projectResult.GitContext.LocalBranch)"
                    Write-Info "🔍 DEBUG: GitContext.RemoteUrl: $($projectResult.GitContext.RemoteUrl)"
                }
                
            } else {
                Write-Error "Project creation failed"
                return @{
                    Success = $false
                    Error = "Project creation failed"
                    Phase = "Project Creation"
                }
            }
        } else {
            Write-Error "Project initialization script not found: $originalProjectPath"
            return @{
                Success = $false
                Error = "Project initialization script not found"
                Phase = "Project Creation"
            }
        }
        
        Write-Host ""
        Write-Host "� Step 2.2: Inventory Metadata Setup" -ForegroundColor Cyan
        Write-Host "──────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Setup inventory metadata for the project
        $inventoryMetadataPath = Join-Path $PSScriptRoot "inventory_metadata\setup-inventory-metadata.ps1"
        if (Test-Path $inventoryMetadataPath) {
            Write-Info "Setting up inventory metadata..."
            
            $inventoryParams = @{
                ProjectPath = $actualProjectPath
                ProjectName = $actualProjectName
                LoopName = $actualLoopName
            }
            if (${what-if}) { $inventoryParams['WhatIf'] = $true }
            if (${check-only}) { $inventoryParams['CheckOnly'] = $true }
            
            $inventoryResult = & $inventoryMetadataPath @inventoryParams
            
            if ($inventoryResult -and $inventoryResult.Success) {
                if ($inventoryResult.Configured) {
                    Write-Success "Inventory metadata configured successfully"
                } else {
                    Write-Info "Inventory metadata setup skipped"
                }
            } else {
                $errorMsg = if ($inventoryResult -and $inventoryResult.Message) {
                    $inventoryResult.Message
                } else {
                    "Inventory metadata setup encountered issues"
                }
                Write-Warning "Inventory metadata setup failed: $errorMsg"
            }
        } else {
            Write-Warning "Inventory metadata setup script not found: $inventoryMetadataPath"
        }
        
        Write-Host ""
        Write-Host "�📚 Step 2.3: Git Repository Setup" -ForegroundColor Cyan
        Write-Host "──────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Initialize Git repository in target platform-specific context
        $gitSetupResult = Initialize-PlatformSpecificGit -ProjectPath $actualProjectPath -TargetPlatform $TargetPlatform -LoopName $actualLoopName -CheckOnly:${check-only} -WhatIf:${what-if} -GitContext $gitContext
        
        if ($gitSetupResult.Success) {
            Write-Success "Git repository setup completed"
        } else {
            $errorMsg = if ($gitSetupResult -and $gitSetupResult.ContainsKey('Error') -and $gitSetupResult.Error) { 
                $gitSetupResult.Error 
            } else { 
                "Git setup encountered issues" 
            }
            Write-Warning "Git repository setup failed: $errorMsg"
        }
        
        Write-Host ""
        Write-Host "🔧 Step 2.4: Target Platform-Specific Configuration" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Apply target platform-specific configurations
        $configResult = Apply-PlatformSpecificConfiguration -ProjectPath $actualProjectPath -TargetPlatform $TargetPlatform -LoopName $actualLoopName
        
        if ($configResult.Success) {
            Write-Success "Target platform-specific configuration applied"
        } else {
            Write-Warning "Target platform-specific configuration failed: $($configResult.Error)"
        }
        
        Write-Host ""
        Write-Host "📦 Step 2.4: Target Platform Dependencies" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Install target platform-specific dependencies
        $depsResult = Install-PlatformDependencies -ProjectPath $actualProjectPath -TargetPlatform $TargetPlatform -LoopName $actualLoopName
        
        if ($depsResult.Success) {
            Write-Success "Platform dependencies installed"
        } else {
            Write-Warning "Platform dependencies installation failed: $($depsResult.Error)"
        }
        
        # Final validation
        Write-Host ""
        Write-Host "✅ Step 2.5: Project Validation" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────" -ForegroundColor DarkCyan
        
        $validationResult = Test-ProjectSetup -ProjectPath $actualProjectPath -TargetPlatform $TargetPlatform -CheckOnly:${check-only}
        
        if ($validationResult.Success) {
            Write-Success "Project validation completed successfully"
        } else {
            Write-Warning "Project validation found issues: $($validationResult.Issues -join ', ')"
        }
        
        # Return comprehensive result
        return @{
            Success = $true
            ProjectPath = $actualProjectPath
            ProjectName = $actualProjectName
            LoopName = $actualLoopName
            Platform = $TargetPlatform
            GitContext = $gitSetupResult
            ConfigurationApplied = $configResult.Success
            DependenciesInstalled = $depsResult.Success
            ValidationPassed = $validationResult.Success
            Phase = "Platform-Specific Project Setup"
            Message = "Project '$actualProjectName' created successfully on $TargetPlatform platform"
        }
        
    } catch {
        Write-Error "Platform-specific project setup failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Phase = "Platform-Specific Project Setup"
        }
    }
}

function Get-PlatformContext {
    param(
        [string]$TargetPlatform
    )
    
    if ($TargetPlatform -eq "WSL") {
        return @{
            IsWSL = $true
            CommandPrefix = "wsl --"
            PathSeparator = "/"
            HomeDirectory = "/home/$env:USERNAME"
        }
    } else {
        return @{
            IsWSL = $false
            CommandPrefix = ""
            PathSeparator = "\"
            HomeDirectory = $env:USERPROFILE
        }
    }
}

function Initialize-PlatformSpecificGit {
    param(
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [string]$LoopName,
        [switch]$CheckOnly,
        [switch]$WhatIf,
        [hashtable]$GitContext
    )
    
    Write-Info "Initializing Git repository for target platform: $TargetPlatform..."
    
    try {
        $gitParams = @{
            'project-path' = $ProjectPath
            'project-name' = (Split-Path $ProjectPath -Leaf)
            'loop-name' = $LoopName
            'TargetPlatform' = $TargetPlatform
            'requires-wsl' = ($TargetPlatform -eq "WSL")
        }
        
        # Add check-only and what-if parameters if specified
        if ($CheckOnly) { $gitParams['check-only'] = $true }
        if ($WhatIf) { $gitParams['what-if'] = $true }
        
        # Add GitContext if provided
        if ($GitContext) { $gitParams['git-context'] = $GitContext }
        
        # Call the original Git setup module
        $gitModulePath = Join-Path $PSScriptRoot "git\setup-git-source-control.ps1"
        if (Test-Path $gitModulePath) {
            $gitResult = & $gitModulePath @gitParams
            
            return @{
                Success = ($gitResult -and ($gitResult.Success -or $gitResult -eq $true))
                RemoteConfigured = if ($gitResult -and $gitResult.ContainsKey('RemoteConfigured')) { $gitResult.RemoteConfigured } else { $false }
                Error = if ($gitResult -and -not $gitResult.Success -and $gitResult.ContainsKey('ErrorMessage')) { 
                    $gitResult.ErrorMessage 
                } elseif ($gitResult -and -not $gitResult.Success) { 
                    "Git setup failed" 
                } else { 
                    $null 
                }
            }
        } else {
            Write-Warning "Git setup module not found: $gitModulePath"
            return @{
                Success = $false
                Error = "Git setup module not found"
            }
        }
    } catch {
        Write-Warning "Git initialization failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Apply-PlatformSpecificConfiguration {
    param(
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [string]$LoopName
    )
    
    Write-Info "Applying target platform-specific configuration ($TargetPlatform)..."
    
    try {
        # Platform-specific configuration logic
        if ($TargetPlatform -eq "WSL") {
            # Get current platform for command routing
            $currentPlatform = Get-CurrentPlatform
            $isRunningInWSL = $currentPlatform -eq "WSL"
            
            # WSL-specific configurations
            Write-Info "Applying WSL-specific configurations..."
            
            # Set appropriate file permissions for WSL
            if (Test-Path $ProjectPath) {
                # Example: Set execute permissions for shell scripts
                $shellScripts = Get-ChildItem -Path $ProjectPath -Filter "*.sh" -Recurse -ErrorAction SilentlyContinue
                foreach ($script in $shellScripts) {
                    try {
                        if ($isRunningInWSL) {
                            # Already in WSL, run chmod directly
                            & chmod +x $script.FullName 2>&1
                        } else {
                            # Running from Windows, use wsl command
                            & wsl -- chmod +x $script.FullName 2>&1
                        }
                    } catch {
                        Write-Warning "Failed to set execute permission for $($script.Name)"
                    }
                }
            }
            
            # Configure WSL-specific paths in configuration files
            # This would be loop-specific implementation
            
        } else {
            # Windows-specific configurations
            Write-Info "Applying Windows-specific configurations..."
            
            # Windows-specific configuration logic
            # This would include setting up Windows paths, registry entries if needed, etc.
        }
        
        return @{
            Success = $true
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Install-PlatformDependencies {
    param(
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [string]$LoopName
    )
    
    Write-Info "Installing target platform-specific dependencies ($TargetPlatform)..."
    
    try {
        if ($TargetPlatform -eq "WSL") {
            # Get current platform for command routing
            $currentPlatform = Get-CurrentPlatform
            $isRunningInWSL = $currentPlatform -eq "WSL"
            
            # Install WSL-specific dependencies
            Write-Info "Installing WSL dependencies..."
            
            # Example: Install Python packages in WSL environment
            if (Test-Path (Join-Path $ProjectPath "requirements.txt")) {
                Write-Info "Installing Python requirements in WSL..."
                if ($isRunningInWSL) {
                    # Already in WSL, run pip directly
                    & bash -c "cd '$ProjectPath' && python3 -m pip install -r requirements.txt" 2>&1
                } else {
                    # Running from Windows, use wsl command
                    & wsl -- bash -c "cd '$ProjectPath' && python3 -m pip install -r requirements.txt" 2>&1
                }
            }
            
            if (Test-Path (Join-Path $ProjectPath "pyproject.toml")) {
                Write-Info "Installing Poetry dependencies in WSL..."
                if ($isRunningInWSL) {
                    # Already in WSL, run poetry directly
                    & bash -c "cd '$ProjectPath' && poetry install" 2>&1
                } else {
                    # Running from Windows, use wsl command
                    & wsl -- bash -c "cd '$ProjectPath' && poetry install" 2>&1
                }
            }
            
        } else {
            # Install Windows-specific dependencies
            Write-Info "Installing Windows dependencies..."
            
            # Example: Install Python packages in Windows environment
            if (Test-Path (Join-Path $ProjectPath "requirements.txt")) {
                Write-Info "Installing Python requirements in Windows..."
                & python -m pip install -r (Join-Path $ProjectPath "requirements.txt")
            }
            
            if (Test-Path (Join-Path $ProjectPath "pyproject.toml")) {
                Write-Info "Installing Poetry dependencies in Windows..."
                Push-Location $ProjectPath
                try {
                    & poetry install
                } finally {
                    Pop-Location
                }
            }
        }
        
        return @{
            Success = $true
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-ProjectSetup {
    param(
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [switch]$CheckOnly
    )
    
    Write-Info "Validating project setup on target platform: $TargetPlatform..."
    
    # In check-only mode, skip actual file system validation
    if ($CheckOnly) {
        Write-Info "Check-only mode: Skipping file system validation"
        return @{
            Success = $true
            Issues = @()
            Message = "Validation skipped in check-only mode"
        }
    }
    
    $issues = @()
    $warnings = @()
    
    try {
        # Basic path validation
        if (-not (Test-Path $ProjectPath)) {
            $warnings += "Project directory will be created: $ProjectPath"
        }
        
        # Platform-specific validations
        if ($TargetPlatform -eq "WSL") {
            # Get current platform for command routing
            $currentPlatform = Get-CurrentPlatform
            $isRunningInWSL = $currentPlatform -eq "WSL"
            
            # WSL-specific validations
            if ($ProjectPath -notmatch "^/.*") {
                $issues += "WSL project path should use Unix-style paths"
            }
            
            # Test WSL access to parent directory
            if ($ProjectPath -match "^/.*") {
                # For Unix-style paths, manually extract parent directory
                $pathParts = $ProjectPath.Split('/')
                if ($pathParts.Length -gt 2) {
                    $parentPath = ($pathParts[0..($pathParts.Length - 2)] -join '/')
                    if (-not $parentPath) { $parentPath = "/" }
                    
                    try {
                        if ($isRunningInWSL) {
                            # Already in WSL, test directory directly
                            $wslTest = Test-Path $parentPath
                            $testSuccess = $wslTest
                        } else {
                            # Running from Windows, use wsl command
                            $wslTest = & wsl -- test -d $parentPath 2>$null
                            $testSuccess = ($LASTEXITCODE -eq 0)
                        }
                        
                        if (-not $testSuccess) {
                            $issues += "WSL cannot access parent directory: $parentPath"
                        }
                    } catch {
                        $issues += "WSL parent directory validation failed"
                    }
                }
            }
            
        } else {
            # Windows-specific validations
            if ($ProjectPath -match "^/.*") {
                $issues += "Windows project path should use Windows-style paths"
            }
        }
        
        # Git repository validation
        if (Test-Path (Join-Path $ProjectPath ".git")) {
            Write-Success "Git repository already initialized"
        } else {
            $warnings += "Git repository will be initialized"
        }
        
        # Report warnings as informational messages
        if ($warnings.Count -gt 0) {
            foreach ($warning in $warnings) {
                Write-Info "📝 $warning"
            }
        }
        
        return @{
            Success = ($issues.Count -eq 0)
            Issues = $issues
            Warnings = $warnings
        }
        
    } catch {
        return @{
            Success = $false
            Issues = @($_.Exception.Message)
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically
    $params = @{}
    if (${project-name}) { $params['ProjectName'] = ${project-name} }
    if (${loop-name}) { $params['LoopName'] = ${loop-name} }
    if (${project-path}) { $params['ProjectPath'] = ${project-path} }
    if ($TargetPlatform) { $params['TargetPlatform'] = $TargetPlatform }
    if ($LoopData) { $params['LoopSelectionData'] = $LoopData }
    if (${what-if}) { $params['what-if'] = $true }
    if (${check-only}) { $params['check-only'] = $true }
    
    $result = Initialize-PlatformSpecificProject @params
    
    return $result
}

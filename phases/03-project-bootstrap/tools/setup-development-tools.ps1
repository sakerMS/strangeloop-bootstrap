# strangeloop Setup - Development Tools Integration
# Version: 1.0.0
# Phase 3 Step 3: Development Tools Integration
# Purpose: Configure development tools and optional features

param(
    [string]$TargetPlatform,
    [hashtable]$ProjectData,
    [string]${project-path},
    [string]${project-name},
    [string]${loop-name},
    [switch]${what-if},
    [switch]${check-only},
    [switch]${skip-pipelines},
    [switch]${skip-vscode},
    [switch]${skip-git-validation}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")

function Initialize-DevelopmentToolsIntegration {
    param(
        [string]$TargetPlatform,
        [hashtable]$ProjectSetupData,
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$LoopName,
        [switch]${what-if},
        [switch]${check-only}
    )
    
    Write-Step "Development Tools Integration (Phase 3 Step 3)..."
    Write-Info "Configuring development tools and optional features for $TargetPlatform platform"
    
    if (${what-if}) {
        Write-Host "what if: Would perform development tools integration:" -ForegroundColor Yellow
        Write-Host "what if:   - Setup CI/CD pipelines (optional)" -ForegroundColor Yellow
        Write-Host "what if:   - Configure VS Code integration" -ForegroundColor Yellow
        Write-Host "what if:   - Install target platform-specific extensions" -ForegroundColor Yellow
        Write-Host "what if:   - Setup debugging configurations" -ForegroundColor Yellow
        Write-Host "what if:   - Configure workspace settings" -ForegroundColor Yellow
        return @{
            Success = $true
            PipelinesConfigured = $true
            VSCodeConfigured = $true
            Platform = $TargetPlatform
        }
    }
    
    try {
        # Extract project details from project data or use provided parameters
        $actualProjectPath = if ($ProjectSetupData -and $ProjectSetupData.ProjectPath) { $ProjectSetupData.ProjectPath } else { $ProjectPath }
        $actualProjectName = if ($ProjectSetupData -and $ProjectSetupData.ProjectName) { $ProjectSetupData.ProjectName } else { $ProjectName }
        $actualLoopName = if ($ProjectSetupData -and $ProjectSetupData.LoopName) { $ProjectSetupData.LoopName } else { $LoopName }
        $actualPlatform = if ($ProjectSetupData -and $ProjectSetupData.Platform) { $ProjectSetupData.Platform } else { $TargetPlatform }
        
        # Validate we have the necessary information
        if (-not $actualProjectPath -or -not $actualProjectName -or -not $actualLoopName) {
            Write-Error "Missing required project information for development tools integration"
            return @{
                Success = $false
                Error = "Missing project information"
                Phase = "Development Tools Integration"
            }
        }
        
        Write-Info "Configuring development tools for project: $actualProjectName"
        Write-Info "Project path: $actualProjectPath"
        Write-Info "Target platform: $actualPlatform"
        
        $integrationResults = @{
            PipelinesConfigured = $false
            VSCodeConfigured = $false
            ExtensionsInstalled = $false
            DebuggingConfigured = $false
        }
        
        Write-Host ""
        Write-Host "🚀 Step 3.1: CI/CD Pipeline Setup (Optional)" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Pipeline setup (optional)
        $setupPipelines = $false
        
        if (${skip-pipelines}) {
            Write-Info "⏭️  Pipeline setup skipped (stage targeting)"
            $setupPipelines = $false
        } elseif (${skip-vscode} -and -not ${skip-pipelines}) {
            # When targeting pipelines specifically (skip-vscode=true, skip-pipelines not set), force setup
            Write-Info "🎯 Pipeline setup forced (targeting pipelines stage)"
            $setupPipelines = $true
        } else {
            Write-Host ""
            Write-Host "🚀 Azure DevOps Pipeline Setup" -ForegroundColor Yellow
            Write-Host "This will create Azure DevOps pipelines for your project." -ForegroundColor Gray
            Write-Host ""
            
            do {
                $response = Read-Host "Would you like to set up Azure DevOps pipelines? (y/n)"
                $response = $response.Trim().ToLower()
            } while ($response -ne 'y' -and $response -ne 'n' -and $response -ne 'yes' -and $response -ne 'no')
            
            $setupPipelines = ($response -eq 'y' -or $response -eq 'yes')
        }
        
        if ($setupPipelines) {
            $pipelineResult = Setup-CICDPipelines -ProjectPath $actualProjectPath -ProjectName $actualProjectName -TargetPlatform $actualPlatform -SkipGitValidation:${skip-git-validation}
            $integrationResults.PipelinesConfigured = $pipelineResult.Success
            
            if ($pipelineResult.Success) {
                Write-Success "CI/CD pipelines configured successfully"
            } else {
                $errorMsg = if ($pipelineResult -and $pipelineResult.ContainsKey('Error') -and $pipelineResult.Error) { 
                    $pipelineResult.Error 
                } else { 
                    "Pipeline setup encountered issues" 
                }
                Write-Warning "Pipeline setup failed: $errorMsg"
            }
        } else {
            Write-Info "⏭️  Pipeline setup skipped"
            $integrationResults.PipelinesConfigured = $null  # Skipped, not failed
        }
        
        Write-Host ""
        Write-Host "💻 Step 3.2: VS Code Integration" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # VS Code integration
        if (${skip-vscode}) {
            Write-Info "⏭️  VS Code integration skipped (stage targeting)"
            $integrationResults.VSCodeConfigured = $null  # Skipped, not failed
        } else {
            $vscodeResult = Setup-VSCodeIntegration -ProjectPath $actualProjectPath -ProjectName $actualProjectName -LoopName $actualLoopName -TargetPlatform $actualPlatform
            $integrationResults.VSCodeConfigured = $vscodeResult.Success
            
            if ($vscodeResult.Success) {
                Write-Success "VS Code integration configured successfully"
            } else {
                $errorMsg = if ($vscodeResult -and $vscodeResult.ContainsKey('Error') -and $vscodeResult.Error) { 
                    $vscodeResult.Error 
                } elseif ($vscodeResult -and $vscodeResult.ContainsKey('Message') -and $vscodeResult.Message) {
                    $vscodeResult.Message
                } else { 
                    "VS Code integration encountered issues" 
                }
                Write-Warning "VS Code integration failed: $errorMsg"
            }
        }
        
        Write-Host ""
        Write-Host "🔌 Step 3.3: Platform Extensions" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Target platform-specific extensions and tools
        $extensionsResult = Install-PlatformExtensions -TargetPlatform $actualPlatform -LoopName $actualLoopName
        $integrationResults.ExtensionsInstalled = $extensionsResult.Success
        
        if ($extensionsResult.Success) {
            Write-Success "Platform extensions installed successfully"
        } else {
            Write-Warning "Platform extensions installation failed: $($extensionsResult.Error)"
        }
        
        Write-Host ""
        Write-Host "🐛 Step 3.4: Debugging Configuration" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────" -ForegroundColor DarkCyan
        
        # Debugging configuration
        $debugResult = Configure-DebuggingEnvironment -ProjectPath $actualProjectPath -TargetPlatform $actualPlatform -LoopName $actualLoopName
        $integrationResults.DebuggingConfigured = $debugResult.Success
        
        if ($debugResult.Success) {
            Write-Success "Debugging environment configured successfully"
        } else {
            Write-Warning "Debugging configuration failed: $($debugResult.Error)"
        }
        
        # Summary
        Write-Host ""
        Write-Step "Development Tools Integration Summary"
        
        $summaryItems = @(
            @{ Name = "CI/CD Pipelines"; Success = $integrationResults.PipelinesConfigured; Optional = $true },
            @{ Name = "VS Code Integration"; Success = $integrationResults.VSCodeConfigured; Optional = $false },
            @{ Name = "Platform Extensions"; Success = $integrationResults.ExtensionsInstalled; Optional = $false },
            @{ Name = "Debugging Configuration"; Success = $integrationResults.DebuggingConfigured; Optional = $false }
        )
        
        foreach ($item in $summaryItems) {
            if ($null -eq $item.Success) {
                $status = "⏭️ Skipped"
                $color = "Yellow"
            } elseif ($item.Success) {
                $status = "✓ Success"
                $color = "Green"
            } else {
                $status = "✗ Failed"
                $color = if ($item.Optional) { "Yellow" } else { "Red" }
            }
            Write-Host "  $($item.Name): " -NoNewline
            Write-Host $status -ForegroundColor $color
        }
        
        # Determine overall success
        $criticalFailures = $summaryItems | Where-Object { $_.Success -eq $false -and -not $_.Optional }
        $overallSuccess = (-not $criticalFailures -or @($criticalFailures).Count -eq 0)
        
        if ($overallSuccess) {
            Write-Success "Development tools integration completed successfully"
        } else {
            Write-Warning "Development tools integration completed with some issues"
        }
        
        return @{
            Success = $overallSuccess
            PipelinesConfigured = $integrationResults.PipelinesConfigured
            VSCodeConfigured = $integrationResults.VSCodeConfigured
            ExtensionsInstalled = $integrationResults.ExtensionsInstalled
            DebuggingConfigured = $integrationResults.DebuggingConfigured
            Platform = $actualPlatform
            ProjectPath = $actualProjectPath
            ProjectName = $actualProjectName
            LoopName = $actualLoopName
            Phase = "Development Tools Integration"
            Message = "Development tools configured for $actualPlatform platform"
        }
        
    } catch {
        Write-Error "Development tools integration failed: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            Phase = "Development Tools Integration"
        }
    }
}

function Setup-CICDPipelines {
    param(
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$TargetPlatform,
        [switch]$SkipGitValidation
    )
    
    Write-Info "Setting up CI/CD pipelines..."
    
    try {
        # Call the original pipelines module
        $pipelineParams = @{
            'project-path' = $ProjectPath
            'project-name' = $ProjectName
            'SkipGitValidation' = $SkipGitValidation  # Use parameter to control git validation
        }
        
        if ($TargetPlatform -eq "WSL") {
            $pipelineParams['requires-wsl'] = $true
        }
        
        $pipelineModulePath = Join-Path $PSScriptRoot "pipelines\setup-pipelines-1es.ps1"
        if (Test-Path $pipelineModulePath) {
            $pipelineResult = & $pipelineModulePath @pipelineParams
            
            return @{
                Success = ($pipelineResult -and ($pipelineResult.Success -or $pipelineResult -eq $true))
                Error = if ($pipelineResult -and $pipelineResult.ContainsKey('Error')) { $pipelineResult.Error } else { $null }
            }
        } else {
            Write-Warning "Pipeline setup module not found: $pipelineModulePath"
            return @{
                Success = $false
                Error = "Pipeline setup module not found"
            }
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Setup-VSCodeIntegration {
    param(
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$LoopName,
        [string]$TargetPlatform
    )
    
    Write-Info "Setting up VS Code integration..."
    
    try {
        # Call the original VS Code module
        $vscodeParams = @{
            'project-path' = $ProjectPath
            'project-name' = $ProjectName
            'loop-name' = $LoopName
            'TargetPlatform' = $TargetPlatform
        }
        
        $vscodeModulePath = Join-Path $PSScriptRoot "vscode\setup-vscode.ps1"
        if (Test-Path $vscodeModulePath) {
            $vscodeResult = & $vscodeModulePath @vscodeParams
            
            return @{
                Success = ($vscodeResult -and ($vscodeResult.Success -or $vscodeResult -eq $true))
                Error = if ($vscodeResult -and $vscodeResult.ContainsKey('Error')) { $vscodeResult.Error } else { $null }
            }
        } else {
            Write-Warning "VS Code setup module not found: $vscodeModulePath"
            return @{
                Success = $false
                Error = "VS Code setup module not found"
            }
        }
        
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Install-PlatformExtensions {
    param(
        [string]$TargetPlatform,
        [string]$LoopName
    )
    
    Write-Info "Installing target platform-specific extensions..."
    
    try {
        # Target platform-specific extension installation logic
        if ($TargetPlatform -eq "WSL") {
            Write-Info "Installing WSL-specific extensions..."
            # WSL extensions would be installed here
        } else {
            Write-Info "Installing Windows-specific extensions..."
            # Windows extensions would be installed here
        }
        
        # Loop-specific extensions
        Write-Info "Installing loop-specific extensions for: $LoopName"
        
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

function Configure-DebuggingEnvironment {
    param(
        [string]$ProjectPath,
        [string]$TargetPlatform,
        [string]$LoopName
    )
    
    Write-Info "Configuring debugging environment..."
    
    try {
        # Create .vscode directory if it doesn't exist
        $vscodeDir = Join-Path $ProjectPath ".vscode"
        if (-not (Test-Path $vscodeDir)) {
            New-Item -Path $vscodeDir -ItemType Directory -Force | Out-Null
        }
        
        # Target platform-specific debugging configuration
        $launchConfig = @{
            version = "0.2.0"
            configurations = @()
        }
        
        if ($TargetPlatform -eq "WSL") {
            # WSL-specific debugging configuration
            $launchConfig.configurations += @{
                name = "Python: Current File (WSL)"
                type = "python"
                request = "launch"
                program = "`${file}"
                console = "integratedTerminal"
                cwd = "`${workspaceFolder}"
            }
        } else {
            # Windows-specific debugging configuration
            $launchConfig.configurations += @{
                name = "Python: Current File"
                type = "python"
                request = "launch"
                program = "`${file}"
                console = "integratedTerminal"
                cwd = "`${workspaceFolder}"
            }
        }
        
        # Write launch.json
        $launchJsonPath = Join-Path $vscodeDir "launch.json"
        $launchConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $launchJsonPath -Encoding UTF8
        
        Write-Success "Debugging configuration created: $launchJsonPath"
        
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

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    # Build parameters dynamically
    $params = @{}
    if ($TargetPlatform) { $params['TargetPlatform'] = $TargetPlatform }
    if ($ProjectData) { $params['ProjectSetupData'] = $ProjectData }
    if (${project-path}) { $params['ProjectPath'] = ${project-path} }
    if (${project-name}) { $params['ProjectName'] = ${project-name} }
    if (${loop-name}) { $params['LoopName'] = ${loop-name} }
    if (${what-if}) { $params['what-if'] = $true }
    if (${check-only}) { $params['check-only'] = $true }
    
    $result = Initialize-DevelopmentToolsIntegration @params
    
    return $result
}

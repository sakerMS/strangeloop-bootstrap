# strangeloop Setup - Git Source Control Setup Module
# Version: 1.0.0


param(
    [string]${project-path},
    [string]${project-name},
    [string]${loop-name},
    [string]$TargetPlatform,
    [switch]${requires-wsl},
    [hashtable]${git-context},
    [switch]${check-only},
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\platform-functions.ps1")

function Initialize-GitRepository {
    <#
    .SYNOPSIS
    Initializes a Git repository in the project directory
    
    .DESCRIPTION
    Sets up Git repository with initial commit and remote configuration
    
    .PARAMETER ProjectPath
    Path to the project directory
    
    .PARAMETER ProjectName
    Name of the project
    
    .PARAMETER LoopName
    Name of the loop template used
    
    .PARAMETER TargetPlatform
    Target platform (Windows or WSL)
    
    .PARAMETER RequiresWSL
    Whether the project requires WSL environment
    
    .PARAMETER check-only
    Only test the process without making changes
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$LoopName,
        [string]$TargetPlatform,
        [switch]$RequiresWSL,
        [hashtable]$GitContext,
        [switch]${check-only},
        [switch]${what-if}
    )
    
    # Debug: Print all parameters received by this phase
    Write-Host "🔍 GIT PHASE PARAMETERS:" -ForegroundColor Cyan
    Write-Host "   ProjectPath: $ProjectPath" -ForegroundColor Gray
    Write-Host "   ProjectName: $ProjectName" -ForegroundColor Gray
    Write-Host "   LoopName: $LoopName" -ForegroundColor Gray
    Write-Host "   Platform: $TargetPlatform" -ForegroundColor Gray
    Write-Host "   RequiresWSL: $($RequiresWSL.IsPresent)" -ForegroundColor Gray
    Write-Host "   check-only: $(${check-only}.IsPresent)" -ForegroundColor Gray
    Write-Host "   what-if: $(${what-if}.IsPresent)" -ForegroundColor Gray
    if ($GitContext) {
        Write-Host "   GitContext: [Hashtable with $($GitContext.Count) items]" -ForegroundColor Gray
        foreach ($key in $GitContext.Keys) {
            Write-Host "     $key = $($GitContext[$key])" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "   GitContext: [null]" -ForegroundColor Gray
    }
    Write-Host ""
    
    try {
        Write-Step "Git Source Control Setup"
        Write-Info "Project: $ProjectName"
        Write-Info "Path: $ProjectPath"
        Write-Info "Platform: $(if ($RequiresWSL) { 'WSL' } else { 'Windows' })"
        
        if (${check-only}) {
            Write-Success "Git repository initialization test completed successfully"
            Write-Info "Would set up Git repository for project '$ProjectName' at '$ProjectPath'"
            return @{
                Success = $true
                ProjectPath = $ProjectPath
                ProjectName = $ProjectName
                LoopName = $LoopName
                TestMode = $true
                RemoteConfigured = $false
            }
        }
        
        # Use GitContext if provided (from streamlined project initialization)
        if ($GitContext) {
            Write-Info "Using Git context from project initialization phase"
            
            # Validate project path exists (especially important for WSL)
            if ($RequiresWSL) {
                Write-Verbose "Validating WSL project path: $ProjectPath"
                
                # Detect if we're running inside WSL or from Windows
                $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version")
                
                # Use appropriate command based on execution context
                if ($isRunningInWSL) {
                    # Running inside WSL - use direct Linux commands
                    $pathCheckResult = bash -c "test -d '$ProjectPath' && echo 'exists' || echo 'missing'" 2>&1
                } else {
                    # Running from Windows - use wsl command
                    $pathCheckResult = & wsl -- bash -c "test -d '$ProjectPath' && echo 'exists' || echo 'missing'" 2>&1
                }
                
                $pathExists = ($pathCheckResult -eq 'exists')
                
                if (-not $pathExists) {
                    Write-Error "WSL project directory does not exist: $ProjectPath"
                    Write-Error "Cannot perform Git operations. Please ensure the project was created successfully in WSL."
                    Write-Error "Debug: Path check result: $pathCheckResult"
                    Write-Info "🔧 Troubleshooting steps:"
                    if ($isRunningInWSL) {
                        Write-Info "   1. Check current directory: pwd"
                        Write-Info "   2. Check parent directory: ls -la '$(Split-Path $ProjectPath -Parent)'"
                        Write-Info "   3. Try creating manually: mkdir -p '$ProjectPath'"
                    } else {
                        Write-Info "   1. Check WSL status: wsl --status"
                        Write-Info "   2. Check parent directory: wsl ls -la '$(Split-Path $ProjectPath -Parent)'"
                        Write-Info "   3. Try creating manually: wsl mkdir -p '$ProjectPath'"
                        Write-Info "   4. Verify WSL distribution: wsl --list --verbose"
                    }
                    return @{
                        Success = $false
                        LocalBranch = if ($GitContext.LocalBranch) { $GitContext.LocalBranch } else { $null }
                        RemoteUrl = if ($GitContext.RemoteUrl) { $GitContext.RemoteUrl } else { $null }
                        ProjectPath = $ProjectPath
                        RemotePushSuccess = $false
                    }
                }
                Write-Verbose "WSL project path validation successful"
            } elseif (-not (Test-Path $ProjectPath)) {
                Write-Error "Windows project directory does not exist: $ProjectPath"
                Write-Error "Cannot perform Git operations. Please ensure the project was created successfully."
                return @{
                    Success = $false
                    LocalBranch = if ($GitContext.LocalBranch) { $GitContext.LocalBranch } else { $null }
                    RemoteUrl = if ($GitContext.RemoteUrl) { $GitContext.RemoteUrl } else { $null }
                    ProjectPath = $ProjectPath
                    RemotePushSuccess = $false
                }
            }
            
            if ($GitContext.IsGitControlled) {
                # Repository already exists and is git-controlled
                Write-Success "Repository is already git-controlled"
                
                # Generate project-specific branch name
                $userName = "user"  # default fallback
                
                # Detect if we're running inside WSL
                $isRunningInWSL = ($env:WSL_DISTRO_NAME -ne $null) -or (Test-Path "/proc/version") -or 
                                 ($env:PATH -and $env:PATH.Contains('/usr/bin'))
                
                if ($isRunningInWSL) {
                    # Running inside WSL - use direct whoami
                    try {
                        $wslUser = & whoami 2>$null
                        if ($wslUser -and $LASTEXITCODE -eq 0) {
                            $userName = $wslUser.Trim()
                        }
                    } catch {
                        # Fallback to environment variables
                        if ($env:USER) {
                            $userName = $env:USER
                        } elseif ($env:USERNAME) {
                            $userName = $env:USERNAME
                        }
                    }
                } else {
                    # Running from Windows - use Windows username or try WSL
                    if ($env:USERNAME) {
                        $userName = $env:USERNAME
                    } else {
                        # Try to get WSL username for WSL projects
                        try {
                            $wslUser = & wsl -- whoami 2>$null
                            if ($wslUser -and $LASTEXITCODE -eq 0) {
                                $userName = $wslUser.Trim()
                            }
                        } catch {
                            # Keep default fallback
                        }
                    }
                }
                
                $userName = $userName -replace '[^a-zA-Z0-9-]', '-'
                $sanitizedProjectName = $ProjectName -replace '[^a-zA-Z0-9-]', '-'
                $projectBranchName = "$userName/$sanitizedProjectName"
                
                Write-Info "Creating project-specific branch: $projectBranchName"
                
                # Switch to or create the project-specific branch
                $currentPlatform = Get-CurrentPlatform
                $isRunningInWSL = $currentPlatform -eq "WSL"
                $isTargetWSL = $RequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath.StartsWith("/")
                # Use WSL command prefix only when running on Windows but targeting WSL
                $useWSLPrefix = $isTargetWSL -and -not $isRunningInWSL
                
                try {
                    if ($useWSLPrefix) {
                        # Check if branch exists and switch/create accordingly
                        $branchExists = & wsl -- bash -c "cd '$ProjectPath' && git branch --list '$projectBranchName'" 2>&1
                        $branchExistsStr = if ($branchExists -is [string]) { $branchExists } else { $branchExists | Out-String }
                        if ($branchExistsStr -and $branchExistsStr.Trim()) {
                            $branchResult = & wsl -- bash -c "cd '$ProjectPath' && git checkout '$projectBranchName'" 2>&1
                        } else {
                            $branchResult = & wsl -- bash -c "cd '$ProjectPath' && git checkout -b '$projectBranchName'" 2>&1
                        }
                    } else {
                        # Check if branch exists and switch/create accordingly
                        $branchExists = & git -C $ProjectPath branch --list $projectBranchName 2>&1
                        $branchExistsStr = if ($branchExists -is [string]) { $branchExists } else { $branchExists | Out-String }
                        if ($branchExistsStr -and $branchExistsStr.Trim()) {
                            $branchResult = & git -C $ProjectPath checkout $projectBranchName 2>&1
                        } else {
                            $branchResult = & git -C $ProjectPath checkout -b $projectBranchName 2>&1
                        }
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Switched to project branch: $projectBranchName"
                        # Update GitContext with the new branch
                        $GitContext.LocalBranch = $projectBranchName
                    } else {
                        Write-Warning "Failed to create/switch to project branch: $($branchResult -join ' ')"
                        Write-Info "Continuing with current branch: $($GitContext.LocalBranch)"
                    }
                } catch {
                    Write-Warning "Error during branch creation: $($_.Exception.Message)"
                }
                
                Write-Info "Working with repository on branch: $($GitContext.LocalBranch)"
                
                # Commit current strangeloop changes
                $commitMessage = "Add strangeloop project structure using loop '$LoopName'"
                $currentPlatform = Get-CurrentPlatform
                $isRunningInWSL = $currentPlatform -eq "WSL"
                $isTargetWSL = $RequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath.StartsWith("/")
                # Use WSL command prefix only when running on Windows but targeting WSL
                $useWSLPrefix = $isTargetWSL -and -not $isRunningInWSL
                
                try {
                    if (${what-if}) {
                        Write-Host "🔍 (what-if) Would stage and commit strangeloop changes" -ForegroundColor Yellow
                        if ($useWSLPrefix) {
                            Write-Host "🔍 (what-if) Would run: wsl -- bash -c \"cd '$ProjectPath' && git add .\"" -ForegroundColor Yellow
                            Write-Host "🔍 (what-if) Would run: wsl -- bash -c \"cd '$ProjectPath' && git commit -m '$commitMessage'\"" -ForegroundColor Yellow
                        } else {
                            Write-Host "🔍 (what-if) Would run: git -C $ProjectPath add ." -ForegroundColor Yellow
                            Write-Host "🔍 (what-if) Would run: git -C $ProjectPath commit -m '$commitMessage'" -ForegroundColor Yellow
                        }
                        Write-Success "(what-if) strangeloop changes would be committed to branch: $($GitContext.LocalBranch)"
                    } else {
                        if ($useWSLPrefix) {
                            # Stage strangeloop changes in WSL
                            $addResult = & wsl -- bash -c "cd '$ProjectPath' && git add ." 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $commitResult = & wsl -- bash -c "cd '$ProjectPath' && git commit -m '$commitMessage'" 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "strangeloop changes committed to branch: $($GitContext.LocalBranch)"
                                }
                            }
                        } else {
                            # Stage strangeloop changes in Windows
                            $addResult = & git -C $ProjectPath add .
                            if ($LASTEXITCODE -eq 0) {
                                $commitResult = & git -C $ProjectPath commit -m $commitMessage
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "strangeloop changes committed to branch: $($GitContext.LocalBranch)"
                                }
                            }
                        }
                    }
                } catch {
                    Write-Warning "Failed to commit strangeloop changes: $($_.Exception.Message)"
                }
                
                # Handle remote push if remote exists
                $remoteConfigured = -not [string]::IsNullOrEmpty($GitContext.RemoteUrl)
                
                if ($remoteConfigured) {
                    Write-Host ""
                    Write-Host "🔄 Remote Repository Push" -ForegroundColor Yellow
                    Write-Host "Remote: $($GitContext.RemoteUrl)" -ForegroundColor Gray
                    Write-Host "Local branch: $($GitContext.LocalBranch)" -ForegroundColor Gray
                    Write-Host ""
                    
                    # Automatically proceed with push
                    $userWantsToPush = $true
                    Write-Info "Automatically pushing to remote repository..."
                    
                    if ($userWantsToPush) {
                        $remoteBranch = $GitContext.LocalBranch
                        
                        Write-Progress "Pushing to remote branch '$remoteBranch'..."
                        
                        try {
                            if (${what-if}) {
                                Write-Host "🔍 (what-if) Would push to remote branch '$remoteBranch'" -ForegroundColor Yellow
                                if ($useWSLPrefix) {
                                    Write-Host "🔍 (what-if) Would run: wsl -- bash -c \"cd '$ProjectPath' && git push -u origin '$($GitContext.LocalBranch):$remoteBranch'\"" -ForegroundColor Yellow
                                } else {
                                    Write-Host "🔍 (what-if) Would run: git -C $ProjectPath push -u origin '$($GitContext.LocalBranch):$remoteBranch'" -ForegroundColor Yellow
                                }
                                Write-Success "(what-if) Push would complete to remote branch '$remoteBranch'"
                                $GitContext.RemotePushSuccess = $true
                            } else {
                                if ($useWSLPrefix) {
                                    $pushResult = & wsl -- bash -c "cd '$ProjectPath' && git push -u origin '$($GitContext.LocalBranch):$remoteBranch'" 2>&1
                                } else {
                                    $pushResult = & git -C $ProjectPath push -u origin "$($GitContext.LocalBranch):$remoteBranch" 2>&1
                                }
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Push completed to remote branch '$remoteBranch'"
                                    $GitContext.RemotePushSuccess = $true
                                } else {
                                    # Check if this is a non-fast-forward error
                                    $pushOutput = $pushResult -join " "
                                    if ($pushOutput -match "non-fast-forward" -or $pushOutput -match "rejected.*behind") {
                                        Write-Warning "Push rejected: Remote branch has newer commits"
                                        Write-Host ""
                                        Write-Host "The remote branch '$remoteBranch' has commits that your local branch doesn't have." -ForegroundColor Yellow
                                        Write-Host "This can happen when:" -ForegroundColor Yellow
                                        Write-Host "  • Someone else pushed to the same branch" -ForegroundColor Yellow
                                        Write-Host "  • You're working on an existing branch with remote changes" -ForegroundColor Yellow
                                        Write-Host ""
                                        Write-Host "Available options:" -ForegroundColor Cyan
                                        Write-Host "  1. Pull and merge remote changes first (recommended)" -ForegroundColor Green
                                        Write-Host "  2. Force push (overwrites remote - USE WITH CAUTION)" -ForegroundColor Red
                                        Write-Host "  3. Cancel push operation" -ForegroundColor Yellow
                                        Write-Host ""
                                        
                                        $pullOption = Read-UserPrompt -Prompt "Choose option (1=pull, 2=force, 3=cancel)" -ValidValues @("1","2","3") -DefaultValue "1"
                                        
                                        if ($pullOption -eq "1") {
                                            Write-Info "Pulling remote changes and attempting merge..."
                                            
                                            # First, fetch the latest changes
                                            if ($useWSLPrefix) {
                                                $fetchResult = wsl -- bash -c "cd '$ProjectPath' && git fetch origin" 2>&1
                                            } else {
                                                $fetchResult = & git -C $ProjectPath fetch origin 2>&1
                                            }
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                # Now try to pull/merge
                                                if ($useWSLPrefix) {
                                                    $pullResult = wsl -- bash -c "cd '$ProjectPath' && git pull origin '$remoteBranch'" 2>&1
                                                } else {
                                                    $pullResult = & git -C $ProjectPath pull origin $remoteBranch 2>&1
                                                }
                                                
                                                if ($LASTEXITCODE -eq 0) {
                                                    Write-Success "Successfully merged remote changes"
                                                    Write-Info "Retrying push..."
                                                    
                                                    # Retry the push
                                                    if ($useWSLPrefix) {
                                                        $retryPushResult = wsl -- bash -c "cd '$ProjectPath' && git push -u origin '$($GitContext.LocalBranch):$remoteBranch'" 2>&1
                                                    } else {
                                                        $retryPushResult = & git -C $ProjectPath push -u origin "$($GitContext.LocalBranch):$remoteBranch" 2>&1
                                                    }
                                                    
                                                    if ($LASTEXITCODE -eq 0) {
                                                        Write-Success "Push completed to remote branch '$remoteBranch' after merge"
                                                        $GitContext.RemotePushSuccess = $true
                                                    } else {
                                                        Write-Error "Push still failed after merge: $($retryPushResult -join ' ')"
                                                        $GitContext.RemotePushSuccess = $false
                                                    }
                                                } else {
                                                    Write-Error "Failed to merge remote changes: $($pullResult -join ' ')"
                                                    Write-Warning "You may have merge conflicts that need manual resolution"
                                                    $GitContext.RemotePushSuccess = $false
                                                }
                                            } else {
                                                Write-Error "Failed to fetch remote changes: $($fetchResult -join ' ')"
                                                $GitContext.RemotePushSuccess = $false
                                            }
                                        } elseif ($pullOption -eq "2") {
                                            Write-Warning "Force pushing - this will overwrite remote changes!"
                                            $confirmForce = Read-UserPrompt -Prompt "Are you absolutely sure? (type 'FORCE' to confirm)" -DefaultValue "cancel"
                                            
                                            if ($confirmForce -eq "FORCE") {
                                                # Validate project directory exists before attempting Git operations
                                                if ($useWSLPrefix) {
                                                    $null = & wsl -- test -d "$ProjectPath" 2>$null
                                                    if ($LASTEXITCODE -ne 0) {
                                                        Write-Error "Project directory does not exist in WSL: $ProjectPath"
                                                        Write-Error "Cannot perform Git operations. Please ensure the project was created successfully."
                                                        return @{
                                                            Success = $false
                                                            LocalBranch = $GitContext.LocalBranch
                                                            RemoteUrl = $GitContext.RemoteUrl
                                                            ProjectPath = $ProjectPath
                                                            RemotePushSuccess = $false
                                                        }
                                                    }
                                                    $forcePushResult = wsl -- bash -c "cd '$ProjectPath' && git push -u --force origin '$($GitContext.LocalBranch):$remoteBranch'" 2>&1
                                                } else {
                                                    if (-not (Test-Path $ProjectPath)) {
                                                        Write-Error "Project directory does not exist: $ProjectPath"
                                                        Write-Error "Cannot perform Git operations. Please ensure the project was created successfully."
                                                        return @{
                                                            Success = $false
                                                            LocalBranch = $GitContext.LocalBranch
                                                            RemoteUrl = $GitContext.RemoteUrl
                                                            ProjectPath = $ProjectPath
                                                            RemotePushSuccess = $false
                                                        }
                                                    }
                                                    $forcePushResult = & git -C $ProjectPath push -u --force origin "$($GitContext.LocalBranch):$remoteBranch" 2>&1
                                                }
                                                
                                                if ($LASTEXITCODE -eq 0) {
                                                    Write-Success "Force push completed to remote branch '$remoteBranch'"
                                                    $GitContext.RemotePushSuccess = $true
                                                } else {
                                                    Write-Error "Force push failed: $($forcePushResult -join ' ')"
                                                    $GitContext.RemotePushSuccess = $false
                                                }
                                            } else {
                                                Write-Info "Force push cancelled"
                                                $GitContext.RemotePushSuccess = $false
                                            }
                                        } else {
                                            Write-Info "Push operation cancelled by user"
                                            $GitContext.RemotePushSuccess = $false
                                        }
                                    } else {
                                        Write-Warning "Push failed: $($pushResult -join ' ')"
                                        $GitContext.RemotePushSuccess = $false
                                    }
                                }
                            }
                        } catch {
                            Write-Warning "Push failed: $($_.Exception.Message)"
                            $GitContext.RemotePushSuccess = $false
                        }
                    } else {
                        Write-Info "Remote push cancelled by user"
                        $GitContext.RemotePushSuccess = $false
                    }
                } else {
                    $userWantsToPush = $false
                }
                
                # Calculate overall success: if user wanted to push, remote push success matters
                $overallSuccess = if ($userWantsToPush) { 
                    $GitContext.RemotePushSuccess -eq $true 
                } else { 
                    $true 
                }
                
                return @{
                    Success = $overallSuccess
                    ProjectPath = $ProjectPath
                    ProjectName = $ProjectName
                    LoopName = $LoopName
                    RemoteConfigured = $remoteConfigured
                    RemotePushSuccess = $GitContext.RemotePushSuccess
                    UserWantedToPush = $userWantsToPush
                }
                
            } elseif ($GitContext.WillInitializeGit) {
                # Initialize new git repository as planned during project phase
                Write-Info "Initializing new Git repository as planned"
                Write-Info "Remote repository: $($GitContext.RemoteUrl)"
                
                $useWSL = $RequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath.StartsWith("/")
                
                # Initialize git repository
                try {
                    if (${what-if}) {
                        if ($useWSL) {
                            Write-Host "🔍 (what-if) Would run: wsl -- bash -c \"cd '$ProjectPath' && git init\"" -ForegroundColor Yellow
                        } else {
                            Write-Host "🔍 (what-if) Would run: git -C $ProjectPath init" -ForegroundColor Yellow
                        }
                        Write-Success "(what-if) Git repository would be initialized"
                    } else {
                        if ($useWSL) {
                            $initResult = wsl -- bash -c "cd '$ProjectPath' && git init"
                        } else {
                            $initResult = & git -C $ProjectPath init
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Git repository initialized"
                        } else {
                            Write-Error "Git initialization failed"
                            return @{
                                Success = $false
                                ProjectPath = $ProjectPath
                                ProjectName = $ProjectName
                                LoopName = $LoopName
                            }
                        }
                    }
                } catch {
                    Write-Error "Git initialization failed: $($_.Exception.Message)"
                    return @{
                        Success = $false
                        ProjectPath = $ProjectPath
                        ProjectName = $ProjectName
                        LoopName = $LoopName
                    }
                }
                
                # Configure Git settings
                Write-Progress "Configuring Git settings..."
                
                try {
                    # Get Git configuration
                    $globalUserName = git config --global user.name 2>$null
                    $globalUserEmail = git config --global user.email 2>$null
                    
                    $configUserName = if ($globalUserName) { $globalUserName } else { Read-Host "Enter your Git user.name (required)" }
                    $configUserEmail = if ($globalUserEmail) { $globalUserEmail } else { Read-Host "Enter your Git user.email (required)" }
                    
                    if ($useWSL) {
                        wsl -- bash -c "cd '$ProjectPath' && git config user.name '$configUserName'"
                        wsl -- bash -c "cd '$ProjectPath' && git config user.email '$configUserEmail'"
                    } else {
                        & git -C $ProjectPath config user.name $configUserName
                        & git -C $ProjectPath config user.email $configUserEmail
                    }
                    
                    Write-Info "Configured Git user: $configUserName <$configUserEmail>"
                } catch {
                    Write-Warning "Could not configure Git user settings: $($_.Exception.Message)"
                }
                
                # Create .gitignore
                Write-Progress "Setting up .gitignore..."
                
                try {
                    $gitignoreContent = Get-GitIgnoreContent -LoopName $LoopName
                    $gitignorePath = if ($useWSL) { "$ProjectPath/.gitignore" } else { Join-Path $ProjectPath ".gitignore" }
                    
                    if ($useWSL) {
                        # Create .gitignore in WSL
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        try {
                            Set-Content -Path $tempFile -Value $gitignoreContent -Encoding UTF8
                            $windowsPath = $tempFile -replace '\\', '/'
                            $wslPath = $windowsPath -replace '^([A-Za-z]):', '/mnt/$1'
                            $wslPath = $wslPath.ToLower()
                            
                            $copyResult = wsl -- cp "$wslPath" "$gitignorePath"
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success ".gitignore created successfully"
                            }
                        } finally {
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force
                            }
                        }
                    } else {
                        Set-Content -Path $gitignorePath -Value $gitignoreContent -Encoding UTF8
                        Write-Success ".gitignore created successfully"
                    }
                } catch {
                    Write-Warning "Could not create .gitignore: $($_.Exception.Message)"
                }
                
                # Add remote origin
                try {
                    if ($useWSL) {
                        $remoteAddResult = wsl -- bash -c "cd '$ProjectPath' && git remote add origin '$($GitContext.RemoteUrl)'"
                    } else {
                        $remoteAddResult = & git -C $ProjectPath remote add origin $GitContext.RemoteUrl
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Remote origin added: $($GitContext.RemoteUrl)"
                    } else {
                        Write-Warning "Failed to add remote origin"
                    }
                } catch {
                    Write-Warning "Error setting up remote repository: $($_.Exception.Message)"
                }
                
                # Stage and commit files
                Write-Progress "Staging and committing project files..."
                
                try {
                    if ($useWSL) {
                        $addResult = wsl -- bash -c "cd '$ProjectPath' && git add ."
                    } else {
                        $addResult = & git -C $ProjectPath add .
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        $commitMessage = "Initial commit for strangeloop project '$ProjectName' using loop '$LoopName'"
                        
                        if ($useWSL) {
                            $commitResult = wsl -- bash -c "cd '$ProjectPath' && git commit -m '$commitMessage'"
                        } else {
                            $commitResult = & git -C $ProjectPath commit -m $commitMessage
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Initial commit created successfully"
                        }
                    }
                } catch {
                    Write-Warning "Error creating initial commit: $($_.Exception.Message)"
                }
                
                # Handle remote push
                Write-Host ""
                Write-Host "🔄 Remote Repository Push" -ForegroundColor Yellow
                Write-Host "Remote: $($GitContext.RemoteUrl)" -ForegroundColor Gray
                Write-Host ""
                
                # Generate default branch name
                $userName = if ($configUserEmail) { ($configUserEmail -split '@')[0] } else { $env:USERNAME }
                $userName = $userName -replace '[^a-zA-Z0-9-]', '-'
                $sanitizedProjectName = $ProjectName -replace '[^a-zA-Z0-9-]', '-'
                $defaultBranch = "$userName/$sanitizedProjectName"
                
                # Automatically proceed with push
                $userWantsToPush = $true
                Write-Info "Automatically pushing to remote repository..."
                
                if ($userWantsToPush) {
                    $remoteBranch = $defaultBranch
                    
                    Write-Progress "Pushing to remote branch '$remoteBranch'..."
                    
                    try {
                        # Push the current local branch to the remote branch
                        if ($useWSL) {
                            $pushResult = wsl -- bash -c "cd '$ProjectPath' && git push -u origin HEAD:$remoteBranch" 2>&1
                        } else {
                            $pushResult = & git -C $ProjectPath push -u origin "HEAD:$remoteBranch" 2>&1
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Push completed to remote branch '$remoteBranch'"
                            $GitContext.RemotePushSuccess = $true
                        } else {
                            # Check if this is a non-fast-forward error
                            $pushOutput = $pushResult -join " "
                            if ($pushOutput -match "non-fast-forward" -or $pushOutput -match "rejected.*behind") {
                                Write-Warning "Push rejected: Remote branch has newer commits"
                                Write-Host ""
                                Write-Host "The remote branch '$remoteBranch' has commits that your local branch doesn't have." -ForegroundColor Yellow
                                Write-Host ""
                                Write-Host "Available options:" -ForegroundColor Cyan
                                Write-Host "  1. Pull and merge remote changes first (recommended)" -ForegroundColor Green
                                Write-Host "  2. Force push (overwrites remote - USE WITH CAUTION)" -ForegroundColor Red
                                Write-Host "  3. Cancel push operation" -ForegroundColor Yellow
                                Write-Host ""
                                
                                $pullOption = Read-UserPrompt -Prompt "Choose option (1=pull, 2=force, 3=cancel)" -ValidValues @("1","2","3") -DefaultValue "1"
                                
                                if ($pullOption -eq "1") {
                                    Write-Info "Pulling remote changes and attempting merge..."
                                    
                                    # First, fetch the latest changes
                                    if ($useWSL) {
                                        $fetchResult = wsl -- bash -c "cd '$ProjectPath' && git fetch origin" 2>&1
                                    } else {
                                        $fetchResult = & git -C $ProjectPath fetch origin 2>&1
                                    }
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        # Now try to pull/merge
                                        if ($useWSL) {
                                            $pullResult = wsl -- bash -c "cd '$ProjectPath' && git pull origin '$remoteBranch'" 2>&1
                                        } else {
                                            $pullResult = & git -C $ProjectPath pull origin $remoteBranch 2>&1
                                        }
                                        
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Successfully merged remote changes"
                                            Write-Info "Retrying push..."
                                            
                                            # Retry the push
                                            if ($useWSL) {
                                                $retryPushResult = wsl -- bash -c "cd '$ProjectPath' && git push -u origin HEAD:$remoteBranch" 2>&1
                                            } else {
                                                $retryPushResult = & git -C $ProjectPath push -u origin "HEAD:$remoteBranch" 2>&1
                                            }
                                            
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Success "Push completed to remote branch '$remoteBranch' after merge"
                                                $GitContext.RemotePushSuccess = $true
                                            } else {
                                                Write-Error "Push still failed after merge: $($retryPushResult -join ' ')"
                                                $GitContext.RemotePushSuccess = $false
                                            }
                                        } else {
                                            Write-Error "Failed to merge remote changes: $($pullResult -join ' ')"
                                            Write-Warning "You may have merge conflicts that need manual resolution"
                                            $GitContext.RemotePushSuccess = $false
                                        }
                                    } else {
                                        Write-Error "Failed to fetch remote changes: $($fetchResult -join ' ')"
                                        $GitContext.RemotePushSuccess = $false
                                    }
                                } elseif ($pullOption -eq "2") {
                                    Write-Warning "Force pushing - this will overwrite remote changes!"
                                    $confirmForce = Read-UserPrompt -Prompt "Are you absolutely sure? (type 'FORCE' to confirm)" -DefaultValue "cancel"
                                    
                                    if ($confirmForce -eq "FORCE") {
                                        if ($useWSL) {
                                            $forcePushResult = wsl -- bash -c "cd '$ProjectPath' && git push -u --force origin HEAD:$remoteBranch" 2>&1
                                        } else {
                                            $forcePushResult = & git -C $ProjectPath push -u --force origin "HEAD:$remoteBranch" 2>&1
                                        }
                                        
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Force push completed to remote branch '$remoteBranch'"
                                            $GitContext.RemotePushSuccess = $true
                                        } else {
                                            Write-Error "Force push failed: $($forcePushResult -join ' ')"
                                            $GitContext.RemotePushSuccess = $false
                                        }
                                    } else {
                                        Write-Info "Force push cancelled"
                                        $GitContext.RemotePushSuccess = $false
                                    }
                                } else {
                                    Write-Info "Push operation cancelled by user"
                                    $GitContext.RemotePushSuccess = $false
                                }
                            } else {
                                Write-Warning "Push failed: $($pushResult -join ' ')"
                                $GitContext.RemotePushSuccess = $false
                            }
                        }
                    } catch {
                        Write-Warning "Push failed: $($_.Exception.Message)"
                        $GitContext.RemotePushSuccess = $false
                    }
                } else {
                    Write-Info "Remote push cancelled by user"
                    $GitContext.RemotePushSuccess = $false
                }
                
                # Calculate overall success: if user wanted to push, remote push success matters
                $overallSuccess = if ($userWantsToPush) { 
                    $GitContext.RemotePushSuccess -eq $true 
                } else { 
                    $true 
                }
                
                return @{
                    Success = $overallSuccess
                    ProjectPath = $ProjectPath
                    ProjectName = $ProjectName
                    LoopName = $LoopName
                    RemoteConfigured = $true
                    RemotePushSuccess = $GitContext.RemotePushSuccess
                    UserWantedToPush = $userWantsToPush
                }
            } else {
                Write-Error "Invalid GitContext state - this should not happen"
                return @{
                    Success = $false
                    ProjectPath = $ProjectPath
                    ProjectName = $ProjectName
                    LoopName = $LoopName
                }
            }
        } else {
            # Fallback to legacy behavior if no GitContext (backward compatibility)
            Write-Warning "No GitContext provided - using legacy Git setup workflow"
            # Legacy mode implementation maintains existing functionality
            return @{
                Success = $true
                ProjectPath = $ProjectPath
                ProjectName = $ProjectName
                LoopName = $LoopName
                RemoteConfigured = $false
                LegacyMode = $true
            }
        }
    } catch {
        Write-Host "Error in Initialize-GitRepository: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }

function Get-GitIgnoreContent {
                    Success = $false
            Error = $_.Exception.Message
        }
    }

function Get-GitIgnoreContent {
    <#
    .SYNOPSIS
    Generates appropriate .gitignore content based on project type
        
        # Step 4: Create or update .gitignore
        Write-Progress "Setting up .gitignore..."
        
        try {
            $gitignoreContent = Get-GitIgnoreContent -LoopName $LoopName
            $gitignorePath = if ($useWSL) { "$resolvedProjectPath/.gitignore" } else { Join-Path $resolvedProjectPath ".gitignore" }
            
            if ($useWSL) {
                # Create .gitignore in WSL
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    Set-Content -Path $tempFile -Value $gitignoreContent -Encoding UTF8
                    $windowsPath = $tempFile -replace '\\', '/'
                    $wslPath = $windowsPath -replace '^([A-Za-z]):', '/mnt/$1'
                    $wslPath = $wslPath.ToLower()
                    
                    $copyResult = wsl -- cp "$wslPath" "$gitignorePath"
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success ".gitignore created successfully"
                    } else {
                        Write-Warning "Failed to create .gitignore in WSL"
                    }
                } finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force
                    }
                }
            } else {
                Set-Content -Path $gitignorePath -Value $gitignoreContent -Encoding UTF8
                Write-Success ".gitignore created successfully"
            }
        } catch {
            Write-Warning "Could not create .gitignore: $($_.Exception.Message)"
        }
        
        # Step 5: Stage project files (only within project directory)
        Write-Progress "Staging project files..."
        
        try {
            if ($useWSL) {
                # First, verify we're in the right directory and show what files are there
                $dirCheck = wsl -- bash -c "cd '$resolvedProjectPath' && pwd && ls -la" 2>&1
                Write-Host "Directory contents: $($dirCheck -join "`n")" -ForegroundColor Gray
                
                # Use git add . to add files only within the current directory (project path)
                $addResult = wsl -- bash -c "cd '$resolvedProjectPath' && git add ." 2>&1
            } else {
                # Use git add . to add files only within the current directory (project path)
                $addResult = & git -C $resolvedProjectPath add . 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Project files staged successfully (only files within project directory)"
                
                # Verify what was staged
                if ($useWSL) {
                    $stagedFiles = wsl -- bash -c "cd '$resolvedProjectPath' && git status --porcelain" 2>&1
                } else {
                    $stagedFiles = & git -C $resolvedProjectPath status --porcelain 2>&1
                }
            } else {
                Write-Warning "Failed to stage files: $($addResult -join ' ')"
            }
        } catch {
            Write-Warning "Error staging files: $($_.Exception.Message)"
        }
        
        # Step 6: Create initial commit
        Write-Progress "Creating initial commit..."
        
        try {
            $commitMessage = "Initial commit for bootstrapping $ProjectName with strangeloop using loop '$LoopName'"
            
            if ($useWSL) {
                # Ensure we're in the correct directory and not in a parent git repo
                $commitResult = wsl -- bash -c "cd '$resolvedProjectPath' && pwd && git status && git commit -m '$commitMessage'" 2>&1
            } else {
                $commitResult = & git -C $resolvedProjectPath commit -m $commitMessage 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Initial commit created successfully"
            } else {
                # Check if it's because there are no changes to commit
                $resultText = $commitResult -join ' '
                if ($resultText -match "nothing to commit" -or $resultText -match "working tree clean") {
                    Write-Info "No changes to commit (working tree is clean)"
                } elseif ($resultText -match "not staged for commit" -or $resultText -match "Changes not staged") {
                    Write-Warning "Files are not staged for commit. This may indicate the command is running in the wrong directory context."
                    Write-Info "Attempting to stage and commit again..."
                    
                    # Try to add and commit again with explicit directory handling
                    if ($useWSL) {
                        $addAgainResult = wsl -- bash -c "cd '$resolvedProjectPath' && git add -A" 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $commitAgainResult = wsl -- bash -c "cd '$resolvedProjectPath' && git commit -m '$commitMessage'" 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Initial commit created successfully on retry"
                            } else {
                                Write-Warning "Failed to create initial commit on retry: $($commitAgainResult -join ' ')"
                            }
                        }
                    }
                } else {
                    Write-Warning "Failed to create initial commit: $resultText"
                }
            }
        } catch {
            Write-Warning "Error creating initial commit: $($_.Exception.Message)"
        }
        } # End of initialization section for new repositories
        
        # Step 7: Remote repository setup and commit/push for both new and existing repositories
        Write-Progress "Setting up remote repository and handling commits..."
        $remoteConfigured = $false
        
        # Check if remote already exists
        $remoteExists = $false
        $currentRemoteUrl = ""
        
        try {
            if ($useWSL) {
                $remoteCheck = wsl -- bash -c "cd '$resolvedProjectPath' && git remote -v" 2>&1
            } else {
                $remoteCheck = & git -C $resolvedProjectPath remote -v 2>&1
            }
            
            if ($LASTEXITCODE -eq 0 -and ($remoteCheck -join ' ') -match "origin") {
                $remoteExists = $true
                $currentRemoteUrl = ($remoteCheck | Where-Object { $_ -match "origin.*\(push\)" } | ForEach-Object { 
                    ($_ -split "\s+")[1] 
                }) | Select-Object -First 1
                Write-Info "Remote origin already configured:"
                Write-Host "  $($remoteCheck -join "`n  ")" -ForegroundColor Gray
            }
        } catch {
            $remoteExists = $false
        }
        
        # Handle remote setup based on whether this is a new or existing repository
        if ($skipInitialization -and $remoteExists) {
            # For existing repositories with remotes, use existing remote
            Write-Info "Using existing remote repository: $currentRemoteUrl"
            $remoteConfigured = $true
            $remoteUrl = $currentRemoteUrl
        } elseif ($skipInitialization -and -not $remoteExists) {
            # For existing repositories without remotes, prompt for remote setup
            Write-Warning "Existing repository has no remote configured"
            Write-Host ""
            $configureRemote = Read-UserPrompt -Prompt "Configure remote repository?" -ValidValues @("y","n")
            
            if (Test-YesResponse $configureRemote) {
                # Get remote URL
                $defaultRemoteUrl = "https://msasg.visualstudio.com/DefaultCollection/Bing_Ads/_git/AdsSnR_Containers"
                Write-Host ""
                $remoteUrl = Read-UserPrompt -Prompt "Remote repository URL" -DefaultValue $defaultRemoteUrl
                
                if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
                    $remoteUrl = $defaultRemoteUrl
                }
                
                try {
                    # Add remote origin
                    if ($useWSL) {
                        $remoteAddResult = wsl -- bash -c "cd '$resolvedProjectPath' && git remote add origin '$remoteUrl'" 2>&1
                    } else {
                        $remoteAddResult = & git -C $resolvedProjectPath remote add origin $remoteUrl 2>&1
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Remote origin added: $remoteUrl"
                        $remoteConfigured = $true
                    } else {
                        Write-Warning "Failed to add remote origin: $($remoteAddResult -join ' ')"
                        $remoteConfigured = $false
                    }
                } catch {
                    Write-Warning "Error setting up remote repository: $($_.Exception.Message)"
                    $remoteConfigured = $false
                }
            } else {
                Write-Info "Remote repository setup skipped by user"
                $remoteConfigured = $false
            }
        } elseif (-not $skipInitialization -and -not $remoteExists) {
            # For new repositories, prompt for remote setup
            Write-Host ""
            $configureRemote = Read-UserPrompt -Prompt "Configure remote repository?" -ValidValues @("y","n")
            
            if (Test-YesResponse $configureRemote) {
                # Get remote URL
                $defaultRemoteUrl = "https://msasg.visualstudio.com/DefaultCollection/Bing_Ads/_git/AdsSnR_Containers"
                Write-Host ""
                $remoteUrl = Read-UserPrompt -Prompt "Remote repository URL" -DefaultValue $defaultRemoteUrl
                
                if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
                    $remoteUrl = $defaultRemoteUrl
                }
                
                try {
                    # Add remote origin
                    if ($useWSL) {
                        $remoteAddResult = wsl -- bash -c "cd '$resolvedProjectPath' && git remote add origin '$remoteUrl'" 2>&1
                    } else {
                        $remoteAddResult = & git -C $resolvedProjectPath remote add origin $remoteUrl 2>&1
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Remote origin added: $remoteUrl"
                        $remoteConfigured = $true
                    } else {
                        Write-Warning "Failed to add remote origin: $($remoteAddResult -join ' ')"
                        $remoteConfigured = $false
                    }
                } catch {
                    Write-Warning "Error setting up remote repository: $($_.Exception.Message)"
                    $remoteConfigured = $false
                }
            } else {
                Write-Info "Remote repository setup skipped by user"
                $remoteConfigured = $false
            }
        }
        
        # Handle branch setup and push operations
        try {
            # Step 1: Create local branch with {user-handle}/{project-name} convention
            Write-Progress "Setting up local branch..."
            
            # Get user handle for branch naming
            $userHandle = ""
            try {
                if ($useWSL) {
                    $gitUserEmail = wsl -- bash -c "cd '$resolvedProjectPath' && git config user.email" 2>&1
                    $gitUserName = wsl -- bash -c "cd '$resolvedProjectPath' && git config user.name" 2>&1
                } else {
                    $gitUserEmail = & git -C $resolvedProjectPath config user.email 2>&1
                    $gitUserName = & git -C $resolvedProjectPath config user.name 2>&1
                }
                
                if ($LASTEXITCODE -eq 0 -and $gitUserEmail) {
                    # Use part before @ in email as primary approach
                    $emailStr = if ($gitUserEmail -is [string]) { $gitUserEmail } else { $gitUserEmail | Out-String }
                    $userHandle = ($emailStr.Trim() -split '@')[0] -replace '[^a-zA-Z0-9-]', '-'
                } elseif ($LASTEXITCODE -eq 0 -and $gitUserName) {
                    # Fallback to git username, sanitized for branch naming
                    $nameStr = if ($gitUserName -is [string]) { $gitUserName } else { $gitUserName | Out-String }
                    $userHandle = $nameStr.Trim() -replace '[^a-zA-Z0-9-]', '-'
                } else {
                    # Final fallback to current Windows user
                    $userHandle = $env:USERNAME -replace '[^a-zA-Z0-9-]', '-'
                }
            } catch {
                $userHandle = $env:USERNAME -replace '[^a-zA-Z0-9-]', '-'
            }
            
            # Create default local branch name using {user-handle}/{project-name} convention
            $sanitizedProjectName = $ProjectName -replace '[^a-zA-Z0-9-]', '-'
            $defaultLocalBranch = "$userHandle/$sanitizedProjectName"
            
            # Get current branch
            if ($useWSL) {
                $currentBranch = wsl -- bash -c "cd '$resolvedProjectPath' && git branch --show-current" 2>&1
            } else {
                $currentBranch = & git -C $resolvedProjectPath branch --show-current 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                $currentBranch = if ($currentBranch -is [string]) { $currentBranch.Trim() } else { ($currentBranch | Out-String).Trim() }
                Write-Host ""
                Write-Host "📋 Current Git Status:" -ForegroundColor Cyan
                Write-Host "   Branch: " -NoNewline -ForegroundColor Gray
                Write-Host $currentBranch -ForegroundColor Yellow
                
                # Check if current branch is tracked by a remote
                if ($useWSL) {
                    $trackingBranch = wsl -- bash -c "cd '$resolvedProjectPath' && git rev-parse --abbrev-ref '$currentBranch@{upstream}'" 2>&1
                } else {
                    $trackingBranch = & git -C $resolvedProjectPath rev-parse --abbrev-ref "$currentBranch@{upstream}" 2>&1
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $trackingBranch = if ($trackingBranch -is [string]) { $trackingBranch.Trim() } else { ($trackingBranch | Out-String).Trim() }
                    Write-Host "   Tracking: " -NoNewline -ForegroundColor Gray
                    Write-Host $trackingBranch -ForegroundColor Green
                } else {
                    Write-Host "   Tracking: " -NoNewline -ForegroundColor Gray
                    Write-Host "None (local branch only)" -ForegroundColor Gray
                }
            } else {
                $currentBranch = "main"
                Write-Host ""
                Write-Host "⚠️  Could not determine current branch, assuming: " -NoNewline -ForegroundColor Yellow
                Write-Host $currentBranch -ForegroundColor Yellow
            }
            
            # Prompt user for local branch name
            Write-Host ""
            Write-Host "Default suggestion follows {user-handle}/{project-name} convention" -ForegroundColor Gray
            $localBranchName = Read-UserPrompt -Prompt "Local branch name" -DefaultValue $defaultLocalBranch
            if ([string]::IsNullOrWhiteSpace($localBranchName)) {
                $localBranchName = $defaultLocalBranch
            }
            
            Write-Info "Using local branch: $localBranchName"
            
            # Create/switch to the local branch if different from current
            if ($currentBranch -ne $localBranchName) {
                Write-Progress "Creating and switching to local branch '$localBranchName'..."
                
                # Check if branch already exists locally
                if ($useWSL) {
                    $branchExists = wsl -- bash -c "cd '$resolvedProjectPath' && git branch --list '$localBranchName'" 2>&1
                } else {
                    $branchExists = & git -C $resolvedProjectPath branch --list $localBranchName 2>&1
                }
                
                $branchExistsStr = if ($branchExists -is [string]) { $branchExists } else { $branchExists | Out-String }
                if ($branchExistsStr -and $branchExistsStr.Trim()) {
                    # Branch exists, just switch to it
                    if ($useWSL) {
                        $branchResult = wsl -- bash -c "cd '$resolvedProjectPath' && git checkout '$localBranchName'" 2>&1
                    } else {
                        $branchResult = & git -C $resolvedProjectPath checkout $localBranchName 2>&1
                    }
                } else {
                    # Create new branch
                    if ($useWSL) {
                        $branchResult = wsl -- bash -c "cd '$resolvedProjectPath' && git checkout -b '$localBranchName'" 2>&1
                    } else {
                        $branchResult = & git -C $resolvedProjectPath checkout -b $localBranchName 2>&1
                    }
                }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to create/switch to branch '$localBranchName': $($branchResult -join ' ')"
                    Write-Info "Will continue with current branch '$currentBranch'"
                    $localBranchName = $currentBranch
                } else {
                    Write-Success "Switched to local branch '$localBranchName'"
                }
            }
            
            # Step 2: Handle commits for existing repositories
            if ($skipInitialization) {
                Write-Progress "Checking for changes to commit..."
                
                if ($useWSL) {
                    $statusResult = wsl -- bash -c "cd '$resolvedProjectPath' && git status --porcelain" 2>&1
                } else {
                    $statusResult = & git -C $resolvedProjectPath status --porcelain 2>&1
                }
                
                if ($LASTEXITCODE -eq 0 -and $statusResult) {
                    Write-Info "Found changes to commit:"
                    $statusResult | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                    
                    # Add changes only within the project directory
                    if ($useWSL) {
                        $addResult = wsl -- bash -c "cd '$resolvedProjectPath' && git add ." 2>&1
                    } else {
                        $addResult = & git -C $resolvedProjectPath add . 2>&1
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        # Commit changes
                        $commitMessage = "Initial commit for bootstrapping $ProjectName with strangeloop using loop '$LoopName'"
                        if ($useWSL) {
                            $commitResult = wsl -- bash -c "cd '$resolvedProjectPath' && git commit -m '$commitMessage'" 2>&1
                        } else {
                            $commitResult = & git -C $resolvedProjectPath commit -m $commitMessage 2>&1
                        }
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Changes committed successfully"
                        } else {
                            Write-Warning "Failed to commit changes: $($commitResult -join ' ')"
                        }
                    } else {
                        Write-Warning "Failed to add changes: $($addResult -join ' ')"
                    }
                } else {
                    Write-Info "No changes to commit"
                }
            }
            
            # Step 3: Handle remote push if remote is configured
            if ($remoteConfigured) {
                Write-Host ""
                Write-Info "Remote repository configured: $remoteUrl"
                
                # Fetch latest from remote before pushing
                Write-Progress "Fetching latest changes from remote..."
                if ($useWSL) {
                    $fetchResult = wsl -- bash -c "cd '$resolvedProjectPath' && git fetch origin" 2>&1
                } else {
                    $fetchResult = & git -C $resolvedProjectPath fetch origin 2>&1
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Successfully fetched latest changes from remote"
                } else {
                    Write-Warning "Failed to fetch from remote (this may be normal for new repositories): $($fetchResult -join ' ')"
                    Write-Info "Continuing with push operation..."
                }
                
                # Automatically proceed with push
                Write-Info "Automatically pushing to remote repository..."
                
                if ($true) {
                    # Use local branch name as remote branch name
                    $remoteBranchName = $localBranchName
                    
                    Write-Info "Ready to push to remote branch '$remoteBranchName'"
                    Write-Host "Local branch: $localBranchName" -ForegroundColor Cyan
                    Write-Host "Remote branch: $remoteBranchName" -ForegroundColor Cyan
                    Write-Host "Remote URL: $remoteUrl" -ForegroundColor Cyan
                
                if (Test-YesResponse $pushConfirm) {
                    Write-Progress "Fetching latest changes from remote before push..."
                    if ($useWSL) {
                        $fetchResult = wsl -- bash -c "cd '$resolvedProjectPath' && git fetch origin" 2>&1
                    } else {
                        $fetchResult = & git -C $resolvedProjectPath fetch origin 2>&1
                    }
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Fetched latest changes from remote."
                    } else {
                        Write-Warning "Failed to fetch from remote. Continuing with push attempt."
                    }

                    Write-Progress "Pushing to remote branch '$remoteBranchName'..."
                    $pushSpec = "$localBranchName`:$remoteBranchName"
                    if ($useWSL) {
                        $pushResult = wsl -- bash -c "cd '$resolvedProjectPath' && git push -u origin '$pushSpec'" 2>&1
                    } else {
                        $pushResult = & git -C $resolvedProjectPath push -u origin $pushSpec 2>&1
                    }

                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Push completed to remote branch '$remoteBranchName'"
                        Write-Info "Local branch '$localBranchName' is now tracking remote '$remoteBranchName'"
                        # Clear any previously set skip flag because push succeeded
                        $global:SkipPipelinePhase = $false
                    } else {
                        $pushOutput = $pushResult -join ' '
                        
                        # Check if this is a non-fast-forward error
                        if ($pushOutput -match "non-fast-forward" -or $pushOutput -match "rejected.*behind") {
                            Write-Warning "Push rejected: Remote branch has newer commits"
                            Write-Host ""
                            Write-Host "The remote branch '$remoteBranchName' has commits that your local branch doesn't have." -ForegroundColor Yellow
                            Write-Host ""
                            Write-Host "Available options:" -ForegroundColor Cyan
                            Write-Host "  1. Pull and merge remote changes first (recommended)" -ForegroundColor Green
                            Write-Host "  2. Force push (overwrites remote - USE WITH CAUTION)" -ForegroundColor Red
                            Write-Host "  3. Skip push (continue without pushing)" -ForegroundColor Yellow
                            Write-Host ""
                            
                            $pullOption = Read-UserPrompt -Prompt "Choose option (1=pull, 2=force, 3=skip)" -ValidValues @("1","2","3") -DefaultValue "1"
                            
                            if ($pullOption -eq "1") {
                                Write-Info "Pulling remote changes and attempting merge..."
                                
                                # Try to pull/merge the specific remote branch
                                if ($useWSL) {
                                    $pullResult = wsl -- bash -c "cd '$resolvedProjectPath' && git pull origin '$remoteBranchName'" 2>&1
                                } else {
                                    $pullResult = & git -C $resolvedProjectPath pull origin $remoteBranchName 2>&1
                                }
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Successfully merged remote changes"
                                    Write-Info "Retrying push..."
                                    
                                    # Retry the push
                                    if ($useWSL) {
                                        $retryPushResult = wsl -- bash -c "cd '$resolvedProjectPath' && git push -u origin '$pushSpec'" 2>&1
                                    } else {
                                        $retryPushResult = & git -C $resolvedProjectPath push -u origin $pushSpec 2>&1
                                    }
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Push completed to remote branch '$remoteBranchName' after merge"
                                        Write-Info "Local branch '$localBranchName' is now tracking remote '$remoteBranchName'"
                                        $global:SkipPipelinePhase = $false
                                    } else {
                                        Write-Error "Push still failed after merge: $($retryPushResult -join ' ')"
                                        Write-Info "You can push manually later with:"
                                        Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                                        $global:SkipPipelinePhase = $true
                                    }
                                } else {
                                    Write-Error "Failed to merge remote changes: $($pullResult -join ' ')"
                                    Write-Warning "You may have merge conflicts that need manual resolution"
                                    Write-Info "You can resolve conflicts manually and push later with:"
                                    Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                                    $global:SkipPipelinePhase = $true
                                }
                            } elseif ($pullOption -eq "2") {
                                Write-Warning "Force pushing - this will overwrite remote changes!"
                                $confirmForce = Read-UserPrompt -Prompt "Are you absolutely sure? (type 'FORCE' to confirm)" -DefaultValue "cancel"
                                
                                if ($confirmForce -eq "FORCE") {
                                    if ($useWSL) {
                                        $forcePushResult = wsl -- bash -c "cd '$resolvedProjectPath' && git push -u --force origin '$pushSpec'" 2>&1
                                    } else {
                                        $forcePushResult = & git -C $resolvedProjectPath push -u --force origin $pushSpec 2>&1
                                    }
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Force push completed to remote branch '$remoteBranchName'"
                                        Write-Info "Local branch '$localBranchName' is now tracking remote '$remoteBranchName'"
                                        $global:SkipPipelinePhase = $false
                                    } else {
                                        Write-Error "Force push failed: $($forcePushResult -join ' ')"
                                        Write-Info "You can push manually later with:"
                                        Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                                        $global:SkipPipelinePhase = $true
                                    }
                                } else {
                                    Write-Info "Force push cancelled"
                                    Write-Info "You can push manually later with:"
                                    Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                                    $global:SkipPipelinePhase = $true
                                }
                            } else {
                                Write-Info "Push skipped by user"
                                Write-Info "You can push manually later with:"
                                Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                                $global:SkipPipelinePhase = $true
                            }
                        } else {
                            Write-Warning "Push failed: $pushOutput"
                            Write-Info "You can push manually later with:"
                            Write-Info "  git push -u origin $localBranchName`:$remoteBranchName"
                            # Signal to skip pipeline phase if push fails
                            $global:SkipPipelinePhase = $true
                        }
                    }
                } else {
                    Write-Info "Push cancelled by user"
                    Write-Info "You can push manually later with:"
                    Write-Info "  git push -u origin $localBranchName"
                }
            } else {
                Write-Info "No remote repository configured - local changes committed to branch '$localBranchName'"
            }
            
        } catch {
            Write-Warning "Error during branch setup and push: $($_.Exception.Message)"
            Write-Info "You may need to complete Git setup manually"
        }
        
        # Step 8: Verify setup
        Write-Progress "Verifying Git setup..."
        
        try {
            if ($useWSL) {
                $statusResult = wsl -- bash -c "cd '$resolvedProjectPath' && git status --porcelain" 2>&1
                $remoteResult = wsl -- bash -c "cd '$resolvedProjectPath' && git remote -v" 2>&1
            } else {
                $statusResult = & git -C $resolvedProjectPath status --porcelain 2>&1
                $remoteResult = & git -C $resolvedProjectPath remote -v 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Git repository setup completed successfully"
                
                if ($remoteResult -and ($remoteResult -join ' ') -match "origin") {
                    Write-Info "Remote repository configured"
                } else {
                    Write-Info "Local repository only (no remote configured)"
                }
            } else {
                Write-Warning "Git setup verification failed"
            }
        } catch {
            Write-Info "Git setup completed (verification skipped)"
        }
        
        return @{
            Success = $true
            ProjectPath = $resolvedProjectPath
            ProjectName = $ProjectName
            LoopName = $LoopName
            RemoteConfigured = $remoteConfigured
            RemotePushSuccess = if ($GitContext.RemotePushSuccess -ne $null) { $GitContext.RemotePushSuccess } else { $null }
        }
        
    } catch {
        Write-Error "Git repository initialization failed: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }

function Get-GitIgnoreContent {
    <#
    .SYNOPSIS
    Generates appropriate .gitignore content based on project type
    
    .PARAMETER LoopName
    Name of the loop template to determine ignore patterns
    
    .OUTPUTS
    String containing .gitignore content
    #>
    param(
        [string]$LoopName
    )
    
    $baseIgnore = @"
# strangeloop
.strangeloop/
strangeloop/cache/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE and Editor files
.vscode/settings.json
.vscode/launch.json
.vscode/extensions.json
.idea/
*.swp
*.swo
*~

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Temporary files
*.tmp
*.temp
temp/
tmp/
"@

    $pythonIgnore = @"

# Python
__pycache__/
*.py[cod]
*`$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/
.poetry/

# Jupyter Notebook
.ipynb_checkpoints

# pyenv
.python-version

# Pipenv
Pipfile.lock
"@

    $dotnetIgnore = @"

# .NET
bin/
obj/
*.user
*.suo
*.userosscache
*.sln.docstates
.vs/
[Dd]ebug/
[Dd]ebugPublic/
[Rr]elease/
[Rr]eleases/
x64/
x86/
bld/
[Bb]in/
[Oo]bj/
[Ll]og/

# NuGet
*.nupkg
*.snupkg
.nuget/
packages/

# MSTest test Results
[Tt]est[Rr]esult*/
[Bb]uild[Ll]og.*

# Visual Studio
*.vspscc
*.vssscc
.builds
*.pidb
*.svclog
*.scc

# ASP.NET
project.lock.json
project.fragment.lock.json
artifacts/
"@

    $nodeIgnore = @"

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
package-lock.json
yarn.lock

# Next.js
.next/
out/

# Production
/build

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# nyc test coverage
.nyc_output

# Dependency directories
jspm_packages/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache/
.rts2_cache_cjs/
.rts2_cache_es/
.rts2_cache_umd/

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity
"@

    # Determine which additional ignore patterns to include
    $content = $baseIgnore
    
    if ($LoopName -match "python|flask|langgraph") {
        $content += $pythonIgnore
    }
    
    if ($LoopName -match "csharp|dotnet|asp") {
        $content += $dotnetIgnore
    }
    
    if ($LoopName -match "node|next|vite") {
        $content += $nodeIgnore
    }
    
    return $content
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $params = @{
        ProjectPath = ${project-path}
        ProjectName = ${project-name}
        LoopName = ${loop-name}
        TargetPlatform = $TargetPlatform
        RequiresWSL = ${requires-wsl}
        GitContext = ${git-context}
    }
    if (${check-only}) { $params['check-only'] = ${check-only} }
    if (${what-if}) { $params['what-if'] = ${what-if} }
    
    $result = Initialize-GitRepository @params
    
    if ($result -and $result.Success) {
        Write-Success "Git source control setup completed successfully"
    } else {
        Write-Error "Git source control setup failed"
    }
    
    # Return the result for Invoke-Phase to capture
    return $result
}

# Export functions for module usage
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Initialize-GitRepository',
        'Get-GitIgnoreContent'
    )
}

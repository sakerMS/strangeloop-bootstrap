# strangeloop Setup - Project Initialization Module
# Version: 1.0.0


param(
    [string]${project-name},
    [string]${loop-name},
    [string]${project-path},
    [string]$TargetPlatform,
    [switch]${requires-wsl},
    [string]${base-directory},
    [switch]${check-only},
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")

# Import platform configuration for centralized loop platform detection
. (Join-Path $LibPath "platform\platform-functions.ps1")

# Helper function for safe user path expansion
function Get-UserForPlatform {
    <#
    .SYNOPSIS
    Gets the username for a specific platform (execution vs target)
    
    .PARAMETER Platform
    The platform to get the user for: 'Windows', 'WSL', or 'Linux'
    
    .RETURNS
    Username for the specified platform
    #>
    param([string]$TargetPlatform)
    
    switch ($TargetPlatform.ToLower()) {
        'windows' {
            # For Windows target, use Windows username
            if ($env:USERNAME) { return $env:USERNAME }
            if ($env:USER) { return $env:USER }
            return 'user'
        }
        { $_ -in @('wsl', 'linux') } {
            # For WSL/Linux target, get the WSL username
            $user = $null
            
            # Method 1: Try WSL whoami command
            try {
                if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) {
                    # Running within WSL - use direct whoami
                    $user = & whoami 2>&1
                } else {
                    # Running from Windows - use wsl command
                    $user = & wsl -- whoami 2>&1
                }
                if ($user -and $LASTEXITCODE -eq 0) {
                    return $user.Trim()
                }
            } catch { }
            
            # Method 2: Try Unix environment variables
            if ($env:USER) { return $env:USER }
            if ($env:LOGNAME) { return $env:LOGNAME }
            
            # Method 3: Try reading from /etc/passwd (WSL only)
            try {
                if (Test-Path '/etc/passwd') {
                    $uid = & id -u 2>&1
                    if ($uid -and $LASTEXITCODE -eq 0) {
                        $passwdEntry = Get-Content '/etc/passwd' | Where-Object { $_ -match "^[^:]*:[^:]*:$($uid.Trim()):" } | Select-Object -First 1
                        if ($passwdEntry) {
                            return ($passwdEntry -split ':')[0]
                        }
                    }
                }
            } catch { }
            
            # Fallback
            return 'user'
        }
        default {
            # Auto-detect based on execution context
            if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) {
                return Get-UserForPlatform 'Linux'
            } else {
                return Get-UserForPlatform 'Windows'
            }
        }
    }
}

function Expand-UserPath {
    <#
    .SYNOPSIS
    Safely expands user placeholders in paths without triggering variable expansion errors
    
    .PARAMETER Path
    The path potentially containing user placeholders
    
    .PARAMETER TargetPlatform
    The target platform for the path expansion: 'Windows', 'WSL', 'Linux', or 'Auto'
    Defaults to 'Auto' which uses the execution context
    
    .RETURNS
    Expanded path with actual username for the target platform
    #>
    param(
        [string]$Path,
        [string]$TargetPlatform = 'Auto'
    )
    
    if (-not $Path) { return $Path }
    
    # Get the appropriate username for the target platform
    $user = Get-UserForPlatform $TargetPlatform
    
    # Handle {USER} placeholder
    if ($Path -like '*{USER}*') {
        return $Path -replace '\{USER\}', $user
    }
    
    # Handle legacy \$USER pattern (convert to safe form)
    if ($Path -match '\\?\$USER') {
        return $Path -replace '\\?\$USER', $user
    }
    
    return $Path
}

# Global context object for passing information between phases
$Global:GitContext = @{
    IsGitControlled = $false
    WillInitializeGit = $false
    SkipGit = $false
    LocalBranch = $null
    RemoteUrl = $null
    RemotePushSuccess = $false
    ProjectPath = $null
}

# Global phase skip flags
$Global:PhaseSkips = @{
    Git = $false
    Pipeline = $false
}

function Get-ProjectPath {
    <#
    .SYNOPSIS
    Gets project parent directory from user with intelligent defaults
    
    .PARAMETER LoopName
    Name of the selected loop for intelligent path suggestion
    
    .PARAMETER ProjectName
    Project name (used for context, but not included in returned path)
    
    .PARAMETER Platform
    Target platform (WSL or Windows)
    
    .PARAMETER RequiresWSL
    Whether the loop requires WSL environment
    
    .OUTPUTS
    String containing the parent directory path where project folder will be created
    #>
    param(
        [string]$LoopName,
        [string]$ProjectName,
        [string]$TargetPlatform,
        [switch]$RequiresWSL
    )
    
    try {
        # Determine if this is a WSL loop using centralized configuration
        $targetPlatform = Get-PlatformForLoop -LoopName $LoopName
        $isWSLLoop = ($targetPlatform -eq "WSL")
        $effectiveRequiresWSL = $RequiresWSL -or $isWSLLoop
        
        # Generate intelligent default parent directory based on platform and loop requirements
        $defaultParentPath = $null
        
        if ($effectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $TargetPlatform -eq "Dual") {
            # WSL parent path
            try {
                # Detect if we're running within WSL or from Windows
                if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) {
                    # Running within WSL - use direct whoami
                    $wslUser = & whoami 2>&1
                } else {
                    # Running from Windows - use wsl command
                    $wslUser = & wsl -- whoami 2>&1
                }
                
                if ($wslUser -and $LASTEXITCODE -eq 0) {
                    $defaultParentPath = "/home/$($wslUser.Trim())/AdsSnR_Containers/services"
                } else {
                    # Use a placeholder that we'll expand later
                    $defaultParentPath = "/home/{USER}/AdsSnR_Containers/services"
                }
            } catch {
                # Use a placeholder that we'll expand later
                $defaultParentPath = "/home/{USER}/AdsSnR_Containers/services"
            }
        } else {
            # Windows parent path
            $defaultParentPath = "Q:\src\AdsSnR_Containers\services"
        }
        
        Write-Host ""
        Write-Host "📁 Project Parent Directory Selection" -ForegroundColor Cyan
        
        # Show both execution and target platform for clarity
        $executionPlatform = if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) { 'WSL/Linux' } else { 'Windows' }
        Write-Host "Execution Platform: $executionPlatform (where this script is running)" -ForegroundColor Gray
        Write-Host "Target Platform: $(if ($effectiveRequiresWSL) { 'WSL' } else { 'Windows' }) (where project will be created)" -ForegroundColor Gray
        Write-Host "Loop: $LoopName" -ForegroundColor Gray
        Write-Host "Project '$ProjectName' will be created in this directory" -ForegroundColor Gray
        Write-Host ""
        
        $parentPath = Read-UserPrompt -Prompt "Parent directory" -DefaultValue $defaultParentPath
        if ([string]::IsNullOrWhiteSpace($parentPath)) {
            $parentPath = $defaultParentPath
        }
        
        # Expand {USER} placeholder if present with correct target platform
        $targetPlatformForPath = if ($effectiveRequiresWSL) { 'WSL' } else { 'Windows' }
        $parentPath = Expand-UserPath $parentPath $targetPlatformForPath
        
        Write-Info "Selected parent directory: $parentPath"
        Write-Info "Project will be created at: $parentPath/$ProjectName"
        return $parentPath
        
    } catch {
        Write-Warning "Error determining project parent path: $($_.Exception.Message)"
        return $null
    }
}

function Test-GitRepository {
    <#
    .SYNOPSIS
    Tests if a path is git-controlled and gets repository information
    
    .PARAMETER Path
    Path to test for git repository
    
    .OUTPUTS
    Hashtable with git repository information
    #>
    param(
        [string]$Path
    )
    
    try {
        $result = @{
            IsGitRepo = $false
            CurrentBranch = $null
            HasRemote = $false
            RemoteUrl = $null
            GitRepositoryPath = $null
        }
        
        # Check if path exists and is a directory
        $isWSLPath = $Path.StartsWith('/') -or $Path.Contains('/home/')
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        if ($isWSLPath) {
            # Test WSL path - check for git repository, handling non-existent paths by checking parents
            $pathToTest = $Path
            
            # If the target path doesn't exist, check parent directories for git repositories
            if ($isRunningInWSL) {
                # Already in WSL, test path directly
                $pathExists = Test-Path $pathToTest
            } else {
                # Running from Windows, use wsl command
                $pathExists = & wsl -- bash -c "test -d '$pathToTest' && echo 'exists' || echo 'missing'" 2>&1
                $pathExists = ($pathExists -eq 'exists')
            }
            if (-not $pathExists) {
                # Path doesn't exist, check if any parent directory is a git repository
                $parentPath = $pathToTest
                $maxDepth = 5  # Prevent infinite loops
                $depth = 0
                
                while ($parentPath -ne '/' -and $parentPath -ne '' -and $depth -lt $maxDepth) {
                    # Use Unix-style path manipulation for WSL paths
                    if ($parentPath.EndsWith('/')) {
                        $parentPath = $parentPath.TrimEnd('/')
                    }
                    $lastSlash = $parentPath.LastIndexOf('/')
                    if ($lastSlash -gt 0) {
                        $parentPath = $parentPath.Substring(0, $lastSlash)
                    } else {
                        $parentPath = '/'
                    }
                    
                    if ($parentPath -eq '' -or $parentPath -eq '/') {
                        break
                    }
                    
                    if ($isRunningInWSL) {
                        # Already in WSL, test path directly
                        $parentExists = Test-Path $parentPath
                    } else {
                        # Running from Windows, use wsl command
                        $parentExists = & wsl -- bash -c "test -d '$parentPath' && echo 'exists' || echo 'missing'" 2>&1
                        $parentExists = ($parentExists -eq 'exists')
                    }
                    if ($parentExists) {
                        $pathToTest = $parentPath
                        break
                    }
                    $depth++
                }
            }
            
            # Now check if the determined path is in a git repository
            # Check if this is a git repository using a simpler approach
            if ($isRunningInWSL) {
                # Already in WSL, use git commands directly
                Push-Location $pathToTest
                try {
                    $gitCheck = git rev-parse --git-dir 2>&1
                    $result.IsGitRepo = ($LASTEXITCODE -eq 0 -and $gitCheck)
                } finally {
                    Pop-Location
                }
            } else {
                # Running from Windows, use wsl command
                $gitCheck = & wsl -- bash -c "cd '$pathToTest' && git rev-parse --git-dir && echo 'git-success'" 2>&1
                $result.IsGitRepo = ($gitCheck -like '*git-success*')
            }
            
            if ($result.IsGitRepo) {
                # Store the git repository path (the path where git commands should be run)
                $result.GitRepositoryPath = $pathToTest
                
                if ($isRunningInWSL) {
                    # Already in WSL, use git commands directly
                    Push-Location $pathToTest
                    try {
                        # Get current branch
                        $branchResult = git branch --show-current 2>&1
                        if ($LASTEXITCODE -eq 0 -and $branchResult -and $branchResult.Trim()) {
                            $result.CurrentBranch = $branchResult.Trim()
                        }
                        
                        # Check for remote
                        $remoteCheck = git remote -v 2>&1
                        if ($LASTEXITCODE -eq 0 -and $remoteCheck) {
                            $result.HasRemote = $true
                            $result.RemoteUrl = ($remoteCheck | Where-Object { $_ -match "origin.*\(push\)" } | ForEach-Object { 
                                ($_ -split "\s+")[1] 
                            }) | Select-Object -First 1
                        }
                    } finally {
                        Pop-Location
                    }
                } else {
                    # Running from Windows, use wsl command
                    # Get current branch
                    $branchResult = & wsl -- bash -c "cd '$pathToTest' && git branch --show-current" 2>&1
                    if ($branchResult -and $branchResult.Trim()) {
                        $result.CurrentBranch = $branchResult.Trim()
                    }
                    
                    # Check for remote
                    $remoteCheck = & wsl -- bash -c "cd '$pathToTest' && git remote -v" 2>&1
                    if ($remoteCheck) {
                        $result.HasRemote = $true
                        $result.RemoteUrl = ($remoteCheck | Where-Object { $_ -match "origin.*\(push\)" } | ForEach-Object { 
                            ($_ -split "\s+")[1] 
                        }) | Select-Object -First 1
                    }
                }
            }
        } else {
            # Test Windows path
            if (Test-Path $Path) {
                Push-Location $Path
                try {
                    $gitCheck = git rev-parse --git-dir 2>&1
                    $result.IsGitRepo = ($LASTEXITCODE -eq 0)
                    
                    if ($result.IsGitRepo) {
                        # Store the git repository path (the path where git commands should be run)
                        $result.GitRepositoryPath = $Path
                        
                        # Get current branch
                        $branchResult = git branch --show-current 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $result.CurrentBranch = $branchResult.Trim()
                        }
                        
                        # Check for remote
                        $remoteCheck = git remote -v 2>&1
                        if ($LASTEXITCODE -eq 0 -and $remoteCheck) {
                            $result.HasRemote = $true
                            $result.RemoteUrl = ($remoteCheck | Where-Object { $_ -match "origin.*\(push\)" } | ForEach-Object { 
                                ($_ -split "\s+")[1] 
                            }) | Select-Object -First 1
                        }
                    }
                } finally {
                    Pop-Location
                }
            }
        }
        
        return $result
        
    } catch {
        Write-Warning "Error testing git repository: $($_.Exception.Message)"
        return @{
            IsGitRepo = $false
            CurrentBranch = $null
            HasRemote = $false
            RemoteUrl = $null
        }
    }
}

function Invoke-RepositoryClone {
    <#
    .SYNOPSIS
    Handles repository cloning for both WSL and Windows environments
    
    .PARAMETER RepositoryDir
    Target directory where repository should be cloned
    
    .PARAMETER RemoteUrl
    Git remote URL to clone from
    
    .PARAMETER UseWSL
    Whether to use WSL for git operations
    
    .PARAMETER WhatIf
    Shows what would be done without performing actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryDir,
        [Parameter(Mandatory)]
        [string]$RemoteUrl,
        [bool]$UseWSL,
        [switch]$WhatIf
    )
    
    try {
        # Determine current execution environment
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        if ($UseWSL) {
            # WSL clone
            Write-Host "🔄 Cloning repository to WSL directory..." -ForegroundColor Cyan
            Write-Info "Target location: $RepositoryDir"
            
            if ($WhatIf) {
                Write-Host "🔍 (what-if) Would clone repository to WSL: $RepositoryDir" -ForegroundColor Yellow
                Write-Host "🔍 (what-if) Would run: git clone $RemoteUrl" -ForegroundColor Yellow
                return $true
            }
            
            # Ensure parent directory exists
            $parentDir = $RepositoryDir.Substring(0, $RepositoryDir.LastIndexOf('/'))
            if ($parentDir -ne '/') {
                if ($isRunningInWSL) {
                    # Already in WSL, run mkdir directly
                    $mkdirResult = mkdir -p "$parentDir" 2>&1
                } else {
                    # Running from Windows, use wsl command
                    $mkdirResult = & wsl -- mkdir -p "$parentDir" 2>&1
                }
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to create parent directory: $mkdirResult"
                    return $false
                }
            }
            
            # Remove existing directory if present
            if ($isRunningInWSL) {
                # Already in WSL, test directory directly
                $null = Test-Path "$RepositoryDir" 2>$null
                $directoryExists = $?
            } else {
                # Running from Windows, use wsl command
                $null = & wsl -- test -d "$RepositoryDir" 2>$null
                $directoryExists = ($LASTEXITCODE -eq 0)
            }
            
            if ($directoryExists) {
                Write-Progress "Removing existing directory..."
                if ($isRunningInWSL) {
                    # Already in WSL, run rm directly
                    $removeResult = rm -rf "$RepositoryDir" 2>&1
                } else {
                    # Running from Windows, use wsl command
                    $removeResult = & wsl -- rm -rf "$RepositoryDir" 2>&1
                }
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to remove existing directory: $removeResult"
                    return $false
                }
            }
            
            # Clone repository
            $repoName = Split-Path $RepositoryDir -Leaf
            $cloneCommand = "cd '$parentDir' && git clone '$RemoteUrl' '$repoName'"
            
            if ($isRunningInWSL) {
                # Already in WSL, run git directly
                Push-Location $parentDir
                try {
                    $cloneResult = git clone $RemoteUrl $repoName 2>&1
                } finally {
                    Pop-Location
                }
            } else {
                # Running from Windows, use wsl command
                $cloneResult = & wsl -- bash -c $cloneCommand 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Repository cloned successfully to $RepositoryDir"
                return $true
            } else {
                Write-Error "WSL git clone failed: $cloneResult"
                return $false
            }
        } else {
            # Windows clone
            Write-Host "🔄 Cloning repository to Windows directory..." -ForegroundColor Cyan
            Write-Info "Target location: $RepositoryDir"
            
            if ($WhatIf) {
                Write-Host "🔍 (what-if) Would clone repository to Windows: $RepositoryDir" -ForegroundColor Yellow
                Write-Host "🔍 (what-if) Would run: git clone $RemoteUrl $RepositoryDir" -ForegroundColor Yellow
                return $true
            }
            
            # Ensure parent directory exists
            $parentDir = Split-Path $RepositoryDir -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                Write-Info "Created parent directory: $parentDir"
            }
            
            # Remove existing directory if present
            if (Test-Path $RepositoryDir) {
                Write-Progress "Removing existing directory..."
                try {
                    Remove-Item $RepositoryDir -Recurse -Force -ErrorAction Stop
                    Write-Success "Existing directory removed"
                } catch {
                    Write-Error "Failed to remove existing directory: $($_.Exception.Message)"
                    return $false
                }
            }
            
            # Clone repository
            $cloneResult = & git clone $RemoteUrl $RepositoryDir 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Repository cloned successfully to $RepositoryDir"
                return $true
            } else {
                Write-Error "Windows git clone failed: $cloneResult"
                return $false
            }
        }
    } catch {
        Write-Error "Error during repository clone: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-GitWorkflow {
    <#
    .SYNOPSIS
    Handles the initial git workflow setup based on path analysis
    
    .PARAMETER ProjectPath
    Path to the project directory
    
    .PARAMETER ProjectName
    Name of the project
    
    .PARAMETER Platform
    Target platform (Windows or WSL)
    
    .PARAMETER EffectiveRequiresWSL
    Whether the project effectively requires WSL
    
    .PARAMETER UseWSLForGit
    Whether to use WSL for git operations
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [string]$ProjectPath,
        [string]$ProjectName,
        [string]$TargetPlatform,
        [bool]$EffectiveRequiresWSL,
        [bool]$UseWSLForGit,
        [switch]${what-if}
    )
    
    try {
        # Determine current execution environment
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        Write-Host ""
        Write-Host "🔍 Git Repository Analysis" -ForegroundColor Cyan
        
        # For git detection, we need to check the parent directory where the project will be created
        # Extract the parent directory from the full project path, handling WSL and Windows paths
        if ($ProjectPath -match '^(\/home\/|\/mnt\/)' ) {
            # WSL-style path: use string manipulation to preserve leading slash
            $parentPath = ($ProjectPath -replace '/+$','') -replace '/[^/]+$',''
            if ([string]::IsNullOrWhiteSpace($parentPath)) { $parentPath = '/' }
        } else {
            # Windows path: use Split-Path
            $parentPath = Split-Path -Parent $ProjectPath
        }
        Write-Info "Checking git repository at parent path: $parentPath"
        
        # Test if parent path is git-controlled
        # No path conversion - use the exact path format provided by user
        $gitInfo = Test-GitRepository -Path $parentPath
        
        if ($gitInfo.IsGitRepo) {
            Write-Success "Project path is already git-controlled"
            Write-Info "Current branch: $($gitInfo.CurrentBranch)"
            if ($gitInfo.HasRemote) {
                Write-Info "Remote repository: $($gitInfo.RemoteUrl)"
            }
            
            # Handle git-controlled path
            Write-Host ""
            Write-Host "🌿 Branch Selection" -ForegroundColor Yellow
            
            # Generate a branch name based on the project name
            $isWSLPath = $ProjectPath.StartsWith('/') -or $ProjectPath.Contains('/home/')
            if ($isWSLPath) {
                # Get WSL username using cross-platform command execution
                $usernameResult = Invoke-CrossPlatformCommand -Command "whoami" -UseWSLPaths
                if ($usernameResult.Success -and $usernameResult.Output) {
                    $username = $usernameResult.Output.ToString().Trim()
                } else {
                    # Fallback: try direct whoami if running in WSL
                    $currentPlatform = Get-CurrentPlatform
                    if ($currentPlatform -eq "WSL") {
                        try {
                            $username = & whoami 2>$null
                            if (-not $username) {
                                $username = "user"
                            }
                        } catch {
                            $username = "user"
                        }
                    } else {
                        $username = "user"
                    }
                }
            } else {
                # Get Windows username
                $username = if ($env:USERNAME) { $env:USERNAME } else { "user" }
            }
            $suggestedBranch = "$username/$ProjectName"
            
            # Prompt user for branch name with project-based default
            $localBranch = Read-UserPrompt -Prompt "Local working branch" -DefaultValue $suggestedBranch
            if ([string]::IsNullOrWhiteSpace($localBranch)) {
                $localBranch = $suggestedBranch
            }
            
            # CRITICAL: Create and switch to project-specific branch first - only continue if successful
            Write-Progress "Creating project-specific branch '$localBranch'..."
            $branchCreationSuccess = $false
            $gitRepoPath = $parentPath
            
            try {
                if (${what-if}) {
                    Write-Host "🔍 (what-if) Would create/switch to branch '$localBranch'" -ForegroundColor Yellow
                    $branchCreationSuccess = $true
                } else {
                    # First, check for uncommitted changes
                    $hasUncommittedChanges = $false
                    if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                        if ($isRunningInWSL) {
                            # Already in WSL, run git directly
                            Push-Location $gitRepoPath
                            try {
                                $statusResult = git status --porcelain 2>&1
                                $hasUncommittedChanges = ($LASTEXITCODE -eq 0 -and $statusResult -and $statusResult.Trim())
                            } finally {
                                Pop-Location
                            }
                        } else {
                            # Running from Windows, use wsl command
                            $statusResult = wsl -- bash -c "cd '$gitRepoPath' && git status --porcelain" 2>&1
                            $hasUncommittedChanges = ($LASTEXITCODE -eq 0 -and $statusResult -and $statusResult.Trim())
                        }
                    } else {
                        Push-Location $gitRepoPath
                        try {
                            $statusResult = git status --porcelain 2>&1
                            $hasUncommittedChanges = ($LASTEXITCODE -eq 0 -and $statusResult -and $statusResult.Trim())
                        } finally {
                            Pop-Location
                        }
                    }
                    
                    # Handle uncommitted changes before branch operations
                    if ($hasUncommittedChanges) {
                        Write-Warning "Found uncommitted changes in the repository"
                        Write-Host ""
                        Write-Host "📋 Uncommitted Changes Detected" -ForegroundColor Yellow
                        Write-Host "The following files have uncommitted changes:" -ForegroundColor Gray
                        $statusResult | ForEach-Object { 
                            if ($_ -and $_.Trim()) {
                                Write-Host "  $_" -ForegroundColor Gray 
                            }
                        }
                        Write-Host ""
                        Write-Host "Options to handle uncommitted changes:" -ForegroundColor Cyan
                        Write-Host "  [s] Stash changes (recommended)" -ForegroundColor White
                        Write-Host "  [c] Commit changes to current branch" -ForegroundColor White
                        Write-Host "  [d] Discard changes (WARNING: permanent)" -ForegroundColor Yellow
                        Write-Host "  [a] Abort branch creation" -ForegroundColor Gray
                        Write-Host ""
                        
                        $changeOption = Read-UserPrompt -Prompt "How to handle uncommitted changes?" -ValidValues @("s","c","d","a")
                        
                        if ($changeOption -eq "a") {
                            Write-Info "Branch creation aborted by user"
                            return $false
                        } elseif ($changeOption -eq "s") {
                            # Stash changes
                            Write-Progress "Stashing uncommitted changes..."
                            if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                                if ($isRunningInWSL) {
                                    # Already in WSL, run git directly
                                    Push-Location $gitRepoPath
                                    try {
                                        $stashResult = git stash push -m "strangeloop-bootstrap: auto-stash before branch switch" 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Changes stashed successfully"
                                            Write-Info "You can restore them later with: git stash pop"
                                        } else {
                                            Write-Error "Failed to stash changes: $($stashResult -join ' ')"
                                            return $false
                                        }
                                    } finally {
                                        Pop-Location
                                    }
                                } else {
                                    # Running from Windows, use wsl command
                                    $stashResult = wsl -- bash -c "cd '$gitRepoPath' && git stash push -m 'strangeloop-bootstrap: auto-stash before branch switch'" 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Changes stashed successfully"
                                        Write-Info "You can restore them later with: git stash pop"
                                    } else {
                                        Write-Error "Failed to stash changes: $($stashResult -join ' ')"
                                        return $false
                                    }
                                }
                            } else {
                                Push-Location $gitRepoPath
                                try {
                                    $stashResult = git stash push -m "strangeloop-bootstrap: auto-stash before branch switch" 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Changes stashed successfully"
                                        Write-Info "You can restore them later with: git stash pop"
                                    } else {
                                        Write-Error "Failed to stash changes: $($stashResult -join ' ')"
                                        return $false
                                    }
                                } finally {
                                    Pop-Location
                                }
                            }
                        } elseif ($changeOption -eq "c") {
                            # Commit changes
                            Write-Progress "Committing uncommitted changes..."
                            $commitMessage = "strangeloop-bootstrap: auto-commit before branch switch"
                            if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                                if ($isRunningInWSL) {
                                    # Already in WSL, run git directly
                                    Push-Location $gitRepoPath
                                    try {
                                        $addResult = git add -A 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            $commitResult = git commit -m $commitMessage 2>&1
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Success "Changes committed successfully"
                                            } else {
                                                Write-Error "Failed to commit changes: $($commitResult -join ' ')"
                                                return $false
                                            }
                                        } else {
                                            Write-Error "Failed to stage changes: $($addResult -join ' ')"
                                            return $false
                                        }
                                    } finally {
                                        Pop-Location
                                    }
                                } else {
                                    # Running from Windows, use wsl command
                                    $addResult = wsl -- bash -c "cd '$gitRepoPath' && git add -A" 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $commitResult = wsl -- bash -c "cd '$gitRepoPath' && git commit -m '$commitMessage'" 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Changes committed successfully"
                                        } else {
                                            Write-Error "Failed to commit changes: $($commitResult -join ' ')"
                                            return $false
                                        }
                                    } else {
                                        Write-Error "Failed to stage changes: $($addResult -join ' ')"
                                        return $false
                                    }
                                }
                            } else {
                                Push-Location $gitRepoPath
                                try {
                                    $addResult = git add -A 2>&1
                                    if ($LASTEXITCODE -eq 0) {
                                        $commitResult = git commit -m $commitMessage 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Changes committed successfully"
                                        } else {
                                            Write-Error "Failed to commit changes: $($commitResult -join ' ')"
                                            return $false
                                        }
                                    } else {
                                        Write-Error "Failed to stage changes: $($addResult -join ' ')"
                                        return $false
                                    }
                                } finally {
                                    Pop-Location
                                }
                            }
                        } elseif ($changeOption -eq "d") {
                            # Discard changes
                            Write-Host ""
                            Write-Warning "⚠️  DANGER: This will permanently discard all uncommitted changes!"
                            $confirmDiscard = Read-UserPrompt -Prompt "Are you sure you want to discard all changes?" -ValidValues @("y","n")
                            if (Test-YesResponse $confirmDiscard) {
                                Write-Progress "Discarding uncommitted changes..."
                                if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                                    if ($isRunningInWSL) {
                                        # Already in WSL, run git directly
                                        Push-Location $gitRepoPath
                                        try {
                                            $resetResult = git reset --hard HEAD 2>&1
                                            $cleanResult = git clean -fd 2>&1
                                            if ($LASTEXITCODE -eq 0) {
                                                Write-Success "Changes discarded successfully"
                                            } else {
                                                Write-Error "Failed to discard changes"
                                                return $false
                                            }
                                        } finally {
                                            Pop-Location
                                        }
                                    } else {
                                        # Running from Windows, use wsl command
                                        $resetResult = wsl -- bash -c "cd '$gitRepoPath' && git reset --hard HEAD && git clean -fd" 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Changes discarded successfully"
                                        } else {
                                            Write-Error "Failed to discard changes: $($resetResult -join ' ')"
                                            return $false
                                        }
                                    }
                                } else {
                                    Push-Location $gitRepoPath
                                    try {
                                        $resetResult = git reset --hard HEAD 2>&1
                                        $cleanResult = git clean -fd 2>&1
                                        if ($LASTEXITCODE -eq 0) {
                                            Write-Success "Changes discarded successfully"
                                        } else {
                                            Write-Error "Failed to discard changes"
                                            return $false
                                        }
                                    } finally {
                                        Pop-Location
                                    }
                                }
                            } else {
                                Write-Info "Discard operation cancelled"
                                return $false
                            }
                        }
                    }
                    
                    # Now proceed with branch creation/switch (working directory should be clean)
                    if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                        if ($isRunningInWSL) {
                            # Already in WSL, run git directly
                            Push-Location $gitRepoPath
                            try {
                                # Check if branch already exists
                                $branchExists = git branch --list $localBranch 2>&1
                                if ($branchExists -and $branchExists.Trim()) {
                                    # Branch exists, switch to it
                                    $checkoutResult = git checkout $localBranch 2>&1
                                    $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                    if ($branchCreationSuccess) {
                                        Write-Success "Switched to existing branch '$localBranch'"
                                    } else {
                                        Write-Error "Failed to switch to existing branch '$localBranch': $($checkoutResult -join ' ')"
                                    }
                                } else {
                                    # Branch doesn't exist, create it
                                    $createResult = git checkout -b $localBranch 2>&1
                                    $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                    if ($branchCreationSuccess) {
                                        Write-Success "Created and switched to new branch '$localBranch'"
                                    } else {
                                        Write-Error "Failed to create branch '$localBranch': $($createResult -join ' ')"
                                    }
                                }
                            } finally {
                                Pop-Location
                            }
                        } else {
                            # Running from Windows, use wsl command
                            # Check if branch already exists
                            $branchExists = wsl -- bash -c "cd '$gitRepoPath' && git branch --list '$localBranch'" 2>&1
                            if ($branchExists -and $branchExists.Trim()) {
                                # Branch exists, switch to it
                                $checkoutResult = wsl -- bash -c "cd '$gitRepoPath' && git checkout '$localBranch'" 2>&1
                                $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                if ($branchCreationSuccess) {
                                    Write-Success "Switched to existing branch '$localBranch'"
                                } else {
                                    Write-Error "Failed to switch to existing branch '$localBranch': $($checkoutResult -join ' ')"
                                }
                            } else {
                                # Branch doesn't exist, create it
                                $createResult = wsl -- bash -c "cd '$gitRepoPath' && git checkout -b '$localBranch'" 2>&1
                                $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                if ($branchCreationSuccess) {
                                    Write-Success "Created and switched to new branch '$localBranch'"
                                } else {
                                    Write-Error "Failed to create branch '$localBranch': $($createResult -join ' ')"
                                }
                            }
                        }
                    } else {
                        Push-Location $gitRepoPath
                        try {
                            # Check if branch already exists
                            $branchExists = git branch --list $localBranch 2>&1
                            if ($branchExists -and $branchExists.Trim()) {
                                # Branch exists, switch to it
                                $checkoutResult = git checkout $localBranch 2>&1
                                $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                if ($branchCreationSuccess) {
                                    Write-Success "Switched to existing branch '$localBranch'"
                                } else {
                                    Write-Error "Failed to switch to existing branch '$localBranch': $($checkoutResult -join ' ')"
                                }
                            } else {
                                # Branch doesn't exist, create it
                                $createResult = git checkout -b $localBranch 2>&1
                                $branchCreationSuccess = ($LASTEXITCODE -eq 0)
                                if ($branchCreationSuccess) {
                                    Write-Success "Created and switched to new branch '$localBranch'"
                                } else {
                                    Write-Error "Failed to create branch '$localBranch': $($createResult -join ' ')"
                                }
                            }
                        } finally {
                            Pop-Location
                        }
                    }
                }
            } catch {
                Write-Error "Error during branch creation/switch: $($_.Exception.Message)"
                $branchCreationSuccess = $false
            }
            
            # ONLY continue if branch creation/switch was successful
            if (-not $branchCreationSuccess) {
                Write-Error "Failed to create or switch to project-specific branch. Cannot continue with git workflow."
                return $false
            }
            
            # Now that we're on the correct branch, sync with remote if available
            if ($gitInfo.HasRemote) {
                if (${what-if}) {
                    Write-Host "🔍 (what-if) Would sync latest changes from main branch..." -ForegroundColor Yellow
                    Write-Host "🔍 (what-if) Would merge/pull changes from origin/main" -ForegroundColor Yellow
                } else {
                    Write-Progress "Syncing latest changes from main branch..."
                    
                    try {
                        if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/') {
                            if ($isRunningInWSL) {
                                # Already in WSL, run git directly
                                Push-Location $gitRepoPath
                                try {
                                    # Fetch latest changes and merge/pull from main
                                    git fetch origin main > /dev/null 2>&1
                                    $syncResult = bash -c "(git merge origin/main >/dev/null 2>&1 || git pull origin main >/dev/null 2>&1)"
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Success "Branch '$localBranch' synced with latest changes from main"
                                    } else {
                                        Write-Warning "Could not sync with main branch, but continuing on branch '$localBranch'"
                                    }
                                } finally {
                                    Pop-Location
                                }
                            } else {
                                # Running from Windows, use wsl command
                                # Fetch latest changes and merge/pull from main
                                wsl -- bash -c "cd '$gitRepoPath' && git fetch origin main >/dev/null 2>&1"
                                $syncResult = wsl -- bash -c "cd '$gitRepoPath' && (git merge origin/main >/dev/null 2>&1 || git pull origin main >/dev/null 2>&1)"
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Branch '$localBranch' synced with latest changes from main"
                                } else {
                                    Write-Warning "Could not sync with main branch, but continuing on branch '$localBranch'"
                                }
                            }
                        } else {
                            Push-Location $gitRepoPath
                            try {
                                $null = git fetch origin main 2>&1
                                $null = git merge origin/main 2>&1
                                if ($LASTEXITCODE -ne 0) {
                                    $null = git pull origin main 2>&1
                                }
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Success "Branch '$localBranch' synced with latest changes from main"
                                } else {
                                    Write-Warning "Could not sync with main branch, but continuing on branch '$localBranch'"
                                }
                            } finally {
                                Pop-Location
                            }
                        }
                    } catch {
                        Write-Warning "Could not sync with remote: $($_.Exception.Message)"
                        Write-Info "Continuing on branch '$localBranch' without sync"
                    }
                }
            }
            
            # Set git contexthat
            $Global:GitContext.IsGitControlled = $true
            $Global:GitContext.LocalBranch = $localBranch
            $Global:GitContext.ProjectPath = $ProjectPath
            if ($gitInfo.HasRemote) {
                $Global:GitContext.RemoteUrl = $gitInfo.RemoteUrl
            }
            
        } else {
            # Handle non-git-controlled path - Check parent directory existence first
            Write-Warning "Project path is not git-controlled"
            Write-Host ""
            Write-Host "⚠️  Source Control Setup" -ForegroundColor Yellow
            Write-Host "This project will not be version controlled without git setup." -ForegroundColor Gray
            Write-Host ""
            
            $includeSourceControl = Read-UserPrompt -Prompt "Include project in source control?" -ValidValues @("y","n")
            
            if (Test-YesResponse $includeSourceControl) {
                # User wants source control - determine target directory structure
                $defaultRemoteUrl = "https://msasg.visualstudio.com/DefaultCollection/Bing_Ads/_git/AdsSnR_Containers"
                Write-Host ""
                $remoteUrl = Read-UserPrompt -Prompt "Remote repository URL" -DefaultValue $defaultRemoteUrl
                if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
                    $remoteUrl = $defaultRemoteUrl
                }
                
                # Determine the expected repository location based on platform
                $repositoryDir = $null
                if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL") {
                    # WSL/Linux project
                    try {
                        if ($isRunningInWSL) {
                            # Already in WSL, use direct whoami command
                            $wslUser = & whoami 2>$null
                        } else {
                            # Running from Windows, use wsl command
                            $wslUser = & wsl -- whoami 2>$null
                        }
                        
                        if ($wslUser) {
                            $repositoryDir = "/home/$($wslUser.Trim())/AdsSnR_Containers"
                        } else {
                            $repositoryDir = "/home/$env:USERNAME/AdsSnR_Containers"
                        }
                    } catch {
                        $repositoryDir = "/home/$env:USERNAME/AdsSnR_Containers"
                        Write-Warning "Could not determine WSL username, using default path"
                    }
                } else {
                    # Windows project
                    $repositoryDir = "Q:\src\AdsSnR_Containers"
                }
                
                Write-Host ""
                Write-Host "� Repository Directory Analysis" -ForegroundColor Cyan
                Write-Info "Expected repository location: $repositoryDir"
                
                # Check if repository directory exists and analyze its git status
                $repositoryExists = $false
                $repositoryIsGitControlled = $false
                
                if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL") {
                    # Check WSL directory
                    if ($isRunningInWSL) {
                        # Already in WSL, test directory directly
                        $repositoryExists = Test-Path $repositoryDir
                    } else {
                        # Running from Windows, use wsl command
                        $null = & wsl -- test -d "$repositoryDir" 2>$null
                        $repositoryExists = ($LASTEXITCODE -eq 0)
                    }
                    
                    if ($repositoryExists) {
                        # Check if it's git-controlled
                        if ($isRunningInWSL) {
                            # Already in WSL, run git directly
                            Push-Location $repositoryDir
                            try {
                                $gitCheckResult = git rev-parse --git-dir 2>&1
                                $repositoryIsGitControlled = ($LASTEXITCODE -eq 0)
                            } finally {
                                Pop-Location
                            }
                        } else {
                            # Running from Windows, use wsl command
                            $gitCheckResult = & wsl -- bash -c "cd '$repositoryDir' && git rev-parse --git-dir" 2>&1
                            $repositoryIsGitControlled = ($LASTEXITCODE -eq 0)
                        }
                    }
                } else {
                    # Check Windows directory
                    $repositoryExists = Test-Path $repositoryDir
                    
                    if ($repositoryExists) {
                        # Check if it's git-controlled
                        Push-Location $repositoryDir
                        try {
                            $null = git rev-parse --git-dir 2>&1
                            $repositoryIsGitControlled = ($LASTEXITCODE -eq 0)
                        } finally {
                            Pop-Location
                        }
                    }
                }
                
                Write-Host ""
                if ($repositoryExists) {
                    if ($repositoryIsGitControlled) {
                        Write-Success "Repository directory exists and is git-controlled"
                        Write-Info "Using existing repository at: $repositoryDir"
                        
                        # Update project path to use the existing repository
                        if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL") {
                            $ProjectPath = "$repositoryDir/services/$ProjectName"
                        } else {
                            $ProjectPath = Join-Path $repositoryDir "services\$ProjectName"
                        }
                        
                        Write-Success "Updated project path: $ProjectPath"
                        
                        # Set git context for existing repository
                        $Global:GitContext.IsGitControlled = $true
                        $Global:GitContext.ProjectPath = $ProjectPath
                        $Global:GitContext.RemoteUrl = $remoteUrl
                        
                    } else {
                        Write-Warning "Repository directory exists but is not git-controlled"
                        Write-Host ""
                        Write-Host "� Directory Status" -ForegroundColor Yellow
                        Write-Host "The directory '$repositoryDir' exists but is not a git repository." -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "Options:" -ForegroundColor Cyan
                        Write-Host "  [r] Remove directory and clone fresh (recommended)" -ForegroundColor White
                        Write-Host "  [i] Initialize git in existing directory" -ForegroundColor White
                        Write-Host "  [a] Abort git setup" -ForegroundColor Gray
                        Write-Host ""
                        
                        $handleOption = Read-UserPrompt -Prompt "How to handle non-git directory?" -ValidValues @("r","i","a")
                        
                        if ($handleOption -eq "a") {
                            Write-Info "Git setup aborted by user"
                            $Global:GitContext.SkipGit = $true
                            $Global:PhaseSkips.Git = $true
                            $Global:PhaseSkips.Pipeline = $true
                        } elseif ($handleOption -eq "i") {
                            Write-Info "Will initialize git repository in existing directory"
                            $Global:GitContext.WillInitializeGit = $true
                            $Global:GitContext.RemoteUrl = $remoteUrl
                            $Global:GitContext.ProjectPath = $ProjectPath
                        } elseif ($handleOption -eq "r") {
                            Write-Progress "Removing existing directory..."
                            $params = @{
                                RepositoryDir = $repositoryDir
                                RemoteUrl = $remoteUrl
                                UseWSL = ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL")
                            }
                            if (${what-if}) { $params['WhatIf'] = ${what-if} }
                            
                            if (-not (Invoke-RepositoryClone @params)) {
                                Write-Error "Failed to clone repository after removing existing directory"
                                return $false
                            }
                            
                            # Update project path and context
                            if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL") {
                                $ProjectPath = "$repositoryDir/services/$ProjectName"
                            } else {
                                $ProjectPath = Join-Path $repositoryDir "services\$ProjectName"
                            }
                            
                            $Global:GitContext.IsGitControlled = $true
                            $Global:GitContext.ProjectPath = $ProjectPath
                            $Global:GitContext.RemoteUrl = $remoteUrl
                        }
                    }
                } else {
                    Write-Info "Repository directory does not exist"
                    Write-Progress "Cloning repository..."
                    
                    $params = @{
                        RepositoryDir = $repositoryDir
                        RemoteUrl = $remoteUrl
                        UseWSL = ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL")
                    }
                    if (${what-if}) { $params['WhatIf'] = ${what-if} }
                    
                    if (-not (Invoke-RepositoryClone @params)) {
                        Write-Error "Failed to clone repository"
                        return $false
                    }
                    
                    # Update project path and context
                    if ($UseWSLForGit -or $EffectiveRequiresWSL -or $TargetPlatform -eq "WSL") {
                        $ProjectPath = "$repositoryDir/services/$ProjectName"
                    } else {
                        $ProjectPath = Join-Path $repositoryDir "services\$ProjectName"
                    }
                    
                    $Global:GitContext.IsGitControlled = $true
                    $Global:GitContext.ProjectPath = $ProjectPath
                    $Global:GitContext.RemoteUrl = $remoteUrl
                }
            } else {
                # User doesn't want source control
                Write-Info "⏭️  Skipping source control setup"
                $Global:GitContext.SkipGit = $true
                $Global:PhaseSkips.Git = $true
                $Global:PhaseSkips.Pipeline = $true
                
                Write-Warning "Git and Pipeline phases will be skipped"
            }
        }
        
        return $true
        
    } catch {
        Write-Error "Git workflow initialization failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-LoopSelection {
    <#
    .SYNOPSIS
    Shows available loops and allows user selection
    
    .DESCRIPTION
    Display available strangeloop templates and prompts user to select one
    
    .PARAMETER AvailableLoops
    Array of available loop objects
    
        
    .OUTPUTS
    Selected loop object or null
    #>
    param(
        [Parameter(Mandatory)]
        [array]$AvailableLoops
    )
    
    if ($false) {
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }
    
    try {
        Write-Host ""
        Write-Step "Available strangeloop Templates"
        Write-Host ""
        
        # Group loops by platform
        $groupedLoops = $AvailableLoops | Group-Object { 
            if ($_.platform) {
                $_.platform
            } else {
                'Windows'  # Default platform
            }
        }
        
        $index = 1
        $loopIndex = @{}
        
        foreach ($group in $groupedLoops) {
            Write-Host "  $($group.Name):" -ForegroundColor Cyan
            
            foreach ($loop in $group.Group) {
                $displayName = $loop.name
                $description = if ($loop.description) { " - $($loop.description)" } else { "" }
                Write-Host "    [$index] $displayName$description" -ForegroundColor White
                $loopIndex[$index] = $loop
                $index++
            }
            Write-Host ""
        }
        
        do {
            $selection = Read-UserPrompt -Prompt "Select a template (1-$($AvailableLoops.Count)) or 'q' to quit"
            
            if ($selection -eq 'q' -or $selection -eq 'quit') {
                return @{
                    Success = $false
                    ProjectPath = $null
                    ProjectName = $null
                    LoopName = $null
                }
            }
            
            $selectedIndex = $null
            if ([int]::TryParse($selection, [ref]$selectedIndex) -and $loopIndex.ContainsKey($selectedIndex)) {
                $selectedLoop = $loopIndex[$selectedIndex]
                Write-Host ""
                Write-Info "Selected: $($selectedLoop.name)"
                if ($selectedLoop.description) {
                    Write-Host "  Description: $($selectedLoop.description)" -ForegroundColor Gray
                }
                return @{
                    Success = $true
                    ProjectPath = $null
                    ProjectName = $null
                    LoopName = $selectedLoop.name
                    SelectedLoop = $selectedLoop
                }
            } else {
                Write-Warning "Invalid selection. Please enter a number between 1 and $($AvailableLoops.Count) or 'q' to quit."
            }
        } while ($true)
        
    } catch {
        Write-Warning "Error in loop selection: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }
}

function Get-ProjectDetails {
    <#
    .SYNOPSIS
    Collects project details from user input
    
    .DESCRIPTION
    Prompts user for project name and parent path, with validation
    
    .PARAMETER DefaultProjectName
    Default project name to suggest
    
    .PARAMETER DefaultProjectPath
    Default parent directory path to suggest (project folder will be created within this)
    
    .PARAMETER LoopName
    Name of the loop template being used
    
    .PARAMETER BaseDirectory
    Base directory for project path suggestions
    
    .PARAMETER RequiresWSL
    Indicates if this is a WSL project, affects path suggestions
    
    .PARAMETER SkipProjectName
    Skip prompting for project name (already provided)
    
    .PARAMETER SkipProjectPath
    Skip prompting for project parent path (already provided)
    
    .OUTPUTS
    Hashtable with ProjectName and ProjectPath (full path to project directory)
    #>
    param(
        [string]$DefaultProjectName,
        [string]$DefaultProjectPath,
        [string]${loop-name},
        [string]${base-directory},
        [switch]${requires-wsl},
        [switch]$SkipProjectName,
        [switch]$SkipProjectPath
    )
    
    if ($false) {
        # Generate defaults if not provided
        $projectName = if ($DefaultProjectName) { $DefaultProjectName } else { "test-strangeloop-app" }
        $projectPath = if ($DefaultProjectPath) { 
            $DefaultProjectPath 
        } else {
            # Generate default path based on loop name and platform using centralized configuration
            if (${loop-name}) {
                # Use centralized platform detection
                $targetPlatform = Get-PlatformForLoop -LoopName ${loop-name}
                
                if ($targetPlatform -eq "Windows") {
                    "Q:\src\AdsSnR_Containers\services\$projectName"
                } elseif (${requires-wsl} -or $targetPlatform -eq "WSL") {
                    # Use WSL Linux path for WSL/Linux loops or when explicitly requiring WSL
                    try {
                        # Detect if we're running within WSL or from Windows
                        if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) {
                            # Running within WSL - use direct whoami
                            $wslUser = & whoami 2>&1
                        } else {
                            # Running from Windows - use wsl command
                            $wslUser = & wsl -- whoami 2>&1
                        }
                        
                        if ($wslUser -and $LASTEXITCODE -eq 0) {
                            "/home/$($wslUser.Trim())/AdsSnR_Containers/services/$projectName"
                        } else {
                            "/home/{USER}/AdsSnR_Containers/services/$projectName"
                        }
                    } catch {
                        "/home/{USER}/AdsSnR_Containers/services/$projectName"
                    }
                } else {
                    $baseDir = if (${base-directory}) { ${base-directory} } else { Get-Location }
                    Join-Path $baseDir "AdsSnR_Containers\services\$projectName"
                }
            } else {
                if (${requires-wsl}) {
                    "/home/{USER}/AdsSnR_Containers/services/$projectName"
                } else {
                    "Q:\src\AdsSnR_Containers\services\$projectName"
                }
            }
        }
        
        return @{
            ProjectName = $projectName
            ProjectPath = $projectPath
        }
    }
    
    try {
        Write-Host ""
        Write-Step "Project Configuration"
        
        # Get project name
        if ($SkipProjectName) {
            # Use the provided default project name
            $projectName = $DefaultProjectName
            Write-Info "Using provided project name: $projectName"
        } else {
            do {
                if ($DefaultProjectName) {
                    $inputName = Read-UserPrompt -Prompt "Project name" -DefaultValue $DefaultProjectName
                } else {
                    $inputName = Read-UserPrompt -Prompt "Project name"
                }
                
                if ([string]::IsNullOrWhiteSpace($inputName) -and $DefaultProjectName) {
                    $projectName = $DefaultProjectName
                } elseif ([string]::IsNullOrWhiteSpace($inputName)) {
                    Write-Warning "Project name cannot be empty"
                    continue
                } else {
                    $projectName = $inputName.Trim()
                }
                
                # Validate project name
                if ($projectName -match '[<>:"/\\|?*]') {
                    Write-Warning "Project name contains invalid characters"
                    continue
                }
                
                break
            } while ($true)
        }
        
        # Get project path
        if ($SkipProjectPath) {
            # Use the provided default project path as parent directory
            $projectParentPath = $DefaultProjectPath
            Write-Info "Using provided project parent directory: $projectParentPath"
            
            # Construct full project path by combining parent path with project name
            if ($projectParentPath.StartsWith("/") -or $projectParentPath.Contains("/home/")) {
                # WSL path - use forward slash
                $projectPath = "$projectParentPath/$projectName"
            } else {
                # Windows path - use Join-Path for proper path handling
                $projectPath = Join-Path $projectParentPath $projectName
            }
            Write-Info "Full project path: $projectPath"
        } else {
            do {
                # Always recalculate suggested path with current project name using centralized configuration
                $targetPlatform = Get-PlatformForLoop -LoopName ${loop-name}
                
                if ($targetPlatform -eq "Windows") {
                    # Use Q:\src\AdsSnR_Containers\services for Windows loops
                    $suggestedPath = "Q:\src\AdsSnR_Containers\services"
                } elseif ($targetPlatform -eq "WSL") {
                    # Use WSL Linux path for WSL loops
                    try {
                        $wslUser = & wsl -- whoami 2>&1
                        if ($wslUser) {
                            $suggestedPath = "/home/$($wslUser.Trim())/AdsSnR_Containers/services"
                        } else {
                            $suggestedPath = "/home/{USER}/AdsSnR_Containers/services"
                        }
                    } catch {
                        $suggestedPath = "/home/{USER}/AdsSnR_Containers/services"
                    }
                } elseif (${requires-wsl}) {
                    # Use WSL Linux path for WSL/Linux loops
                    try {
                        $wslUser = & wsl -- whoami 2>&1
                        if ($wslUser) {
                            $suggestedPath = "/home/$($wslUser.Trim())/AdsSnR_Containers/services"
                        } else {
                            $suggestedPath = "/home/{USER}/AdsSnR_Containers/services"
                        }
                    } catch {
                        $suggestedPath = "/home/{USER}/AdsSnR_Containers/services"
                    }
                } else {
                    # Use relative path as fallback
                    $baseDir = if (${base-directory}) { ${base-directory} } else { Get-Location }
                    Write-Verbose "Using BaseDirectory: $baseDir" 
                    $suggestedPath = Join-Path $baseDir "AdsSnR_Containers\services"
                }
                
                $inputPath = Read-UserPrompt -Prompt "Project parent directory" -DefaultValue $suggestedPath
            
            if ([string]::IsNullOrWhiteSpace($inputPath)) {
                $projectParentPath = $suggestedPath
            } else {
                $projectParentPath = $inputPath.Trim()
            }
            
            # Expand environment variables
            $projectParentPath = [Environment]::ExpandEnvironmentVariables($projectParentPath)
            
            # Convert to absolute path (handle WSL paths differently)
            if ($projectParentPath.StartsWith("/") -or $projectParentPath.Contains("/home/")) {
                # This is a WSL/Linux path, don't try to convert it using Windows logic
                Write-Verbose "Using WSL/Linux parent path: $projectParentPath"
            } elseif (-not [System.IO.Path]::IsPathRooted($projectParentPath)) {
                $projectParentPath = Join-Path $PWD $projectParentPath
            }
            
            # Construct full project path by combining parent path with project name
            if ($projectParentPath.StartsWith("/") -or $projectParentPath.Contains("/home/")) {
                # WSL path - use forward slash
                $projectPath = "$projectParentPath/$projectName"
            } else {
                # Windows path - use Join-Path for proper path handling
                $projectPath = Join-Path $projectParentPath $projectName
            }
            
            # Check if path exists and is not empty (handle WSL paths)
            $pathExists = $false
            $pathHasItems = $false
            
            if ($projectPath.StartsWith("/") -or $projectPath.Contains("/home/")) {
                # WSL path - check using WSL commands
                try {
                    $null = & wsl test -d "$projectPath" 2>&1
                    $pathExists = ($LASTEXITCODE -eq 0)
                    if ($pathExists) {
                        $items = & wsl ls -la "$projectPath" 2>&1
                        $pathHasItems = ($items -and ($items | Where-Object { $_ -and $_ -notmatch "^total" -and $_ -notmatch "^\.\s" -and $_ -notmatch "^\.\.\s" }).Count -gt 0)
                    }
                } catch {
                    Write-Verbose "Could not check WSL path existence: $($_.Exception.Message)"
                }
            } else {
                # Windows path - use normal Test-Path
                $pathExists = Test-Path $projectPath
                if ($pathExists) {
                    $items = Get-ChildItem $projectPath -ErrorAction SilentlyContinue
                    $pathHasItems = ($items -and $items.Count -gt 0)
                }
            }
            
            if ($pathExists -and $pathHasItems) {
                # Check if it's already a strangeloop project
                $isstrangeloopProject = $false
                
                if ($projectPath.StartsWith("/") -or $projectPath.Contains("/home/")) {
                    # WSL path - check using WSL commands
                    try {
                        $null = & wsl test -d "$projectPath/strangeloop" 2>&1
                        $strangeloopExists = ($LASTEXITCODE -eq 0)
                        $null = & wsl test -f "$projectPath/strangeloop/settings.yaml" 2>&1
                        $settingsExists = ($LASTEXITCODE -eq 0)
                        $isstrangeloopProject = $strangeloopExists -and $settingsExists
                    } catch {
                        Write-Verbose "Could not check WSL strangeloop project structure: $($_.Exception.Message)"
                    }
                } else {
                    # Windows path - use normal Test-Path
                    $strangeLoopDir = Join-Path $projectPath "strangeloop"
                    $settingsPath = Join-Path $strangeLoopDir "settings.yaml"
                    $isstrangeloopProject = (Test-Path $strangeLoopDir) -and (Test-Path $settingsPath)
                }
                
                if ($isstrangeloopProject) {
                    Write-Info "strangeloop project already exists at: $projectPath"
                    Write-Info "Using existing project"
                    break  # Use existing strangeloop project
                } else {
                    # Directory exists but not a strangeloop project
                    Write-Warning "Directory '$projectPath' already exists and is not empty"
                    $confirm = Read-UserPrompt -Prompt "Continue anyway?" -ValidValues @("y","n")
                    if (-not (Test-YesResponse $confirm)) {
                        continue
                    }
                }
            }
            
            break
        } while ($true)
        }
        
        return @{
            Success = $true
            ProjectName = $projectName
            ProjectPath = $projectPath
        }
        
    } catch {
        Write-Warning "Error collecting project details: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = ${loop-name}
        }
    }
}

function New-strangeloopProject {
    <#
    .SYNOPSIS
    Creates a new strangeloop project from a template
    
    .DESCRIPTION
    Initializes a new project using the strangeloop CLI with the specified template
    
    .PARAMETER ProjectName
    Name of the project to create
    
    .PARAMETER LoopName
    Name of the loop template to use
    
    .PARAMETER ProjectPath
    Path where the project should be created
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]${project-name},
        [Parameter(Mandatory)]
        [string]${loop-name},
        [Parameter(Mandatory)]
        [string]${project-path},
        [switch]${what-if}
    )
    
    try {
        Write-Step "Creating strangeloop Project"
        Write-Info "Project: ${project-name}"
        Write-Info "Template: ${loop-name}"
        Write-Info "Path: ${project-path}"
        
        # Validate platform prerequisites before project creation
        $targetPlatform = Get-PlatformForLoop -LoopName ${loop-name}
        Write-Host "🔧 Validating target platform prerequisites ($targetPlatform)..." -ForegroundColor Cyan
        
        # Set working directory context for prerequisites check (same as strangeloop commands)
        $originalLocation = Get-Location
        try {
            # Change to project parent directory (where strangeloop commands will run)
            $parentDir = Split-Path ${project-path} -Parent
            if ($parentDir -and (Test-Path $parentDir)) {
                Set-Location $parentDir
                Write-Verbose "Prerequisites check running from: $parentDir"
            }
            
            # Run prerequisites check for the target platform (Windows projects run on Windows)
            $prereqsResult = & strangeloop cli prereqs 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Target platform prerequisites validated successfully for $targetPlatform"
            } else {
                Write-Warning "Target platform prerequisites check completed with warnings for $targetPlatform - continuing project setup"
                Write-Host "Prerequisites output: $prereqsResult" -ForegroundColor Yellow
            }
        } catch {
            Write-Warning "Could not run target platform prerequisites check for $targetPlatform`: $($_.Exception.Message) - continuing project setup"
        } finally {
            Set-Location $originalLocation
        }
        Write-Host ""
        
        # Ensure parent directory exists
        $parentDir = Split-Path ${project-path} -Parent
        if (-not (Test-Path $parentDir)) {
            Write-Info "Creating parent directory: $parentDir"
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        
        # Check if project directory already exists (strangeloop will create it with --name parameter)
        if (Test-Path ${project-path}) {
            # Check if it's already a strangeloop project
            $strangeLoopDir = Join-Path ${project-path} "strangeloop"
            $settingsPath = Join-Path $strangeLoopDir "settings.yaml"
            
            if ((Test-Path $strangeLoopDir) -and (Test-Path $settingsPath)) {
                # It's an existing strangeloop project
                Write-Warning "strangeloop project already exists at: ${project-path}"
                $response = Read-UserPrompt -Prompt "Overwrite existing strangeloop project?" -ValidValues @("y","n")
                if (-not (Test-YesResponse $response)) {
                    Write-Info "Using existing strangeloop project without overwriting"
                    # Return success but indicate it's an existing project
                    # Don't return early - let the workflow continue for git and pipeline setup
                    Write-Success "Project will use existing strangeloop configuration"
                    return @{
                        Success = $true
                        ProjectPath = ${project-path}
                        ProjectName = ${project-name}
                        LoopName = ${loop-name}
                        ExistingProject = $true
                        SkipProjectCreation = $true
                    }
                }
                
                # User confirmed to overwrite
                Write-Info "Removing existing strangeloop project"
                
                # Reset any Git changes to avoid "git checkout is not clean" errors
                if ($true) {  # Always try to reset git changes
                    Write-Progress "Resetting any Git changes in existing project..."
                    try {
                        & git -C ${project-path} reset --hard HEAD
                        if ($LASTEXITCODE -eq 0) {
                            Write-Info "Git changes reset successfully"
                        } else {
                            Write-Info "No Git repository found or reset not needed (exit code: $LASTEXITCODE)"
                        }
                    } catch {
                        Write-Info "Git reset skipped (no Git repository or other issue)"
                        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
                
                Remove-Item ${project-path} -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                # Directory exists but is not a strangeloop project, check if it has content
                $dirContent = Get-ChildItem ${project-path} -ErrorAction SilentlyContinue
                $hasContent = ($dirContent -and $dirContent.Count -gt 0)
                
                if ($hasContent) {
                    # Directory has content, ask user if they want to overwrite
                    Write-Warning "Directory already exists and contains files: ${project-path}"
                    $response = Read-UserPrompt -Prompt "Overwrite existing directory?" -ValidValues @("y","n")
                    if (-not (Test-YesResponse $response)) {
                        Write-Warning "Project creation cancelled by user"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = $null
                        }
                    }
                    
                    # User confirmed to overwrite
                    Write-Info "Removing existing directory"
                    
                    # Reset any Git changes to avoid "git checkout is not clean" errors
                    if ($true) {  # Always try to reset git changes
                        Write-Progress "Resetting any Git changes in existing directory..."
                        try {
                            & git -C ${project-path} reset --hard HEAD
                            if ($LASTEXITCODE -eq 0) {
                                Write-Info "Git changes reset successfully"
                            } else {
                                Write-Info "No Git repository found or reset not needed (exit code: $LASTEXITCODE)"
                            }
                        } catch {
                            Write-Info "Git reset skipped (no Git repository or other issue)"
                        }
                    }
                    
                    Remove-Item ${project-path} -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    # Directory is empty, remove it so strangeloop can create it fresh
                    Write-Info "Directory exists but is empty, removing for fresh creation"
                    Remove-Item ${project-path} -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        # Create project using strangeloop CLI
        Write-Progress "Creating project from template..."
        
        # Ensure parent directory exists (strangeloop will create the project directory with the --name parameter)
        $parentDir = Split-Path ${project-path} -Parent
        if (-not (Test-Path $parentDir)) {
            Write-Info "Creating parent directory: $parentDir"
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        
        # Execute strangeloop CLI from the parent directory
        try {
            # Clear cache before initialization
            if (${what-if}) {
                Write-Host "🔍 (what-if) Would clear strangeloop cache" -ForegroundColor Yellow
                Write-Host "🔍 (what-if) Would run: strangeloop library-registry clear-cache" -ForegroundColor Yellow
            } else {
                Write-Info "Clearing strangeloop cache..."
                $clearProcess = Start-Process -FilePath "strangeloop" -ArgumentList @("library-registry", "clear-cache") -Wait -PassThru -NoNewWindow
                
                if ($clearProcess.ExitCode -ne 0) {
                    Write-Warning "Failed to clear strangeloop cache, but continuing with initialization..."
                }
            }
            
            # Build CLI command - use init with --name parameter (run from parent directory)
            $cliArgs = @(
                "--force",
                "init",
                "--loop", ${loop-name},
                "--name", ${project-name}
            )
            
            if (${what-if}) {
                Write-Host "🔍 (what-if) Would create strangeloop project" -ForegroundColor Yellow
                Write-Host "🔍 (what-if) Would run: strangeloop $($cliArgs -join ' ')" -ForegroundColor Yellow
                Write-Host "🔍 (what-if) Working directory: $parentDir" -ForegroundColor Yellow
                Write-Success "(what-if) Project would be created with name: ${project-name}"
            } else {
                # Use Start-Process to run with real-time console output from parent directory
                $process = Start-Process -FilePath "strangeloop" -ArgumentList $cliArgs -WorkingDirectory $parentDir -Wait -PassThru -NoNewWindow
                
                $exitCode = $process.ExitCode
                
                if ($exitCode -ne 0) {
                    Write-Warning "strangeloop project creation failed with exit code: $exitCode"
                    return @{
                        Success = $false
                        ProjectPath = $null
                        ProjectName = $null
                        LoopName = $null
                    }
                }
                
                Write-Success "Project created with name: ${project-name}"
            }
        } catch {
            Write-Warning "Error executing strangeloop CLI: $($_.Exception.Message)"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        # Verify project was created
        if (-not (Test-Path ${project-path})) {
            Write-Warning "Project directory was not created: ${project-path}"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        Write-Success "Project created successfully at: ${project-path}"
        
        return @{
            Success = $true
            ProjectPath = ${project-path}
            ProjectName = ${project-name}
            LoopName = ${loop-name}
            ExistingProject = $false
        }
        
    } catch {
        Write-Warning "Error creating strangeloop project: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }
}

function New-strangeloopProjectWSL {
    <#
    .SYNOPSIS
    Creates a new strangeloop project in WSL environment
    
    .DESCRIPTION
    Initializes a new project using the strangeloop CLI in WSL with the specified template
    
    .PARAMETER ProjectName
    Name of the project to create
    
    .PARAMETER LoopName
    Name of the loop template to use
    
    .PARAMETER ProjectPath
    Path where the project should be created (WSL path)
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]${project-name},
        [Parameter(Mandatory)]
        [string]${loop-name},
        [Parameter(Mandatory)]
        [string]${project-path},
        [switch]${what-if}
    )
    
    try {
        Write-Step "Creating strangeloop Project in WSL"
        Write-Info "Project: ${project-name}"
        Write-Info "Template: ${loop-name}"
        Write-Info "WSL Path: ${project-path}"
        
        # Validate platform prerequisites before project creation
        $targetPlatform = Get-PlatformForLoop -LoopName ${loop-name}
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        Write-Host "🔧 Validating target platform prerequisites ($targetPlatform)..." -ForegroundColor Cyan
        
        # Set working directory context for prerequisites check (same as strangeloop commands)
        $originalLocation = Get-Location
        try {
            # For WSL target projects, ensure prerequisites are checked in WSL environment
            if ($targetPlatform -eq "WSL") {
                if ($currentPlatform -eq "WSL") {
                    # Already in WSL - run prerequisites check directly
                    $prereqsResult = & strangeloop cli prereqs 2>&1
                } else {
                    # In Windows but targeting WSL - run prerequisites check in WSL
                    $prereqsResult = & wsl -- strangeloop cli prereqs 2>&1
                }
            } else {
                # Targeting Windows - run prerequisites check on current platform
                $prereqsResult = & strangeloop cli prereqs 2>&1
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Target platform prerequisites validated successfully for $targetPlatform"
            } else {
                Write-Warning "Target platform prerequisites check completed with warnings for $targetPlatform - continuing project setup"
                Write-Host "Prerequisites output: $prereqsResult" -ForegroundColor Yellow
            }
        } catch {
            Write-Warning "Could not run target platform prerequisites check for $targetPlatform`: $($_.Exception.Message) - continuing project setup"
        } finally {
            Set-Location $originalLocation
        }
        Write-Host ""
        
        # Check if WSL is available (only when running from Windows and targeting WSL)
        if (-not $isRunningInWSL -and -not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            Write-Warning "WSL is required but not available on Windows host"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        # Use WSL path format
        $wslProjectPath = if (${project-path}.StartsWith("/")) { 
            ${project-path} 
        } else { 
            try {
                if ($isRunningInWSL) {
                    $wslUser = & whoami 2>&1
                } else {
                    $wslUser = & wsl -- whoami 2>&1
                }
                if ($wslUser) {
                    "/home/$($wslUser.Trim())/AdsSnR_Containers/services/${project-name}"
                } else {
                    "/home/{USER}/AdsSnR_Containers/services/${project-name}"
                }
            } catch {
                "/home/{USER}/AdsSnR_Containers/services/${project-name}"
            }
        }
        
        # Check if project already exists in WSL (strangeloop will create the directory with --name parameter)
        if ($isRunningInWSL) {
            # Already in WSL, test directory directly
            $projectExists = Test-Path $wslProjectPath
        } else {
            # Running from Windows, use wsl command
            $null = & wsl -- test -d $wslProjectPath 2>$null
            $projectExists = ($LASTEXITCODE -eq 0)
        }
        
        if ($projectExists) {
            # Directory exists, check if it has strangeloop project
            if ($isRunningInWSL) {
                # Already in WSL, test directory directly
                $strangeloopExists = Test-Path "$wslProjectPath/strangeloop"
            } else {
                # Running from Windows, use wsl command
                $null = & wsl -- test -d "$wslProjectPath/strangeloop" 2>$null
                $strangeloopExists = ($LASTEXITCODE -eq 0)
            }
            
            if ($strangeloopExists) {
                # It's a strangeloop project
                Write-Warning "strangeloop project already exists in WSL at $wslProjectPath"
                $response = Read-UserPrompt -Prompt "Do you want to overwrite it?" -ValidValues @("y","n")
                
                if (-not (Test-YesResponse $response)) {
                    Write-Info "Using existing strangeloop project without overwriting"
                    # Return success but indicate it's an existing project
                    # Don't return early - let the workflow continue for git and pipeline setup
                    Write-Success "Project will use existing strangeloop configuration"
                    return @{
                        Success = $true
                        ProjectPath = ${project-path}
                        ProjectName = ${project-name}
                        LoopName = ${loop-name}
                        ExistingProject = $true
                        SkipProjectCreation = $true
                    }
                }
                
                Write-Info "Removing existing project..."
                
                # Reset any Git changes to avoid "git checkout is not clean" errors
                if ($true) {  # Always try to reset git changes
                    Write-Progress "Resetting any Git changes in existing project..."
                    try {
                        if ($isRunningInWSL) {
                            # Already in WSL, run git directly
                            Push-Location $wslProjectPath
                            try {
                                git reset --hard HEAD
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Info "Git changes reset successfully"
                                } else {
                                    Write-Info "No Git repository found or reset not needed (exit code: $LASTEXITCODE)"
                                }
                            } finally {
                                Pop-Location
                            }
                        } else {
                            # Running from Windows, use wsl command
                            & wsl -- bash -c "cd '$wslProjectPath' && git reset --hard HEAD" 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-Info "Git changes reset successfully"
                            } else {
                                Write-Info "No Git repository found or reset not needed (exit code: $LASTEXITCODE)"
                            }
                        }
                    } catch {
                        Write-Info "Git reset skipped (no Git repository or other issue)"
                    }
                }
                
                if ($isRunningInWSL) {
                    # Already in WSL, remove directory directly
                    $removeResult = & rm -rf $wslProjectPath 2>&1
                } else {
                    # Running from Windows, use wsl command
                    $removeResult = & wsl -- rm -rf $wslProjectPath 2>&1
                }
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to remove existing project: $removeResult"
                    return @{
                        Success = $false
                        ProjectPath = $null
                        ProjectName = $null
                        LoopName = $null
                    }
                }
            } else {
                # Directory exists but not a strangeloop project, check if it has content
                if ($isRunningInWSL) {
                    # Already in WSL, list directory directly
                    $dirContent = & ls -la "$wslProjectPath" 2>&1
                } else {
                    # Running from Windows, use wsl command
                    $dirContent = & wsl -- ls -la "$wslProjectPath" 2>&1
                }
                $hasContent = $false
                
                if ($LASTEXITCODE -eq 0 -and $dirContent) {
                    # Count actual files (excluding . and .. and total line)
                    $fileLines = $dirContent | Where-Object { 
                        $_ -and 
                        $_ -notmatch '^\s*total\s+' -and 
                        $_ -notmatch '\s+\.$' -and 
                        $_ -notmatch '\s+\.\.$'
                    }
                    $fileCount = if ($fileLines) { 
                        if ($fileLines.Count) { $fileLines.Count } else { 1 }
                    } else { 0 }
                    $hasContent = ($fileCount -gt 0)
                    
                    Write-Verbose "Directory content check: Found $fileCount actual files/directories"
                }
                
                if ($hasContent) {
                    # Directory has content, ask user if they want to overwrite
                    Write-Warning "Directory already exists in WSL and contains files: $wslProjectPath"
                    $response = Read-UserPrompt -Prompt "Do you want to overwrite this directory?" -ValidValues @("y","n")
                    
                    if (-not (Test-YesResponse $response)) {
                        Write-Info "Project creation cancelled by user"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = $null
                        }
                    }
                    
                    Write-Info "Removing existing directory..."
                    
                    # Reset any Git changes to avoid "git checkout is not clean" errors
                    Write-Progress "Resetting any Git changes in existing directory..."
                    try {
                        if ($isRunningInWSL) {
                            # Already in WSL, run git directly
                            Write-Host "Executing: git reset --hard HEAD in $wslProjectPath" -ForegroundColor Cyan
                            Push-Location $wslProjectPath
                            try {
                                git reset --hard HEAD
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Info "Git changes reset successfully"
                                } else {
                                    Write-Info "No Git repository found or reset not needed"
                                }
                            } finally {
                                Pop-Location
                            }
                        } else {
                            # Running from Windows, use wsl command
                            Write-Host "Executing: git reset --hard HEAD in $wslProjectPath" -ForegroundColor Cyan
                            & wsl -- bash -c "cd '$wslProjectPath' && git reset --hard HEAD" 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Info "Git changes reset successfully"
                            } else {
                                Write-Info "No Git repository found or reset not needed"
                            }
                        }
                    } catch {
                        Write-Info "Git reset skipped (no Git repository or other issue)"
                    }
                    
                    if ($isRunningInWSL) {
                        # Already in WSL, remove directory directly
                        $removeResult = & rm -rf $wslProjectPath 2>&1
                    } else {
                        # Running from Windows, use wsl command
                        $removeResult = & wsl -- rm -rf $wslProjectPath 2>&1
                    }
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to remove existing directory: $removeResult"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = $null
                        }
                    }
                } else {
                    # Directory is empty, remove it so strangeloop can create it fresh
                    Write-Info "Directory exists but is empty, removing for fresh creation"
                    if ($isRunningInWSL) {
                        # Already in WSL, remove directory directly
                        $removeResult = & rm -rf $wslProjectPath 2>&1
                    } else {
                        # Running from Windows, use wsl command
                        $removeResult = & wsl -- rm -rf $wslProjectPath 2>&1
                    }
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to remove existing directory: $removeResult"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = $null
                        }
                    }
                }
            }
        }
        
        # Ensure parent directory exists in WSL
        $parentDirPath = if ($wslProjectPath.Contains("/")) {
            # Unix path - handle manually to avoid Windows path semantics
            $lastSlashIndex = $wslProjectPath.LastIndexOf('/')
            if ($lastSlashIndex -gt 0) {
                $wslProjectPath.Substring(0, $lastSlashIndex)
            } else {
                "/"
            }
        } else {
            Split-Path $wslProjectPath -Parent
        }
        
        if ($isRunningInWSL) {
            # Already in WSL, create directory directly
            $mkdirResult = & mkdir -p $parentDirPath 2>&1
        } else {
            # Running from Windows, use wsl command
            $mkdirResult = & wsl -- mkdir -p $parentDirPath 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create parent directory in WSL: $mkdirResult"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        Write-Progress "Initializing strangeloop project in WSL..."
        
        # Clear cache before initialization
        Write-Info "Clearing strangeloop cache in WSL..."
        if ($isRunningInWSL) {
            # Already in WSL, run strangeloop directly
            $clearProcess = Start-Process -FilePath "strangeloop" -ArgumentList @("library-registry", "clear-cache") -Wait -PassThru -NoNewWindow
        } else {
            # Running from Windows, use wsl command
            $clearProcess = Start-Process -FilePath "wsl" -ArgumentList @("--", "strangeloop", "library-registry", "clear-cache") -Wait -PassThru -NoNewWindow
        }
        
        if ($clearProcess.ExitCode -ne 0) {
            Write-Warning "Failed to clear strangeloop cache in WSL, but continuing with initialization..."
        }
        
        # Execute strangeloop CLI from parent directory with --name parameter
        $parentDirPath = if ($wslProjectPath.Contains("/")) {
            # Unix path - handle manually to avoid Windows path semantics
            $lastSlashIndex = $wslProjectPath.LastIndexOf('/')
            if ($lastSlashIndex -gt 0) {
                $wslProjectPath.Substring(0, $lastSlashIndex)
            } else {
                "/"
            }
        } else {
            Split-Path $wslProjectPath -Parent
        }
        
        # Execute strangeloop init command from parent directory (where the project will be created)
        $combinedCommand = "cd `"$parentDirPath`" && strangeloop --force init --loop '${loop-name}' --name '${project-name}'"
        
        if (${what-if}) {
            Write-Host "🔍 (what-if) Would create strangeloop project in WSL" -ForegroundColor Yellow
            Write-Host "🔍 (what-if) Would execute in WSL: $combinedCommand" -ForegroundColor Yellow
        } else {
            Write-Info "Executing in WSL: $combinedCommand"
            
            # Use Start-Process to show real-time output but with proper command construction
            Write-Progress "Initializing strangeloop project (this may take a moment)..."
            try {
                # Execute the init command from parent directory with --name parameter
                $initCommand = "cd `"$parentDirPath`" && strangeloop --force init --loop '${loop-name}' --name '${project-name}'"
                
                if ($isRunningInWSL) {
                    # Already in WSL, execute bash directly
                    $null = & bash -c $initCommand 2>&1
                } else {
                    # Running from Windows, use wsl command
                    $null = & wsl.exe -- bash -c $initCommand 2>&1
                }
                $exitCode = $LASTEXITCODE
                
            } catch {
                Write-Warning "Error during project initialization: $($_.Exception.Message)"
                $exitCode = 1
            }
        }
        
        if ($exitCode -ne 0) {
            Write-Warning "strangeloop project creation failed in WSL with exit code: $exitCode"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        Write-Success "Project created with name: ${project-name}"
        
        # Verify project was created
        if ($isRunningInWSL) {
            # Already in WSL, test directory directly
            $verificationSuccess = Test-Path "$wslProjectPath/strangeloop"
        } else {
            # Running from Windows, use wsl command
            $null = & wsl -- test -d "$wslProjectPath/strangeloop" 2>$null
            $verificationSuccess = ($LASTEXITCODE -eq 0)
        }
        
        if (-not $verificationSuccess) {
            Write-Warning "Project verification failed - strangeloop directory not found"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
            }
        }
        
        Write-Success "strangeloop project created successfully in WSL at: $wslProjectPath"
        
        return @{
            Success = $true
            ProjectPath = ${project-path}
            ProjectName = ${project-name}
            LoopName = ${loop-name}
            ExistingProject = $false
        }
        
    } catch {
        Write-Warning "Error creating strangeloop project in WSL: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }
}

function initialize-projectWorkspace {
    <#
    .SYNOPSIS
    Initializes the project workspace with development tools
    
    .DESCRIPTION
    Sets up the created project with additional development tools and configurations
    
    .PARAMETER ProjectPath
    Path to the project directory
    
        
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [Parameter(Mandatory)]
        [string]${project-path}
    )
    
    try {
        # Determine current execution environment
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        Write-Info "Initializing project workspace..."
        
        # Determine if this is a WSL path
        $isWSLPath = ${project-path}.StartsWith("/") -or ${project-path}.Contains("/home/")
        
        if ($isWSLPath) {
            # Handle WSL project initialization
            Write-Info "Initializing WSL project workspace..."
            
            # Check for Python projects and install dependencies
            if ($isRunningInWSL) {
                # Already in WSL, test files directly
                $pyprojectExists = Test-Path "${project-path}/pyproject.toml"
                $requirementsExists = Test-Path "${project-path}/requirements.txt"
            } else {
                # Running from Windows, use wsl command
                $null = & wsl -- test -f "${project-path}/pyproject.toml" 2>$null
                $pyprojectExists = ($LASTEXITCODE -eq 0)
                $null = & wsl -- test -f "${project-path}/requirements.txt" 2>$null
                $requirementsExists = ($LASTEXITCODE -eq 0)
            }
            
            if ($pyprojectExists -or $requirementsExists) {
                Write-Progress "Installing Python dependencies in WSL..."
                
                if ($pyprojectExists -eq 0) {
                    Write-Info "Found pyproject.toml - installing with Poetry..."
                    if ($isRunningInWSL) {
                        # Already in WSL, run poetry directly
                        Push-Location ${project-path}
                        try {
                            $null = poetry install
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Poetry dependencies installed"
                            } else {
                                Write-Info "Poetry install completed with warnings"
                            }
                        } finally {
                            Pop-Location
                        }
                    } else {
                        # Running from Windows, use wsl command
                        $null = & wsl -- bash -c "cd '${project-path}' && poetry install" 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Poetry dependencies installed"
                        } else {
                            Write-Info "Poetry install completed with warnings"
                        }
                    }
                } elseif ($requirementsExists -eq 0) {
                    Write-Info "Found requirements.txt - installing with pip..."
                    if ($isRunningInWSL) {
                        # Already in WSL, run pip directly
                        Push-Location ${project-path}
                        try {
                            $null = pip install -r requirements.txt
                            if ($LASTEXITCODE -eq 0) {
                                Write-Success "Python dependencies installed"
                            } else {
                                Write-Info "Pip install completed with warnings"
                            }
                        } finally {
                            Pop-Location
                        }
                    } else {
                        # Running from Windows, use wsl command
                        $null = & wsl -- bash -c "cd '${project-path}' && pip install -r requirements.txt" 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "Python dependencies installed"
                        } else {
                            Write-Info "Pip install completed with warnings"
                        }
                    }
                }
            }
            
            # Check for .NET projects and restore packages
            if ($isRunningInWSL) {
                # Already in WSL, run find directly
                Push-Location ${project-path}
                try {
                    $csprojExists = find . -name "*.csproj" -type f | head -1
                    $hasCsproj = ($LASTEXITCODE -eq 0 -and $csprojExists)
                } finally {
                    Pop-Location
                }
            } else {
                # Running from Windows, use wsl command
                $csprojExists = & wsl -- bash -c "find '${project-path}' -name '*.csproj' -type f | head -1" 2>&1
                $hasCsproj = ($LASTEXITCODE -eq 0 -and $csprojExists)
            }
            
            if ($hasCsproj) {
                Write-Progress "Restoring .NET packages in WSL..."
                if ($isRunningInWSL) {
                    # Already in WSL, run dotnet directly
                    Push-Location ${project-path}
                    try {
                        $null = dotnet restore
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success ".NET packages restored"
                        } else {
                            Write-Info "Dotnet restore completed with warnings"
                        }
                    } finally {
                        Pop-Location
                    }
                } else {
                    # Running from Windows, use wsl command
                    $null = & wsl -- bash -c "cd '${project-path}' && dotnet restore" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success ".NET packages restored"
                    } else {
                        Write-Info "Dotnet restore completed with warnings"
                    }
                }
            }
        } else {
            # Handle Windows project initialization  
            Write-Info "Initializing Windows project workspace..."
            
            # Check for Python projects and install dependencies
            $pyprojectPath = Join-Path ${project-path} "pyproject.toml"
            $requirementsPath = Join-Path ${project-path} "requirements.txt"
            
            if ((Test-Path $pyprojectPath) -or (Test-Path $requirementsPath)) {
                Write-Progress "Installing Python dependencies..."
                
                if (Test-Path $pyprojectPath) {
                    $poetryProcess = New-Object System.Diagnostics.Process
                    $poetryProcess.StartInfo.FileName = "poetry"
                    $poetryProcess.StartInfo.Arguments = "install"
                    $poetryProcess.StartInfo.WorkingDirectory = ${project-path}
                    $poetryProcess.StartInfo.UseShellExecute = $false
                    $poetryProcess.StartInfo.RedirectStandardOutput = $true
                    $poetryProcess.StartInfo.RedirectStandardError = $true
                    $poetryProcess.Start() | Out-Null
                    $poetryProcess.WaitForExit()
                    
                    if ($poetryProcess.ExitCode -eq 0) {
                        Write-Success "Poetry dependencies installed"
                    }
                } elseif (Test-Path $requirementsPath) {
                    $pipProcess = New-Object System.Diagnostics.Process
                    $pipProcess.StartInfo.FileName = "pip"
                    $pipProcess.StartInfo.Arguments = "install -r requirements.txt"
                    $pipProcess.StartInfo.WorkingDirectory = ${project-path}
                    $pipProcess.StartInfo.UseShellExecute = $false
                    $pipProcess.StartInfo.RedirectStandardOutput = $true
                    $pipProcess.StartInfo.RedirectStandardError = $true
                    $pipProcess.Start() | Out-Null
                    $pipProcess.WaitForExit()
                    
                    if ($pipProcess.ExitCode -eq 0) {
                        Write-Success "Python dependencies installed"
                    }
                }
            }
            
            # Check for .NET projects and restore packages
            $csprojFiles = Get-ChildItem -Path ${project-path} -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
            if ($csprojFiles) {
                Write-Progress "Restoring .NET packages..."
                
                $dotnetProcess = New-Object System.Diagnostics.Process
                $dotnetProcess.StartInfo.FileName = "dotnet"
                $dotnetProcess.StartInfo.Arguments = "restore"
                $dotnetProcess.StartInfo.WorkingDirectory = ${project-path}
                $dotnetProcess.StartInfo.UseShellExecute = $false
                $dotnetProcess.StartInfo.RedirectStandardOutput = $true
                $dotnetProcess.StartInfo.RedirectStandardError = $true
                $dotnetProcess.Start() | Out-Null
                $dotnetProcess.WaitForExit()
                
                if ($dotnetProcess.ExitCode -eq 0) {
                    Write-Success ".NET packages restored"
                }
            }
        }
        
        return @{
            Success = $true
            ProjectPath = ${project-path}
            ProjectName = $null
            LoopName = $null
        }
        
    } catch {
        Write-Warning "Error initializing project workspace: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = $null
        }
    }
}

function Start-ProjectInitialization {
    <#
    .SYNOPSIS
    Main function to start the project initialization process
    
    .DESCRIPTION
    Orchestrates the complete project creation workflow including loop selection and project setup
    
    .PARAMETER ProjectName
    Name of the project (optional, will prompt if not provided)
    
    .PARAMETER LoopName
    Name of the loop template (optional, will show selection if not provided)
    
    .PARAMETER ProjectPath
    Parent directory path where the project folder will be created (optional, will prompt if not provided)
    
    .PARAMETER Platform
    Target platform (Windows or Linux/WSL)
    
    .PARAMETER RequiresWSL
    Whether the project requires WSL environment
    
    .PARAMETER BaseDirectory
    Base directory for project path suggestions
    
    .PARAMETER check-only
    Only test the process without creating anything
    
    .PARAMETER what-if
    Shows what would be done without actually performing the actions
    
    .OUTPUTS
    Boolean indicating success
    #>
    param(
        [string]${project-name},
        [string]${loop-name},
        [string]${project-path},
        [string]$TargetPlatform,
        [switch]${requires-wsl},
        [string]${base-directory},
        [switch]${check-only},
        [switch]${what-if}
    )
    
    try {
        # Determine current execution environment
        $currentPlatform = Get-CurrentPlatform
        $isRunningInWSL = $currentPlatform -eq "WSL"
        
        Write-Step "Starting Project Initialization..."
        
        # Validate that we have a loop name (should come from Loop Selection phase or command line)
        if (-not ${loop-name}) {
            Write-Error "No loop template specified. This should have been selected during the Loop Selection phase."
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = $null
                GitContext = $Global:GitContext
                PhaseSkips = $Global:PhaseSkips
            }
        }
        
        # Get or validate project name
        $ProjectName = ${project-name}
        if (-not $ProjectName) {
            # Generate default name based on loop name
            $defaultName = "test-${loop-name}-app"
            $ProjectName = Read-UserPrompt -Prompt "Enter project name" -DefaultValue $defaultName
            if ([string]::IsNullOrWhiteSpace($ProjectName)) {
                $ProjectName = $defaultName
            }
        }
        
        # Validate project name
        if ($ProjectName -notmatch "^[a-zA-Z0-9-_]+$") {
            Write-Error "Invalid project name. Use only letters, numbers, hyphens, and underscores."
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = ${loop-name}
                GitContext = $Global:GitContext
                PhaseSkips = $Global:PhaseSkips
            }
        }
        
        Write-Info "Project Name: $ProjectName"
        Write-Info "Loop Template: ${loop-name}"
        
        # Determine platform using centralized configuration
        $targetPlatform = Get-PlatformForLoop -LoopName ${loop-name}
        $effectiveRequiresWSL = ${requires-wsl} -or ($targetPlatform -eq "WSL")
        
        # Show both execution and target platform for clarity
        $executionPlatform = if ($PSVersionTable.Platform -eq 'Unix' -or $env:WSL_DISTRO_NAME) { 'WSL/Linux' } else { 'Windows' }
        Write-Info "Execution Platform: $executionPlatform (running script)"
        Write-Info "Target Platform: $(if ($effectiveRequiresWSL) { 'WSL' } else { 'Windows' }) (creating project)"
        
        if (${check-only}) {
            Write-Success "Project initialization test completed successfully"
            Write-Info "Would initialize project '$ProjectName' using loop '${loop-name}'"
            
            # Use provided project path if available, otherwise create a test path
            $testProjectPath = if (${project-path}) { 
                ${project-path} 
            } else { 
                "/example/projects/$ProjectName" 
            }
            
            return @{
                Success = $true
                ProjectPath = $testProjectPath
                ProjectName = $ProjectName
                LoopName = ${loop-name}
                TestMode = $true
                GitContext = $Global:GitContext
                PhaseSkips = $Global:PhaseSkips
            }
        }
        
        # Step 1: Get project parent directory with intelligent defaults
        $ProjectParentPath = ${project-path}
        if (-not $ProjectParentPath) {
            $params = @{
                LoopName = ${loop-name}
                ProjectName = $ProjectName
                Platform = $TargetPlatform
                RequiresWSL = ${requires-wsl}
            }
            $ProjectParentPath = Get-ProjectPath @params
            if (-not $ProjectParentPath) {
                Write-Error "Failed to determine project parent directory"
                return @{
                    Success = $false
                    ProjectPath = $null
                    ProjectName = $null
                    LoopName = ${loop-name}
                    GitContext = $Global:GitContext
                    PhaseSkips = $Global:PhaseSkips
                }
            }
        }
        
        # Construct full project path by combining parent path with project name
        if ($ProjectParentPath.StartsWith("/") -or $ProjectParentPath.Contains("/home/")) {
            # WSL path - use forward slash
            $ProjectPath = "$ProjectParentPath/$ProjectName"
        } else {
            # Windows path - use Join-Path for proper path handling
            $ProjectPath = Join-Path $ProjectParentPath $ProjectName
        }
        
        # Step 2: Initialize git workflow (discovery and setup) - CRITICAL: Must succeed to continue
        $useWSLForGit = $effectiveRequiresWSL -or $TargetPlatform -eq "WSL" -or $ProjectPath -match '^/'
        $params = @{
            ProjectPath = $ProjectPath
            ProjectName = $ProjectName
            Platform = $TargetPlatform
            EffectiveRequiresWSL = $effectiveRequiresWSL
            UseWSLForGit = $useWSLForGit
        }
        if (${what-if}) { $params['what-if'] = ${what-if} }
        
        $gitWorkflowResult = Initialize-GitWorkflow @params
        if (-not $gitWorkflowResult) {
            Write-Error "Git workflow initialization failed. Cannot continue with project creation to prevent corruption."
            Write-Error "Please resolve git issues and try again."
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = ${loop-name}
                GitContext = $Global:GitContext
                PhaseSkips = $Global:PhaseSkips
                Error = "Git workflow initialization failed"
            }
        }
        
        # Step 3: Create project directory if it doesn't exist
        $isWSLPath = $ProjectPath.StartsWith('/') -or $ProjectPath.Contains('/home/')
        
        if ($isWSLPath) {
            # WSL path handling
            if ($isRunningInWSL) {
                # Already in WSL, test directory directly
                $dirExistsResult = Test-Path "$ProjectPath"
            } else {
                # Running from Windows, use wsl command with reliable validation
                $validateResult = & wsl -- bash -c "if [ -d '$ProjectPath' ]; then echo 'DIR_EXISTS'; else echo 'DIR_NOT_EXISTS'; fi" 2>&1
                $dirExistsResult = ($validateResult -contains "DIR_EXISTS")
            }
            
            if (-not $dirExistsResult) {
                if (${what-if}) {
                    Write-Host "what if: Would create WSL project directory: $ProjectPath" -ForegroundColor Yellow
                } else {
                    Write-Progress "Creating project directory in WSL..."
                    Write-Verbose "Debug: Attempting to create WSL directory: $ProjectPath"
                    
                    # Check if parent directory exists first
                    $parentPath = Split-Path $ProjectPath -Parent
                    Write-Verbose "Debug: Checking parent directory: $parentPath"
                    
                    if ($isRunningInWSL) {
                        $parentExists = Test-Path $parentPath
                    } else {
                        # Use reliable bash echo validation for parent directory
                        $parentValidateResult = & wsl -- bash -c "if [ -d '$parentPath' ]; then echo 'PARENT_EXISTS'; else echo 'PARENT_NOT_EXISTS'; fi" 2>&1
                        $parentExists = ($parentValidateResult -contains "PARENT_EXISTS")
                    }
                    
                    if (-not $parentExists) {
                        Write-Warning "Parent directory does not exist in WSL: $parentPath"
                        Write-Info "Debug: You can check manually with: wsl ls -la '$(Split-Path $parentPath -Parent)'"
                        Write-Info "Debug: Or create parent manually with: wsl mkdir -p '$parentPath'"
                    }
                    
                    if ($isRunningInWSL) {
                        # Already in WSL, run mkdir directly
                        $createResult = mkdir -p "$ProjectPath"
                    } else {
                        # Running from Windows, use wsl command
                        Write-Verbose "Debug: Running: wsl -- mkdir -p '$ProjectPath'"
                        $createResult = & wsl -- mkdir -p "$ProjectPath" 2>&1
                    }
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to create WSL project directory: $ProjectPath"
                        Write-Error "mkdir result: $($createResult -join ' ')"
                        Write-Error "Debug: Parent directory exists: $parentExists"
                        Write-Error "Debug: You can try manually: wsl mkdir -p '$ProjectPath'"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = ${loop-name}
                            GitContext = $Global:GitContext
                            PhaseSkips = $Global:PhaseSkips
                        }
                    }
                    
                    # Verify the directory was actually created
                    if ($isRunningInWSL) {
                        $dirExists = Test-Path $ProjectPath
                    } else {
                        # Use a more reliable validation method for WSL paths
                        $pathCheckResult = & wsl -- bash -c "test -d '$ProjectPath' && echo 'exists' || echo 'missing'" 2>&1
                        $dirExists = ($pathCheckResult -eq 'exists')
                    }
                    
                    if (-not $dirExists) {
                        Write-Error "WSL project directory was not created successfully: $ProjectPath"
                        Write-Error "Directory verification failed. Check WSL connectivity and permissions."
                        Write-Error "Debug: mkdir command completed with exit code: $LASTEXITCODE"
                        Write-Error "Debug: mkdir output: $($createResult -join ' ')"
                        Write-Error "Debug: Parent directory exists: $parentExists"
                        Write-Error "Debug: Manual verification: wsl ls -la '$ProjectPath'"
                        Write-Error "Debug: Check WSL status: wsl --status"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = ${loop-name}
                            GitContext = $Global:GitContext
                            PhaseSkips = $Global:PhaseSkips
                        }
                    }
                }
            }
        } else {
            # Windows path handling
            if (-not (Test-Path $ProjectPath)) {
                if (${what-if}) {
                    Write-Host "what if: Would create Windows project directory: $ProjectPath" -ForegroundColor Yellow
                } else {
                    Write-Progress "Creating project directory..."
                    try {
                        New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
                    } catch {
                        Write-Error "Failed to create project directory: $($_.Exception.Message)"
                        return @{
                            Success = $false
                            ProjectPath = $null
                            ProjectName = $null
                            LoopName = ${loop-name}
                            GitContext = $Global:GitContext
                            PhaseSkips = $Global:PhaseSkips
                        }
                    }
                }
            }
        }
        
        # Step 4: Initialize strangeloop project
        Write-Progress "Initializing strangeloop project..."
        
        # Use the proper project creation functions
        if ($isWSLPath) {
            $params = @{
                'project-name' = $ProjectName
                'loop-name' = ${loop-name}
                'project-path' = $ProjectPath
            }
            if (${what-if}) { $params['what-if'] = ${what-if} }
            
            $createResult = New-strangeloopProjectWSL @params
        } else {
            $params = @{
                'project-name' = $ProjectName
                'loop-name' = ${loop-name}
                'project-path' = $ProjectPath
            }
            if (${what-if}) { $params['what-if'] = ${what-if} }
            
            $createResult = New-strangeloopProject @params
        }
        
        # Handle case where createResult might be an array with mixed output
        if ($createResult -is [Object[]] -and $createResult.Count -gt 0) {
            # Find the hashtable in the array
            $hashtableResult = $createResult | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('Success') } | Select-Object -First 1
            if ($hashtableResult) {
                $createResult = $hashtableResult
            }
        }
        
        if (-not $createResult -or -not $createResult.Success) {
            Write-Error "strangeloop project creation failed"
            return @{
                Success = $false
                ProjectPath = $null
                ProjectName = $null
                LoopName = ${loop-name}
                GitContext = $Global:GitContext
                PhaseSkips = $Global:PhaseSkips
            }
        }
        
        # Check if this was an existing project that user chose not to overwrite
        if ($createResult.ExistingProject -and $createResult.SkipProjectCreation) {
            Write-Success "Using existing strangeloop project"
        } else {
            Write-Success "strangeloop project created successfully"
        }
        
        # Update git context with final project path
        $Global:GitContext.ProjectPath = $ProjectPath
        
        Write-Success "Project initialization completed successfully"
        Write-Info "Project location: $ProjectPath"
        
        # Display git workflow summary
        if ($Global:GitContext.SkipGit) {
            Write-Info "📋 Git and Pipeline phases will be skipped (user choice)"
        } elseif ($Global:GitContext.IsGitControlled) {
            Write-Info "📋 Git repository detected - will commit changes in Git phase"
            Write-Info "   Branch: $($Global:GitContext.LocalBranch)"
            if ($Global:GitContext.RemoteUrl) {
                Write-Info "   Remote: $($Global:GitContext.RemoteUrl)"
            }
        } elseif ($Global:GitContext.WillInitializeGit) {
            Write-Info "📋 Git repository will be initialized in Git phase"
            Write-Info "   Remote: $($Global:GitContext.RemoteUrl)"
        }
        
        return @{
            Success = $true
            ProjectPath = $ProjectPath
            ProjectName = $ProjectName
            LoopName = ${loop-name}
            GitContext = $Global:GitContext
            PhaseSkips = $Global:PhaseSkips
        }
        
    } catch {
        Write-Error "Project initialization failed: $($_.Exception.Message)"
        return @{
            Success = $false
            ProjectPath = $null
            ProjectName = $null
            LoopName = ${loop-name}
            GitContext = $Global:GitContext
            PhaseSkips = $Global:PhaseSkips
        }
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $params = @{
        'project-name' = ${project-name}
        'loop-name' = ${loop-name}
        'project-path' = ${project-path}
        Platform = $TargetPlatform
        'requires-wsl' = ${requires-wsl}
        'base-directory' = ${base-directory}
    }
    if (${check-only}) { $params['check-only'] = ${check-only} }
    if (${what-if}) { $params['what-if'] = ${what-if} }
    
    $result = Start-ProjectInitialization @params
    
    if ($result -and $result.Success) {
        Write-Success "Project initialization completed successfully"
    } else {
        Write-Error "Project initialization failed"
    }
    
    # Return the result for Invoke-Phase to capture
    return $result
}

# Export functions for module usage
if ($MyInvocation.MyCommand.ModuleName) {
    Export-ModuleMember -Function @(
        'Show-LoopSelection',
        'Get-ProjectDetails',
        'New-strangeloopProject',
        'New-strangeloopProjectWSL',
        'initialize-projectWorkspace',
        'Start-ProjectInitialization'
    )
}


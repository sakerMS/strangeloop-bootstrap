# strangeloop Setup - Completion Module
# Version: 1.0.0


param(
    [hashtable]${phase-results},
    [datetime]${start-time},
    [switch]${failed},
    [switch]${what-if}
)

# Import shared modules
$BootstrapRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
$LibPath = Join-Path $BootstrapRoot "lib"
. (Join-Path $LibPath "display\write-functions.ps1")
. (Join-Path $LibPath "validation\test-functions.ps1")
. (Join-Path $LibPath "platform\path-functions.ps1")
. (Join-Path $LibPath "version\version-functions.ps1")

function Complete-Setup {
    param(
        [hashtable]${phase-results},
        [datetime]${start-time},
        [switch]${failed},
        [switch]${what-if}
    )
    
    if (${what-if}) {
        Write-Host "what if: Would display setup completion summary" -ForegroundColor Yellow
        Write-Host "what if: Would calculate and show execution time" -ForegroundColor Yellow
        Write-Host "what if: Would show phase results in execution order" -ForegroundColor Yellow
        Write-Host "what if: Would display next steps and usage tips" -ForegroundColor Yellow
        Write-Host "what if: Would clean up temporary files" -ForegroundColor Yellow
        Write-Host "what if: Would display final success/failure message" -ForegroundColor Yellow
        return $true
    }
    
    if (${failed}) {
        Write-Step "Setup Cleanup & Error Summary" "Red"
    } else {
        Write-Step "Setup Completion & Summary" "Green"
    }
    
    try {
        # Calculate execution time
        $executionTime = (Get-Date) - ${start-time}
        $completedTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        
        # Get version from centralized configuration
        $scriptVersion = try { Get-BootstrapScriptVersion } catch { "1.0.0" }
        
        # Determine if setup was actually successful or failed
        $actuallyFailed = ${failed}
        if (-not $actuallyFailed -and ${phase-results}) {
            # Check if any phases actually failed (vs being skipped)
            foreach ($phaseResult in ${phase-results}.Values) {
                if ($phaseResult -is [hashtable]) {
                    # Only consider it a failure if Success is false AND it's not just skipped
                    if ($phaseResult.ContainsKey('Success') -and -not $phaseResult.Success -and 
                        -not ($phaseResult.ContainsKey('Skipped') -and $phaseResult.Skipped)) {
                        $actuallyFailed = $true
                        break
                    }
                } elseif ($phaseResult -is [bool] -and -not $phaseResult) {
                    # Direct boolean false indicates failure
                    $actuallyFailed = $true
                    break
                }
            }
        }
        
        # Display execution summary
        Write-Host ""
        if ($actuallyFailed) {
            Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║                    SETUP FAILURE SUMMARY                     ║" -ForegroundColor Red
            Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
            Write-Host "║ Script Version: $($scriptVersion.PadRight(42))   ║" -ForegroundColor Red
            Write-Host "║ Execution Time: $($executionTime.ToString('mm\:ss').PadRight(42))   ║" -ForegroundColor Red
            Write-Host "║ Completed:      $($completedTime.PadRight(42))   ║" -ForegroundColor Red
            Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red            
        } else {
            Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║                   SETUP SUCCESS SUMMARY                      ║" -ForegroundColor Green
            Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
            Write-Host "║ Script Version: $($scriptVersion.PadRight(42))   ║" -ForegroundColor Green
            Write-Host "║ Execution Time: $($executionTime.ToString('mm\:ss').PadRight(42))   ║" -ForegroundColor Green
            Write-Host "║ Completed:      $($completedTime.PadRight(42))   ║" -ForegroundColor Green
            Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green            
        }
            
            # Display phase results in correct execution order
            if (${phase-results} -and ${phase-results}.Count -gt 0) {
                Write-Host ""
                Write-Host "Phase Results:" -ForegroundColor Yellow
                Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
                
                # Define phases in correct execution order
                $orderedPhases = @(
                    'Prerequisites',
                    'Authentication', 
                    'Discovery',
                    'Environment',
                    'WSL',
                    'Project',
                    'Git',
                    'Pipelines',
                    'VSCode'
                )
                
                foreach ($phaseName in $orderedPhases) {
                    if (${phase-results}.ContainsKey($phaseName)) {
                        $phase = @{ Key = $phaseName; Value = ${phase-results}[$phaseName] }
                        
                        # Handle different return types from phases
                        $isSuccess = $false
                        $isSkipped = $false
                        $skipReason = $null
                        $phaseDuration = $null
                        
                        if ($null -eq $phase.Value) {
                            # Null or empty result
                            $isSuccess = $false
                        } elseif ($phase.Value -is [hashtable]) {
                            # Handle object with Success property and possible Skipped property
                            if ($phase.Value.ContainsKey('Skipped') -and $phase.Value.Skipped) {
                                $isSkipped = $true
                                $isSuccess = $phase.Value.Success -eq $true
                                $skipReason = $phase.Value.Reason
                            } elseif ($phase.Value.ContainsKey('Success')) {
                                $isSuccess = $phase.Value.Success
                            }
                            
                            # Extract timing information if available
                            if ($phase.Value.ContainsKey('Duration')) {
                                $phaseDuration = $phase.Value.Duration
                            }
                        } elseif ($phase.Value -is [bool]) {
                            # Handle direct boolean result
                            $isSuccess = $phase.Value
                        } elseif ($phase.Value -is [string] -and $phase.Value -eq "True") {
                            # Handle string "True" (PowerShell sometimes converts bool to string)
                            $isSuccess = $true
                        } elseif ($phase.Value -is [string] -and $phase.Value -eq "False") {
                            # Handle string "False"
                            $isSuccess = $false
                        } elseif ($phase.Value -match "Success|Complete|OK") {
                            # Handle success-indicating strings
                            $isSuccess = $true
                        } elseif ($phase.Value -match "Fail|Error|False") {
                            # Handle failure-indicating strings
                            $isSuccess = $false
                        } elseif ($phase.Value) {
                            # Handle other truthy values (objects, non-empty strings, numbers > 0, etc.)
                            $isSuccess = $true
                        }
                        
                        # Determine status display
                        if ($isSkipped) {
                            $status = if ($isSuccess) { "⏭️  Skipped" } else { "⏭️  Skipped (Failed)" }
                            $color = if ($isSuccess) { "Yellow" } else { "DarkRed" }
                            if ($skipReason) {
                                $status += " - $skipReason"
                            }
                            # Don't show timing for skipped phases
                        } else {
                            $status = if ($isSuccess) { "✓ Success" } else { "✗ Failed" }
                            $color = if ($isSuccess) { "Green" } else { "Red" }
                            
                            # Add timing information only for phases that actually ran
                            if ($phaseDuration) {
                                if ($phaseDuration.TotalSeconds -lt 1) {
                                    $timingStr = "(<1s)"
                                } elseif ($phaseDuration.TotalMinutes -lt 1) {
                                    $timingStr = "($([math]::Round($phaseDuration.TotalSeconds, 1))s)"
                                } else {
                                    $timingStr = "($([math]::Round($phaseDuration.TotalMinutes, 1))m)"
                                }
                                $status += " $timingStr"
                            }
                        }
                        
                        # Format with proper alignment (phase name padded to 15 characters)
                        $formattedPhaseName = $phase.Key.PadRight(15)
                        Write-Host "  ${formattedPhaseName}: " -NoNewline -ForegroundColor Cyan
                        Write-Host $status -ForegroundColor $color
                    }
                }
                Write-Host ""
            }
            
            if (-not $actuallyFailed) {
                # Check if project setup was skipped to customize next steps
                $projectSkipped = $false
                if (${phase-results} -and ${phase-results}.ContainsKey('Project')) {
                    $projectResult = ${phase-results}['Project']
                    if ($projectResult -is [hashtable] -and $projectResult.ContainsKey('Skipped') -and $projectResult.Skipped) {
                        $projectSkipped = $true
                    }
                }
                
                # Display context-appropriate usage tips
                Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
                if ($projectSkipped) {
                    Write-Host "   • Environment setup is complete and ready for use" -ForegroundColor Gray
                    Write-Host "   • You can run the setup again to create a project:" -ForegroundColor Gray
                    Write-Host "     - .\setup-strangeloop.ps1 -loop-name <loop-name> -project-name <name>" -ForegroundColor DarkGray
                    Write-Host "   • Or create a project manually using strangeloop CLI" -ForegroundColor Gray
                } else {
                    Write-Host "   • Your project should now be open in VS Code" -ForegroundColor Gray
                    Write-Host "   • Review the generated project structure" -ForegroundColor Gray
                    Write-Host "   • Git repository has been initialized with initial commit" -ForegroundColor Gray
                    Write-Host "   • If you configured a remote, you can now push changes:" -ForegroundColor Gray
                    Write-Host "     - git push" -ForegroundColor DarkGray
                    Write-Host "   • Install any additional dependencies as needed" -ForegroundColor Gray
                    Write-Host "   • Start developing with strangeloop!" -ForegroundColor Gray
                }
                
                Write-Host "`n🔧 Available Commands:" -ForegroundColor Cyan
                Write-Host "   • strangeloop --help                 - Show strangeloop CLI help" -ForegroundColor White
                Write-Host "   • strangeloop list                   - List available loops" -ForegroundColor White
                if (-not $projectSkipped) {
                    Write-Host "   • strangeloop recurse                - Apply configuration changes" -ForegroundColor White
                }
                
                Write-Host "`n📖 For more information:" -ForegroundColor Cyan
                Write-Host "   • Check the project README.md file" -ForegroundColor Gray
                Write-Host "   • Visit the strangeloop documentation" -ForegroundColor Gray
            } else {
                Write-Host "`n🛠️ Troubleshooting:" -ForegroundColor Yellow
                Write-Host "   • Check the error messages above" -ForegroundColor Gray
                Write-Host "   • Ensure all prerequisites are installed" -ForegroundColor Gray
                Write-Host "   • Try running with -Force parameter" -ForegroundColor Gray
                Write-Host "   • Check your internet connection" -ForegroundColor Gray
            }
        
        # Cleanup temporary files
        if (${what-if}) {
            Write-Host "what if: Would clean up temporary strangeloop files from temp directory" -ForegroundColor Yellow
        } else {
            Write-Progress "Cleaning up temporary files..."
            
            $tempPath = [System.IO.Path]::GetTempPath()
            $tempFiles = Get-ChildItem -Path $tempPath -Filter "strangeloop*" -ErrorAction SilentlyContinue
            
            foreach ($tempFile in $tempFiles) {
                try {
                    Remove-Item $tempFile.FullName -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    # Ignore cleanup errors
                }
            }
        }
        
        if (-not $actuallyFailed) {
            Write-Success "strangeloop setup completed successfully!"
        } else {
            Write-Error "strangeloop setup failed. Please review the errors above."
        }
        
        return $true
    
    } catch {
        Write-Error "Completion phase failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $params = @{
        'phase-results' = ${phase-results}
        'start-time' = ${start-time}
        failed = ${failed}
    }
    if (${what-if}) { $params['what-if'] = ${what-if} }
    
    $result = Complete-Setup @params
    
    # Return the result for Invoke-Phase to capture
    return $result
}

# Export functions for module usage
# Note: Functions are available when this file is dot-sourced

# Setup.ps1 - Runner setup and configuration functions

# Determine the runner base directory (where the downloaded runner binary is)
$RunnerInstallBase = "C:\actions-runner"

# Configure new GitHub Actions runners (interactive setup)
function Start-MassConfigureRunners {
    Write-ColorOutput "=== Mass Runner Configuration ===" -Color Blue
    Write-Host ""
    
    # Check if runner binary exists
    if (-not (Test-Path "$RunnerInstallBase\bin\Runner.Listener.exe")) {
        Write-ColorOutput "ERROR: Runner binary not found at $RunnerInstallBase\bin\Runner.Listener.exe" -Color Red
        Write-ColorOutput "Please download the GitHub Actions runner first." -Color Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    # Prompt for configuration details
    Write-ColorOutput "GitHub Actions Runner Configuration" -Color Cyan
    Write-Host ""
    
    $repoUrl = Read-Host "Enter repository URL (e.g., https://github.com/owner/repo)"
    if (-not $repoUrl) {
        Write-ColorOutput "Repository URL is required." -Color Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $token = Read-Host "Enter GitHub Personal Access Token"
    if (-not $token) {
        Write-ColorOutput "GitHub token is required." -Color Red
        Read-Host "Press Enter to continue"
        return
    }
    
    $numRunners = Read-Host "How many runners to configure? (1-10) [default: 1]"
    if (-not $numRunners) { $numRunners = 1 }
    $numRunners = [int]$numRunners
    
    if ($numRunners -lt 1 -or $numRunners -gt 10) {
        Write-ColorOutput "Invalid number. Please provide a number between 1 and 10." -Color Red
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-ColorOutput "Configuring $numRunners runner(s)..." -Color Yellow
    Write-Host ""
    
    $successCount = 0
    $failureCount = 0
    
    for ($i = 1; $i -le $numRunners; $i++) {
        $runnerName = "runner-$i"
        $runnerDir = "$RunnerInstallBase\$runnerName"
        
        Write-ColorOutput "[$i/$numRunners] Configuring runner: $runnerName" -Color Cyan
        
        try {
            # Create runner directory if it doesn't exist
            if (-not (Test-Path $runnerDir)) {
                New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
                Write-Host "  Created directory: $runnerDir"
            }
            
            # Copy runner files (bin, externals, _diag folders and scripts)
            Write-Host "  Copying runner files..."
            
            # Copy bin directory (contains Runner.Listener.exe and other binaries)
            if (Test-Path "$RunnerInstallBase\bin") {
                Copy-Item "$RunnerInstallBase\bin" "$runnerDir\" -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Copy externals directory
            if (Test-Path "$RunnerInstallBase\externals") {
                Copy-Item "$RunnerInstallBase\externals" "$runnerDir\" -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Copy _diag directory
            if (Test-Path "$RunnerInstallBase\_diag") {
                Copy-Item "$RunnerInstallBase\_diag" "$runnerDir\" -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            # Copy script files to runner directory
            Copy-Item "$RunnerInstallBase\config.cmd" "$runnerDir\" -Force -ErrorAction SilentlyContinue
            Copy-Item "$RunnerInstallBase\run.cmd" "$runnerDir\" -Force -ErrorAction SilentlyContinue
            Copy-Item "$RunnerInstallBase\run-helper.cmd.template" "$runnerDir\" -Force -ErrorAction SilentlyContinue
            Copy-Item "$RunnerInstallBase\run-helper.sh.template" "$runnerDir\" -Force -ErrorAction SilentlyContinue
            Copy-Item "$RunnerInstallBase\*.json" "$runnerDir\" -Force -ErrorAction SilentlyContinue
            
            # Run config.cmd (GitHub Actions runner configuration)
            Write-Host "  Running configuration script..."
            $configScript = "$runnerDir\config.cmd"
            
            if (Test-Path $configScript) {
                Set-Location $runnerDir
                & $configScript --url $repoUrl --token $token --name $runnerName --work _work --unattended 2>&1 | ForEach-Object {
                    Write-Host "    $_"
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "  ✓ $runnerName configured successfully" -Color Green
                    $successCount++
                } else {
                    Write-ColorOutput "  ✗ $runnerName configuration failed (exit code: $LASTEXITCODE)" -Color Red
                    $failureCount++
                }
            } else {
                Write-ColorOutput "  ✗ Configuration script not found at $configScript" -Color Red
                $failureCount++
            }
        }
        catch {
            Write-ColorOutput "  ✗ Error configuring $runnerName : $_" -Color Red
            $failureCount++
        }
        
        Write-Host ""
    }
    
    # Summary
    Write-ColorOutput "Configuration Summary:" -Color Blue
    Write-ColorOutput "  Successful: $successCount" -Color Green
    Write-ColorOutput "  Failed: $failureCount" -Color $(if ($failureCount -gt 0) { 'Red' } else { 'Green' })
    
    if ($successCount -gt 0) {
        Write-ColorOutput "Next: Use option 2 to start all runners" -Color Yellow
    }
    
    Read-Host "Press Enter to continue"
}

# Start all configured runners
function Start-AllRunners {
    Write-ColorOutput "=== Starting All Runners ===" -Color Blue
    Write-Host ""
    
    if (-not (Test-Path $RunnerInstallBase)) {
        Write-ColorOutput "No runner installation found at $RunnerInstallBase" -Color Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $runnerDirs = @(Get-ChildItem -Path $RunnerInstallBase -Directory -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -match '^runner-' })
    
    if ($runnerDirs.Count -eq 0) {
        Write-ColorOutput "No configured runners found." -Color Yellow
        Write-ColorOutput "Use option 1 to configure runners first." -Color Cyan
        Read-Host "Press Enter to continue"
        return
    }
    
    $startedCount = 0
    
    foreach ($dir in $runnerDirs) {
        $runName = $dir.Name
        $runScript = "$($dir.FullName)\run.cmd"
        
        Write-ColorOutput "Starting $runName..." -Color Cyan
        
        try {
            if (Test-Path $runScript) {
                # Run in background and capture PID
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $runScript `
                    -WorkingDirectory $dir.FullName -PassThru -NoNewWindow
                
                # Save PID for later monitoring
                $pidFile = "$($dir.FullName)\.runner.pid"
                $process.Id | Set-Content -Path $pidFile
                
                Write-ColorOutput "  ✓ $runName started (PID: $($process.Id))" -Color Green
                $startedCount++
            } else {
                Write-ColorOutput "  ✗ Run script not found: $runScript" -Color Red
            }
        }
        catch {
            Write-ColorOutput "  ✗ Failed to start $runName : $_" -Color Red
        }
    }
    
    Write-Host ""
    Write-ColorOutput "Started $startedCount runner(s)" -Color Green
    Read-Host "Press Enter to continue"
}

# Stop all running runners
function Stop-AllRunners {
    Write-ColorOutput "=== Stopping All Runners ===" -Color Blue
    Write-Host ""
    
    $confirm = Read-Host "This will stop all running runners. Continue? (y/N)"
    if ($confirm -notmatch '^[yY]$') {
        Write-ColorOutput "Cancelled." -Color Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    
    $stoppedCount = 0
    
    # Try to find and stop Runner.Listener processes
    $listeners = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
    
    foreach ($proc in $listeners) {
        try {
            Write-ColorOutput "Stopping process PID $($proc.Id)..." -Color Cyan
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-ColorOutput "  ✓ Stopped PID $($proc.Id)" -Color Green
            $stoppedCount++
        }
        catch {
            Write-ColorOutput "  ✗ Failed to stop PID $($proc.Id)" -Color Red
        }
    }
    
    if ($stoppedCount -eq 0) {
        Write-ColorOutput "No running runners found." -Color Yellow
    } else {
        Write-ColorOutput "Stopped $stoppedCount runner(s)" -Color Green
    }
    
    Read-Host "Press Enter to continue"
}

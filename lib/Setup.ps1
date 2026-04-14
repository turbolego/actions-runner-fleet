# Setup.ps1 - Runner setup and configuration functions

# Install and configure a single runner instance
function Install-SingleRunner {
    param(
        [Parameter(Mandatory = $true)] [string]$RunnerDir,
        [Parameter(Mandatory = $true)] [string]$RepoUrl,
        [Parameter(Mandatory = $true)] [string]$Token,
        [Parameter(Mandatory = $true)] [string]$RunnerName,
        [Parameter(Mandatory = $true)] [string]$ZipFile
    )

    Write-ColorOutput "Setting up runner: $RunnerName in $RunnerDir" -Color Blue

    if (-not (Test-Path $RunnerDir)) {
        New-Item -ItemType Directory -Path $RunnerDir -Force | Out-Null
    }

    # Extract archive if not already done
    if (-not (Test-Path "$RunnerDir\config.cmd")) {
        Write-ColorOutput "Extracting runner archive..." -Color Blue

        $zipPath = Join-Path $script:BaseDir $ZipFile
        if (-not (Test-Path $zipPath)) {
            Write-ColorOutput "Error: Archive not found at $zipPath" -Color Red
            return $false
        }

        try {
            Expand-Archive -Path $zipPath -DestinationPath $RunnerDir -Force -ErrorAction Stop
        }
        catch {
            Write-ColorOutput "Error: Failed to extract runner archive" -Color Red
            Write-ColorOutput $_.Exception.Message -Color Red
            return $false
        }

        if (-not (Test-Path "$RunnerDir\config.cmd")) {
            Write-ColorOutput "Error: Extraction completed but config.cmd not found" -Color Red
            return $false
        }

        Write-ColorOutput "Successfully extracted runner files" -Color Green
    }
    else {
        Write-ColorOutput "Runner already extracted, skipping extraction" -Color Yellow
    }

    # Configure the runner
    Write-ColorOutput "Configuring runner..." -Color Blue

    Push-Location $RunnerDir
    try {
        $configArgs = @(
            '--url',         $RepoUrl,
            '--token',       $Token,
            '--name',        $RunnerName,
            '--work',        '_work',
            '--labels',      'Playwright',
            '--runnergroup', 'Default',
            '--replace',
            '--unattended'
        )

        & ".\config.cmd" @configArgs
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($exitCode -eq 0) {
        Write-ColorOutput "Runner $RunnerName configured successfully" -Color Green
        return $true
    }
    else {
        Write-ColorOutput "Error: Failed to configure runner $RunnerName (exit code $exitCode)" -Color Red
        return $false
    }
}

# Mass-configure multiple runners for a repository
function Start-MassConfigureRunners {
    Write-ColorOutput "=== Mass Runner Configuration ===" -Color Blue

    $numRunnersStr = Read-Host "How many runners do you want to set up?"
    if ($numRunnersStr -notmatch '^\d+$' -or [int]$numRunnersStr -le 0) {
        Write-ColorOutput "Error: Please enter a valid positive number" -Color Red
        Read-Host "Press Enter to continue"
        return
    }
    $numRunners = [int]$numRunnersStr

    $repoUrl = Read-Host "Enter the GitHub repository URL"
    if (-not (Get-RepoInfo $repoUrl)) {
        Read-Host "Press Enter to continue"
        return
    }

    # Build runner name base; GitHub limits runner names to 64 characters
    $baseName       = "$($script:RepoOwner)_$($script:RepoName)"
    $maxBaseLength  = 60  # reserves room for "-NNNN" suffix

    if ($baseName.Length -gt $maxBaseLength) {
        $ownerLen  = $script:RepoOwner.Length
        $remaining = $maxBaseLength - $ownerLen - 1  # -1 for underscore
        if ($remaining -lt 1) { $remaining = 1 }
        $truncRepo = $script:RepoName.Substring(0, [Math]::Min($remaining, $script:RepoName.Length))
        $baseName  = "$($script:RepoOwner)_$truncRepo"
        Write-ColorOutput "Runner name base truncated to: $baseName" -Color Yellow
    }

    # Detect existing runner directories
    $existingRunners = @()
    for ($i = 1; $i -le $numRunners; $i++) {
        $runnerDir = Join-Path $script:BaseDir "$baseName-$i"
        if (Test-Path $runnerDir) { $existingRunners += "$baseName-$i" }
    }

    if ($existingRunners.Count -gt 0) {
        Write-ColorOutput "Found $($existingRunners.Count) existing runner director(ies):" -Color Yellow
        foreach ($r in $existingRunners) { Write-Host "  - $r" }
        $removeExisting = Read-Host "Remove existing runners before setup? (y/N)"
        if ($removeExisting -match '^[yY]$') {
            foreach ($r in $existingRunners) {
                $rDir = Join-Path $script:BaseDir $r
                Write-ColorOutput "Removing $r..." -Color Yellow
                Remove-Item $rDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host ""
    Write-ColorOutput "WARNING: The token will be visible on screen. Ensure no one is watching." -Color Yellow
    $token = Read-Host "Enter the GitHub runner token"

    if ([string]::IsNullOrEmpty($token)) {
        Write-ColorOutput "Error: Token cannot be empty" -Color Red
        Read-Host "Press Enter to continue"
        return
    }

    # Download runner archive
    Write-ColorOutput "Downloading GitHub Actions runner..." -Color Blue
    $zipFile = Get-Runner $script:BaseDir

    if (-not $zipFile) {
        Write-ColorOutput "Error: Failed to download runner" -Color Red
        Read-Host "Press Enter to continue"
        return
    }

    Write-ColorOutput "Successfully downloaded: $zipFile" -Color Green
    Write-ColorOutput "Setting up $numRunners runner(s) for $($script:RepoOwner)/$($script:RepoName)..." -Color Blue
    Write-ColorOutput "Using runner name base: $baseName" -Color Blue

    for ($i = 1; $i -le $numRunners; $i++) {
        $runnerName = "$baseName-$i"
        $runnerDir  = Join-Path $script:BaseDir $runnerName
        Write-Host ""
        Write-ColorOutput "--- Runner $i of $numRunners: $runnerName ---" -Color Blue
        $ok = Install-SingleRunner -RunnerDir $runnerDir -RepoUrl $repoUrl -Token $token `
                                   -RunnerName $runnerName -ZipFile $zipFile
        if ($ok) {
            Write-ColorOutput "Runner $runnerName ready" -Color Green
        }
        else {
            Write-ColorOutput "Runner $runnerName failed — continuing with remaining runners" -Color Red
        }
        Write-Host "---"
    }

    Write-ColorOutput "Mass configuration complete!" -Color Green
    Read-Host "Press Enter to continue"
}

# Start all configured runners as background processes
function Start-AllRunners {
    Write-ColorOutput "=== Starting All Runners ===" -Color Blue

    $count   = 0
    $runCmds = Get-ChildItem -Path $script:BaseDir -Recurse -Depth 2 -Filter 'run.cmd' -ErrorAction SilentlyContinue

    if (-not $runCmds) {
        Write-ColorOutput "No run.cmd files found under $($script:BaseDir)" -Color Yellow
        Read-Host "Press Enter to continue"
        return
    }

    foreach ($runCmd in $runCmds) {
        $runnerDir  = $runCmd.DirectoryName
        $logFile    = Join-Path $runnerDir 'run.log'
        $runnerName = Split-Path $runnerDir -Leaf
        $pidFile    = Join-Path $runnerDir '.runner.pid'

        # Skip if already running (PID file check)
        if (Test-Path $pidFile) {
            $storedPid = (Get-Content $pidFile -ErrorAction SilentlyContinue).Trim()
            if ($storedPid -and (Get-Process -Id $storedPid -ErrorAction SilentlyContinue)) {
                Write-ColorOutput "Runner $runnerName is already running (PID: $storedPid)" -Color Yellow
                continue
            }
        }

        Write-ColorOutput "Starting $runnerName..." -Color Green

        Start-Process `
            -FilePath 'cmd.exe' `
            -ArgumentList '/c', 'run.cmd' `
            -WorkingDirectory $runnerDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $logFile `
            -ErrorAction SilentlyContinue

        # Brief pause to let Runner.Listener.exe spawn
        Start-Sleep -Milliseconds 2000

        # Attempt to identify the new Runner.Listener process for this directory
        $runnerPid = $null
        $listeners = Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue
        foreach ($proc in $listeners) {
            try {
                if ($proc.MainModule.FileName -like "$runnerDir*") {
                    $runnerPid = $proc.Id
                    break
                }
            }
            catch { }
        }

        if ($runnerPid) {
            $runnerPid | Set-Content $pidFile
            Write-ColorOutput "Started $runnerName (PID: $runnerPid)" -Color Green
        }
        else {
            Write-ColorOutput "Started $runnerName (PID tracking unavailable)" -Color Green
        }

        $count++
    }

    Write-ColorOutput "Started $count new runner(s) in the background" -Color Green
    Write-Host ""

    Start-Sleep -Seconds 1
    $totalActive = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue).Count
    Write-ColorOutput "Total active Runner.Listener processes: $totalActive" -Color Blue

    Read-Host "Press Enter to continue"
}

# Terminate all running runner processes
function Stop-AllRunners {
    Write-ColorOutput "=== Terminate Runners ===" -Color Blue
    Write-Host ""

    Show-RunnerStatus
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to kill all Runner.Listener processes? (y/N)"

    if ($confirm -match '^[yY]$') {
        $listeners = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)
        $workers   = @(Get-Process -Name 'Runner.Worker'   -ErrorAction SilentlyContinue)

        if ($listeners.Count -gt 0) {
            $listeners | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "Terminated $($listeners.Count) Runner.Listener process(es)" -Color Green
        }
        else {
            Write-ColorOutput "No Runner.Listener processes found" -Color Yellow
        }

        if ($workers.Count -gt 0) {
            $workers | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "Terminated $($workers.Count) Runner.Worker process(es)" -Color Green
        }

        # Remove stale PID files
        Get-ChildItem -Path $script:BaseDir -Recurse -Filter '.runner.pid' -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-ColorOutput "Operation cancelled." -Color Yellow
    }

    Read-Host "Press Enter to continue"
}

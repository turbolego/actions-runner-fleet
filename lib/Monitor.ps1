# Monitor.ps1 - Runner monitoring and status functions

# Helper: determine whether a specific runner directory has an active process
function Test-RunnerRunning {
    param([string]$RunnerDir)

    # First try the PID file written by Start-AllRunners
    $pidFile = Join-Path $RunnerDir '.runner.pid'
    if (Test-Path $pidFile) {
        $storedPid = (Get-Content $pidFile -ErrorAction SilentlyContinue).Trim()
        if ($storedPid -match '^\d+$') {
            return ($null -ne (Get-Process -Id $storedPid -ErrorAction SilentlyContinue))
        }
    }

    # Fallback: check if any Runner.Listener exe lives inside this directory
    $listeners = Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue
    foreach ($proc in $listeners) {
        try {
            if ($proc.MainModule.FileName -like "$RunnerDir*") { return $true }
        }
        catch { }
    }
    return $false
}

# Display a formatted status table of all configured runners
function Show-RunnerStatus {
    Write-ColorOutput "=== Runner Status ===" -Color Blue

    # Determine basedir (use global if script is not available)
    $baseDir = if ($script:BaseDir) { $script:BaseDir } else { $global:RunnerBaseDir }
    
    if (-not $baseDir -or -not (Test-Path $baseDir)) {
        Write-ColorOutput "Base directory not found or not configured" -Color Yellow
        return
    }

    $runnerDirs = @(Get-ChildItem -Path $baseDir -Directory -ErrorAction SilentlyContinue)
    if ($runnerDirs.Count -eq 0) {
        Write-ColorOutput "No runner directories found in $baseDir" -Color Yellow
        return
    }

    $totalConfigured = 0
    $totalRunning    = 0

    $nameWidth   = 35
    $statusWidth = 12
    $typeWidth   = 15
    $repoWidth   = 40

    # Adjust for wider consoles
    try {
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        if ($consoleWidth -gt 120) { $nameWidth = 45; $repoWidth = 50 }
    }
    catch { }

    $header = '{0,-' + $nameWidth + '} {1,-' + $statusWidth + '} {2,-' + $typeWidth + '} {3,-' + $repoWidth + '}'
    Write-Host ($header -f 'Runner Name', 'Status', 'Type', 'Repository')
    Write-Host ($header -f ('-' * $nameWidth), ('-' * $statusWidth), ('-' * $typeWidth), ('-' * $repoWidth))

    foreach ($dir in $runnerDirs) {
        $configFile = "$($dir.FullName)\.runner"
        if (-not (Test-Path $configFile)) { continue }

        $totalConfigured++
        $isRunning = Test-RunnerRunning $dir.FullName

        if ($isRunning) {
            $totalRunning++
            $status      = 'Running'
            $statusColor = [ConsoleColor]::Green
        }
        else {
            $status      = 'Idle'
            $statusColor = [ConsoleColor]::Yellow
        }

        $repo = Get-RepoForDir $dir.FullName
        $runnerType = if ($repo -match '^https://github\.com/[^/]+$') { 'org' } else { 'repo' }

        # Truncate long repo URLs for display
        $displayRepo = if ($repo.Length -gt $repoWidth) {
            '...' + $repo.Substring($repo.Length - $repoWidth + 3)
        }
        else { $repo }

        $namePart = ('{0,-' + $nameWidth + '} ') -f $dir.Name
        Write-Host $namePart -NoNewline
        Write-Host (('{0,-' + $statusWidth + '} ') -f $status) -ForegroundColor $statusColor -NoNewline
        Write-Host (('{0,-' + $typeWidth + '} {1,-' + $repoWidth + '}') -f $runnerType, $displayRepo)
    }

    Write-Host ''
    Write-ColorOutput 'Summary:' -Color Blue
    Write-ColorOutput "  Configured runners : $totalConfigured" -Color Green
    Write-ColorOutput "  Running runners    : $totalRunning"    -Color Green
    Write-ColorOutput "  Idle runners       : $($totalConfigured - $totalRunning)" -Color Yellow
}

# Real-time monitoring loop; exits when user presses any key
function Watch-Runners {
    Write-ColorOutput '=== Real-time Runner Monitor ===' -Color Blue
    Write-ColorOutput "Press any key to return to the main menu" -Color Yellow
    Write-Host ''

    while ($true) {
        Clear-Host
        Write-ColorOutput '=== GitHub Actions Runner Fleet Monitor ===' -Color Blue
        Write-ColorOutput (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Color Yellow
        Write-Host ''

        Show-RunnerStatus

        Write-Host ''
        Write-ColorOutput '=== Process Information ===' -Color Blue
        $listenerCount = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue).Count
        $workerCount   = @(Get-Process -Name 'Runner.Worker'   -ErrorAction SilentlyContinue).Count
        Write-ColorOutput "Active Runner.Listener processes : $listenerCount" -Color Green
        Write-ColorOutput "Active Runner.Worker processes   : $workerCount"   -Color Green

        Write-Host ''
        Write-ColorOutput 'Refreshing in 30 seconds... (Press any key to return to menu)' -Color Blue

        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            if ([Console]::KeyAvailable) {
                [Console]::ReadKey($true) | Out-Null
                return
            }
        }
    }
}

# Browse and display runner log files
function Show-RunnerLogs {
    Write-ColorOutput '=== View Runner Logs ===' -Color Blue

    $runnersWithLogs = @(
        Get-ChildItem -Path $script:BaseDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\run.log" } |
        Select-Object -ExpandProperty Name
    )

    if ($runnersWithLogs.Count -eq 0) {
        Write-ColorOutput 'No runners with log files found.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput 'Available runners with logs:' -Color Green
    for ($i = 0; $i -lt $runnersWithLogs.Count; $i++) {
        Write-Host "$($i + 1). $($runnersWithLogs[$i])"
    }
    Write-Host "$($runnersWithLogs.Count + 1). View all logs (combined, last 50 lines each)"
    Write-Host ''

    $choice = Read-Host "Select a runner (1-$($runnersWithLogs.Count + 1)) or press Enter to cancel"
    if ([string]::IsNullOrEmpty($choice)) { return }

    if (-not ($choice -match '^\d+$')) {
        Write-ColorOutput 'Invalid selection.' -Color Red
        Read-Host 'Press Enter to continue'
        return
    }

    $choiceNum = [int]$choice

    if ($choiceNum -eq ($runnersWithLogs.Count + 1)) {
        Write-ColorOutput '=== Combined logs from all runners ===' -Color Blue
        foreach ($runnerName in $runnersWithLogs) {
            $logFile = Join-Path $script:BaseDir "$runnerName\run.log"
            Write-ColorOutput "--- $runnerName ---" -Color Yellow
            Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue | Write-Host
        }
    }
    elseif ($choiceNum -ge 1 -and $choiceNum -le $runnersWithLogs.Count) {
        $runnerName = $runnersWithLogs[$choiceNum - 1]
        $logFile    = Join-Path $script:BaseDir "$runnerName\run.log"
        Write-ColorOutput "=== Logs for $runnerName (last 100 lines) ===" -Color Blue
        Get-Content $logFile -Tail 100 -ErrorAction SilentlyContinue | Write-Host
    }
    else {
        Write-ColorOutput 'Invalid selection.' -Color Red
    }

    Read-Host 'Press Enter to continue'
}

# Display system resource and runner health information
function Show-SystemHealth {
    Write-ColorOutput '=== System Health Check ===' -Color Blue
    Write-Host ''

    # Disk space
    Write-ColorOutput 'Disk Space:' -Color Yellow
    $drive = Split-Path $script:BaseDir -Qualifier
    $disk  = Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($disk) {
        $usedGB = [Math]::Round($disk.Used / 1GB, 2)
        $freeGB = [Math]::Round($disk.Free / 1GB, 2)
        Write-Host "  Drive $drive  Used: ${usedGB} GB  Free: ${freeGB} GB"
    }
    Write-Host ''

    # Memory
    Write-ColorOutput 'Memory Usage:' -Color Yellow
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $totalGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB2 = [Math]::Round($os.FreePhysicalMemory      / 1MB, 2)
        $usedGB2 = [Math]::Round($totalGB - $freeGB2, 2)
        Write-Host "  Total: ${totalGB} GB  Used: ${usedGB2} GB  Free: ${freeGB2} GB"
    }
    Write-Host ''

    # CPU
    Write-ColorOutput 'CPU Usage:' -Color Yellow
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
    if ($cpu) { Write-Host "  Load: $($cpu.LoadPercentage)%" }
    Write-Host ''

    # Runner processes
    Write-ColorOutput 'GitHub Actions Related Processes:' -Color Yellow
    $listeners = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)
    $workers   = @(Get-Process -Name 'Runner.Worker'   -ErrorAction SilentlyContinue)
    if ($listeners.Count -gt 0) { Write-Host "  Runner.Listener : $($listeners.Count) process(es)" }
    else { Write-Host '  No Runner.Listener processes found' }
    if ($workers.Count -gt 0)   { Write-Host "  Runner.Worker   : $($workers.Count) process(es)" }
    Write-Host ''

    # Runner directory sizes
    Write-ColorOutput 'Runner Directory Sizes:' -Color Yellow
    Get-ChildItem -Path $script:BaseDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $sizeMB = [Math]::Round(
            (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-Host "  $($_.Name) : ${sizeMB} MB"
    }
    Write-Host ''

    # Large log files (>10 MB)
    Write-ColorOutput 'Large Log Files (>10 MB):' -Color Yellow
    $largeLogs = @(Get-ChildItem -Path $script:BaseDir -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Length -gt 10MB })
    if ($largeLogs.Count -eq 0) {
        Write-ColorOutput '  No large log files found' -Color Green
    }
    else {
        foreach ($log in $largeLogs) {
            $sizeMB = [Math]::Round($log.Length / 1MB, 2)
            Write-Host "  $($log.FullName) (${sizeMB} MB)"
        }
    }

    Read-Host 'Press Enter to continue'
}

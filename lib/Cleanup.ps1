# Cleanup.ps1 - Runner cleanup and maintenance functions

# Interactively remove selected runner directories
function Remove-SpecificRunners {
    Write-ColorOutput '=== Remove Specific Runners ===' -Color Blue

    $runners = @(Get-ChildItem -Path $script:BaseDir -Directory -ErrorAction SilentlyContinue |
                 Select-Object -ExpandProperty Name)

    if ($runners.Count -eq 0) {
        Write-ColorOutput 'No runners found to remove.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput 'Available runners:' -Color Green
    for ($i = 0; $i -lt $runners.Count; $i++) {
        Write-Host "$($i + 1). $($runners[$i])"
    }
    Write-Host ''

    $selection = Read-Host "Enter runner numbers to remove (comma-separated, e.g. 1,3) or 'all'"

    if ([string]::IsNullOrEmpty($selection)) {
        Write-ColorOutput 'No selection made. Operation cancelled.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    $runnersToRemove = @()

    if ($selection -eq 'all') {
        $runnersToRemove = $runners
        Write-ColorOutput 'Selected ALL runners for removal.' -Color Yellow
    }
    else {
        foreach ($num in ($selection -split ',' | ForEach-Object { $_.Trim() })) {
            if ($num -match '^\d+$') {
                $idx = [int]$num - 1
                if ($idx -ge 0 -and $idx -lt $runners.Count) {
                    $runnersToRemove += $runners[$idx]
                }
                else {
                    Write-ColorOutput "Invalid runner number: $num" -Color Red
                }
            }
        }
    }

    if ($runnersToRemove.Count -eq 0) {
        Write-ColorOutput 'No valid runners selected.' -Color Red
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput 'Runners to be removed:' -Color Yellow
    foreach ($r in $runnersToRemove) { Write-Host "  - $r" }
    Write-Host ''

    Write-ColorOutput 'WARNING: This will permanently delete the selected runner directories!' -Color Red
    $confirm = Read-Host 'Are you sure you want to continue? (y/N)'

    if ($confirm -notmatch '^[yY]$') {
        Write-ColorOutput 'Operation cancelled.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    foreach ($runnerName in $runnersToRemove) {
        $runnerDir = Join-Path $script:BaseDir $runnerName

        # Attempt graceful unconfiguration
        if (Test-Path "$runnerDir\config.cmd") {
            Write-ColorOutput "Unconfiguring $runnerName from GitHub..." -Color Blue
            Push-Location $runnerDir
            try {
                & ".\config.cmd" remove --unattended 2>$null
            }
            catch { }
            Pop-Location
        }

        Write-ColorOutput "Removing $runnerName..." -Color Yellow
        Remove-Item $runnerDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "Removed: $runnerName" -Color Green
    }

    Write-ColorOutput 'Runner removal completed!' -Color Green
    Read-Host 'Press Enter to continue'
}

# Find and optionally kill orphaned runner processes
function Remove-OrphanedProcesses {
    Write-ColorOutput '=== Cleanup Orphaned Processes ===' -Color Blue
    Write-ColorOutput 'Searching for GitHub Actions related processes...' -Color Blue
    Write-Host ''

    $listeners = @(Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue)
    $workers   = @(Get-Process -Name 'Runner.Worker'   -ErrorAction SilentlyContinue)
    $nodeProcs = @(Get-Process -Name 'node'            -ErrorAction SilentlyContinue |
                   Where-Object {
                       try { $_.MainModule.FileName -like '*actions*' } catch { $false }
                   })

    if ($listeners.Count -gt 0) {
        Write-ColorOutput "Found $($listeners.Count) Runner.Listener process(es)" -Color Yellow
        $listeners | ForEach-Object { Write-Host "  PID $($_.Id)  Started: $($_.StartTime)" }
    }
    else { Write-ColorOutput 'No Runner.Listener processes found' -Color Green }

    if ($workers.Count -gt 0) {
        Write-ColorOutput "Found $($workers.Count) Runner.Worker process(es)" -Color Yellow
        $workers | ForEach-Object { Write-Host "  PID $($_.Id)  Started: $($_.StartTime)" }
    }
    else { Write-ColorOutput 'No Runner.Worker processes found' -Color Green }

    if ($nodeProcs.Count -gt 0) {
        Write-ColorOutput "Found $($nodeProcs.Count) actions-related Node.js process(es)" -Color Yellow
    }
    else { Write-ColorOutput 'No actions-related Node.js processes found' -Color Green }

    $allProcs = @($listeners) + @($workers) + @($nodeProcs)

    if ($allProcs.Count -eq 0) {
        Write-ColorOutput 'No orphaned processes found!' -Color Green
        Read-Host 'Press Enter to continue'
        return
    }

    Write-Host ''
    $confirm = Read-Host "Kill all $($allProcs.Count) found runner process(es)? (y/N)"

    if ($confirm -match '^[yY]$') {
        $killed = 0
        foreach ($proc in $allProcs) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                $killed++
            }
            catch {
                Write-ColorOutput "Could not stop PID $($proc.Id): $($_.Exception.Message)" -Color Red
            }
        }
        Write-ColorOutput "Killed $killed process(es)" -Color Green
    }
    else {
        Write-ColorOutput 'Operation cancelled.' -Color Yellow
    }

    Read-Host 'Press Enter to continue'
}

# Clean up runner log files
function Remove-RunnerLogFiles {
    Write-ColorOutput '=== Cleanup Log Files ===' -Color Blue

    $logFiles = @(Get-ChildItem -Path $script:BaseDir -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue)

    if ($logFiles.Count -eq 0) {
        Write-ColorOutput 'No log files found.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput "Found $($logFiles.Count) log file(s):" -Color Blue
    Write-Host ''

    $totalSize = 0
    $largeFiles = @()

    foreach ($log in $logFiles) {
        $sizeMB     = [Math]::Round($log.Length / 1MB, 2)
        $totalSize += $log.Length
        Write-Host "  $($log.FullName) (${sizeMB} MB)"
        if ($log.Length -gt 10MB) { $largeFiles += $log }
    }

    $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
    Write-Host ''
    Write-ColorOutput "Total log size: ${totalSizeMB} MB" -Color Blue

    if ($largeFiles.Count -gt 0) {
        Write-ColorOutput "Found $($largeFiles.Count) large log file(s) (>10 MB)" -Color Yellow
    }

    Write-Host ''
    Write-ColorOutput 'Cleanup options:' -Color Blue
    Write-Host '1. Delete all log files'
    Write-Host '2. Delete only large log files (>10 MB)'
    Write-Host '3. Truncate all log files (keep last 100 lines each)'
    Write-Host '4. View log file details'
    Write-Host '5. Cancel'
    Write-Host ''

    $choice = Read-Host 'Select cleanup option (1-5)'

    switch ($choice) {
        '1' {
            foreach ($log in $logFiles) {
                Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            }
            Write-ColorOutput "Deleted $($logFiles.Count) log file(s)" -Color Green
        }
        '2' {
            if ($largeFiles.Count -eq 0) {
                Write-ColorOutput 'No large log files found.' -Color Yellow
            }
            else {
                foreach ($log in $largeFiles) {
                    Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
                }
                Write-ColorOutput "Deleted $($largeFiles.Count) large log file(s)" -Color Green
            }
        }
        '3' {
            foreach ($log in $logFiles) {
                $lines = Get-Content $log.FullName -Tail 100 -ErrorAction SilentlyContinue
                if ($lines) { Set-Content $log.FullName -Value $lines }
            }
            Write-ColorOutput "Truncated $($logFiles.Count) log file(s) to last 100 lines" -Color Green
        }
        '4' {
            Write-Host ''
            foreach ($log in $logFiles) {
                $sizeMB = [Math]::Round($log.Length / 1MB, 2)
                Write-Host ("  {0,-70} {1,8} MB  Modified: {2}" -f $log.FullName, $sizeMB, $log.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
            }
        }
        '5' { Write-ColorOutput 'Cancelled.' -Color Yellow }
        default { Write-ColorOutput 'Invalid choice.' -Color Red }
    }

    Read-Host 'Press Enter to continue'
}

# Remove temporary files and work directories
function Remove-TempFiles {
    Write-ColorOutput '=== Cleanup Temporary Files ===' -Color Blue

    $tempItems = @()

    # Common temporary file patterns
    foreach ($pattern in @('*.tmp', '*.temp', 'Thumbs.db')) {
        $tempItems += @(Get-ChildItem -Path $script:BaseDir -Recurse -Filter $pattern -ErrorAction SilentlyContinue)
    }

    # _work directories created by runners
    $tempItems += @(Get-ChildItem -Path $script:BaseDir -Directory -Recurse -Filter '_work' -ErrorAction SilentlyContinue)

    if ($tempItems.Count -eq 0) {
        Write-ColorOutput 'No temporary files or work directories found.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput "Found $($tempItems.Count) temporary item(s):" -Color Blue
    Write-Host ''

    $totalSize = 0
    foreach ($item in $tempItems) {
        if ($item.PSIsContainer) {
            $size = (Get-ChildItem $item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum
        }
        else {
            $size = $item.Length
        }
        $totalSize += $size
        $sizeMB = [Math]::Round($size / 1MB, 2)
        Write-Host "  $($item.FullName) (${sizeMB} MB)"
    }

    $totalSizeMB = [Math]::Round($totalSize / 1MB, 2)
    Write-Host ''
    Write-ColorOutput "Total size: ${totalSizeMB} MB" -Color Blue
    Write-Host ''

    Write-ColorOutput 'WARNING: This will permanently delete all listed items!' -Color Red
    $confirm = Read-Host 'Do you want to proceed? (y/N)'

    if ($confirm -match '^[yY]$') {
        foreach ($item in $tempItems) {
            Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-ColorOutput 'All temporary files and directories deleted' -Color Green
    }
    else {
        Write-ColorOutput 'Operation cancelled.' -Color Yellow
    }

    Read-Host 'Press Enter to continue'
}

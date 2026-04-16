#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive GitHub Actions Runner Management System (Windows)

.DESCRIPTION
    Manages self-hosted GitHub Actions runners on Windows with an interactive menu interface.
    Place this script in C:\actions-runner\ as recommended by GitHub to avoid path/permission issues.

.EXAMPLE
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    .\runner-manager.ps1
#>

Set-StrictMode -Version Latest

# Base directory is the folder containing this script (use global for sourced libraries)
$script:BaseDir = $PSScriptRoot
$global:RunnerBaseDir = $PSScriptRoot

# ── Library loading ──────────────────────────────────────────────────────────

function Test-LibraryFiles {
    $libFiles = @('Colors.ps1', 'GitHub.ps1', 'Download.ps1', 'Setup.ps1',
                  'Monitor.ps1', 'Dependencies.ps1', 'Cleanup.ps1')
    $missing  = $libFiles | Where-Object { -not (Test-Path "$script:BaseDir\lib\$_") }

    if ($missing) {
        Write-Host 'Error: Missing library files:' -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  lib\$_" -ForegroundColor Red }
        Write-Host 'Ensure all lib\ files are present next to runner-manager.ps1.' -ForegroundColor Yellow
        exit 1
    }
}

# ── Define fallback color function (in case Colors.ps1 doesn't load) ────────

function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $Color
}

# ── TEST AND LOAD ALL LIBRARIES AT SCRIPT SCOPE ─────────────────────────────

Test-LibraryFiles

try {
    . "$script:BaseDir\lib\Colors.ps1"
    . "$script:BaseDir\lib\GitHub.ps1"
    . "$script:BaseDir\lib\Download.ps1"
    . "$script:BaseDir\lib\Setup.ps1"
    . "$script:BaseDir\lib\Monitor.ps1"
    . "$script:BaseDir\lib\Dependencies.ps1"
    . "$script:BaseDir\lib\Cleanup.ps1"
} catch {
    Write-Host "Error importing libraries: $_" -ForegroundColor Red
    exit 1
}

# ── Startup check ────────────────────────────────────────────────────────────

if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
    Write-ColorOutput 'Warning: curl not found. Invoke-WebRequest will be used for downloads.' -Color Yellow
}

# ── Menu display function ────────────────────────────────────────────────────

function Show-Menu {
    Clear-Host
    Write-ColorOutput '==========================================' -Color Blue
    Write-ColorOutput '   GitHub Actions Runner Manager'          -Color Blue
    Write-ColorOutput '       Windows Fleet Management'           -Color Blue
    Write-ColorOutput '==========================================' -Color Blue
    Write-Host ''
    Write-ColorOutput 'RUNNER MANAGEMENT'                        -Color Green
    Write-ColorOutput ' 1. Mass Configure New Runners'           -Color Green
    Write-ColorOutput ' 2. Start All Existing Runners'           -Color Green
    Write-ColorOutput ' 3. Terminate All Runners'                -Color Green
    Write-Host ''
    Write-ColorOutput 'MONITORING & STATUS'                      -Color Cyan
    Write-ColorOutput ' 4. Show Runner Status (one-time)'        -Color Cyan
    Write-ColorOutput ' 5. Monitor Runners (real-time)'          -Color Cyan
    Write-ColorOutput ' 6. View Runner Logs'                     -Color Cyan
    Write-ColorOutput ' 7. Check System Health'                  -Color Cyan
    Write-Host ''
    Write-ColorOutput 'SYSTEM MANAGEMENT'                        -Color Yellow
    Write-ColorOutput ' 8. Check Dependencies'                   -Color Yellow
    Write-ColorOutput ' 9. Install Missing Dependencies'         -Color Yellow
    Write-ColorOutput '10. Setup Python Environment'             -Color Yellow
    Write-ColorOutput '11. Repair Git Bash PATH (fix shell: bash)' -Color Yellow
    Write-Host ''
    Write-ColorOutput 'CLEANUP & MAINTENANCE'                    -Color Red
    Write-ColorOutput '12. Remove Specific Runners'              -Color Red
    Write-ColorOutput '13. Cleanup Orphaned Processes'           -Color Red
    Write-ColorOutput '14. Cleanup Log Files'                    -Color Red
    Write-ColorOutput '15. Cleanup Temporary Files'              -Color Red
    Write-Host ''
    Write-ColorOutput '16. Exit'                                  -Color Green
    Write-Host ''
}

# ── MAIN INTERACTIVE LOOP ────────────────────────────────────────────────────

Write-ColorOutput 'GitHub Actions Runner Manager loaded successfully!' -Color Green
Write-ColorOutput "Base directory: $script:BaseDir"                   -Color Blue
Write-Host ''

while ($true) {
    Show-Menu
    $rawChoice = Read-Host 'Enter your choice (1-16)'
    $choice = if ($rawChoice) { $rawChoice.Trim() } else { '' }
    
    switch ($choice) {
        '1'     { Start-MassConfigureRunners }
        '2'     { Start-AllRunners }
        '3'     { Stop-AllRunners }
        '4'     { Show-RunnerStatus; Read-Host 'Press Enter to continue' }
        '5'     { Watch-Runners }
        '6'     { Show-RunnerLogs }
        '7'     { Show-SystemHealth }
        '8'     { Test-AllDependencies }
        '9'     { Install-RequiredDependencies }
        '10'    { New-RunnerPythonEnvironment }
        '11'    { Repair-RunnerGitBashPath }
        '12'    { Remove-SpecificRunners }
        '13'    { Remove-OrphanedProcesses }
        '14'    { Remove-RunnerLogFiles }
        '15'    { Remove-TempFiles }
        '16'    {
            Write-ColorOutput 'Thanks for using GitHub Actions Runner Manager!' -Color Green
            Write-ColorOutput 'All runners remain active in the background.'   -Color Blue
            exit 0
        }
        default {
            if ($choice -ne '') {
                Write-ColorOutput "Invalid choice: '$choice'. Please enter 1-16." -Color Red
            }
            Read-Host 'Press Enter to continue'
        }
    }
}
#Requires -Version 5.1
# runner-manager.ps1 - Interactive GitHub Actions Runner Management System (Windows)
#
# GitHub recommends placing runners under C:\actions-runner\ to avoid issues with
# long paths and service identity folder permissions on Windows.
# Place this script in that directory, e.g. C:\actions-runner\runner-manager.ps1
#
# Usage:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # one-time, if needed
#   .\runner-manager.ps1

Set-StrictMode -Version Latest

# Base directory is the folder containing this script
$script:BaseDir = $PSScriptRoot

# ── Library loading ──────────────────────────────────────────────────────────

function Test-LibraryFiles {
    $libFiles = @('Colors.ps1', 'GitHub.ps1', 'Download.ps1', 'Setup.ps1',
                  'Monitor.ps1', 'Dependencies.ps1', 'Cleanup.ps1')
    $missing  = $libFiles | Where-Object { -not (Test-Path "$script:BaseDir\lib\$_") }

    if ($missing) {
        Write-Host 'Error: Missing library files:' -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  lib\$_" -ForegroundColor Red }
        Write-Host 'Ensure all lib\ files are present next to runner-manager.ps1.' -ForegroundColor Yellow
        exit 1
    }
}

function Import-Libraries {
    try {
        . "$script:BaseDir\lib\Colors.ps1"
        . "$script:BaseDir\lib\GitHub.ps1"
        . "$script:BaseDir\lib\Download.ps1"
        . "$script:BaseDir\lib\Setup.ps1"
        . "$script:BaseDir\lib\Monitor.ps1"
        . "$script:BaseDir\lib\Dependencies.ps1"
        . "$script:BaseDir\lib\Cleanup.ps1"
    } catch {
        Write-Host "Error importing libraries: $_" -ForegroundColor Red
        exit 1
    }
}

# ── Startup checks ───────────────────────────────────────────────────────────

function Test-BasicDependencies {
    # Warn if curl is missing (needed for downloads as a fallback)
    if (-not (Get-Command curl -ErrorAction SilentlyContinue)) {
        Write-ColorOutput 'Warning: curl not found. Invoke-WebRequest will be used for downloads.' -Color Yellow
    }
}

# ── Load libraries at script scope BEFORE defining functions ────────────────

# Define a fallback version of Write-ColorOutput in case import fails
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $Color
}

# Test and load libraries
Test-LibraryFiles
Import-Libraries

# ── Menu ─────────────────────────────────────────────────────────────────────

function Show-Menu {
    Clear-Host
    Write-ColorOutput '==========================================' -Color Blue
    Write-ColorOutput '   GitHub Actions Runner Manager'          -Color Blue
    Write-ColorOutput '       Windows Fleet Management'           -Color Blue
    Write-ColorOutput '==========================================' -Color Blue
    Write-Host ''
    Write-ColorOutput 'RUNNER MANAGEMENT'                        -Color Green
    Write-ColorOutput ' 1. Mass Configure New Runners'           -Color Green
    Write-ColorOutput ' 2. Start All Existing Runners'           -Color Green
    Write-ColorOutput ' 3. Terminate All Runners'                -Color Green
    Write-Host ''
    Write-ColorOutput 'MONITORING & STATUS'                      -Color Cyan
    Write-ColorOutput ' 4. Show Runner Status (one-time)'        -Color Cyan
    Write-ColorOutput ' 5. Monitor Runners (real-time)'          -Color Cyan
    Write-ColorOutput ' 6. View Runner Logs'                     -Color Cyan
    Write-ColorOutput ' 7. Check System Health'                  -Color Cyan
    Write-Host ''
    Write-ColorOutput 'SYSTEM MANAGEMENT'                        -Color Yellow
    Write-ColorOutput ' 8. Check Dependencies'                   -Color Yellow
    Write-ColorOutput ' 9. Install Missing Dependencies'         -Color Yellow
    Write-ColorOutput '10. Setup Python Environment'             -Color Yellow
    Write-Host ''
    Write-ColorOutput 'CLEANUP & MAINTENANCE'                    -Color Red
    Write-ColorOutput '11. Remove Specific Runners'              -Color Red
    Write-ColorOutput '12. Cleanup Orphaned Processes'           -Color Red
    Write-ColorOutput '13. Cleanup Log Files'                    -Color Red
    Write-ColorOutput '14. Cleanup Temporary Files'              -Color Red
    Write-Host ''
    Write-ColorOutput '15. Exit'                                  -Color Green
    Write-Host ''
}

# ── Main loop ─────────────────────────────────────────────────────────────────

function Main {
    Test-BasicDependencies

    Write-ColorOutput 'GitHub Actions Runner Manager loaded successfully!' -Color Green
    Write-ColorOutput "Base directory: $script:BaseDir"                   -Color Blue
    Write-Host ''

    while ($true) {
        Show-Menu
        $rawChoice = Read-Host 'Enter your choice (1-16)'
        $choice = if ($rawChoice) { $rawChoice.Trim() } else { '' }
        
        # Convert to string for consistent matching
        $choice = [string]$choice

        switch ($choice) {
            '1'     { Start-MassConfigureRunners }
            '2'     { Start-AllRunners }
            '3'     { Stop-AllRunners }
            '4'     { Show-RunnerStatus; Read-Host 'Press Enter to continue' }
            '5'     { Watch-Runners }
            '6'     { Show-RunnerLogs }
            '7'     { Show-SystemHealth }
            '8'     { Test-AllDependencies }
            '9'     { Install-RequiredDependencies }
            '10'    { New-RunnerPythonEnvironment }
            '11'    { Repair-RunnerGitBashPath }
            '12'    { Remove-SpecificRunners }
            '13'    { Remove-OrphanedProcesses }
            '14'    { Remove-RunnerLogFiles }
            '15'    { Remove-TempFiles }
            '16'    {
                Write-ColorOutput 'Thanks for using GitHub Actions Runner Manager!' -Color Green
                Write-ColorOutput 'All runners remain active in the background.'   -Color Blue
                exit 0
            }
            default {
                if ($choice -ne '') {
                    Write-ColorOutput "Invalid choice: '$choice'. Please enter 1-16." -Color Red
                }
                Read-Host 'Press Enter to continue'
            }
        }
    }
}

Main

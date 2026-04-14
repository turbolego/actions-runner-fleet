#Requires -Version 5.1
# setup-runner.ps1 - Dependency check for Windows GitHub Actions self-hosted runners
# Runs without requiring administrator privileges.

Set-StrictMode -Version Latest

Write-Host 'Setting up self-hosted runner dependencies (Windows, no elevation required)...'
Write-Host ''

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
               [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host 'Note: Running as Administrator.'
}

# ── Python ──────────────────────────────────────────────────────────────────
Write-Host 'Checking Python...'

$pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
             elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
             else { $null }

if ($pythonCmd) {
    $pyVersion = (& $pythonCmd --version 2>&1).ToString().Trim()
    Write-Host "[OK] Python is available: $pyVersion"

    # Check venv module
    & $pythonCmd -c 'import venv' 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[OK] Python venv module is available'

        # Test actual venv creation
        $testVenvDir = Join-Path $env:TEMP "runner-venv-test-$PID"
        try {
            & $pythonCmd -m venv $testVenvDir 2>$null
            if (Test-Path "$testVenvDir\Scripts\activate.ps1") {
                Write-Host '[OK] Virtual environment creation works'
            }
            else {
                Write-Host '[WARNING] Virtual environment creation failed — check your Python installation'
            }
        }
        catch {
            Write-Host '[WARNING] Virtual environment creation failed'
        }
        finally {
            Remove-Item $testVenvDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host '[WARNING] Python venv module not available'
        Write-Host "          Fix: winget install Python.Python.3 --override '/quiet PrependPath=1'"
    }
}
else {
    Write-Host '[WARNING] Python not found. Some workflows may not work.'
    Write-Host '          Install: winget install Python.Python.3'
    Write-Host '             or  : https://www.python.org/downloads/'
}

# ── Node.js ──────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Checking Node.js...'

if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node --version
    Write-Host "[OK] Node.js is available: $nodeVersion"

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmVersion = npm --version
        Write-Host "[OK] npm is available: $npmVersion"
    }
    else {
        Write-Host '[WARNING] npm not found'
    }
}
else {
    Write-Host '[WARNING] Node.js not found. JavaScript workflows may not work.'
    Write-Host '          Install: winget install OpenJS.NodeJS.LTS'
    Write-Host '             or  : https://nodejs.org'
}

# ── Basic tools ───────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Checking basic tools...'
foreach ($tool in @('git', 'curl', 'jq')) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $tool is available"
    }
    else {
        Write-Host "[WARNING] $tool not found"
        switch ($tool) {
            'git'  { Write-Host '          Install: winget install Git.Git' }
            'curl' { Write-Host '          Note   : curl.exe is built into Windows 10+; ensure %SystemRoot%\System32 is in PATH' }
            'jq'   { Write-Host '          Install: winget install jqlang.jq  (optional)' }
        }
    }
}

# ── Docker (optional) ─────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Checking Docker...'
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerVersion = docker --version 2>&1
    Write-Host "[OK] Docker is available: $dockerVersion"
}
else {
    Write-Host '[WARNING] Docker not found (optional — required only for container-based workflows)'
    Write-Host '          Install: https://docs.docker.com/desktop/windows/'
}

# ── Write permissions ─────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Testing write permissions...'
$testDir = Join-Path $env:TEMP "runner-perm-test-$PID"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    Set-Content  -Path "$testDir\probe" -Value 'ok'
    Remove-Item  -Path $testDir -Recurse -Force
    Write-Host '[OK] Write permissions OK'
}
catch {
    Write-Host "[ERROR] Write permission test failed: $($_.Exception.Message)"
}

# ── Local directories runners may need ────────────────────────────────────────
Write-Host ''
Write-Host 'Creating common runner directories...'
foreach ($dir in @("$env:APPDATA\npm", "$env:LOCALAPPDATA\pip\Cache")) {
    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
}
Write-Host '[OK] Runner directories ready'

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Basic dependency check complete!'
Write-Host ''
Write-Host 'Summary:'
Write-Host '  - Basic tools checked'
Write-Host '  - Write permissions verified'
Write-Host '  - Runner directories created'
Write-Host ''
Write-Host 'Note: This script checks dependencies without requiring elevated privileges.'
Write-Host '      Most GitHub Actions workflows should work with the current setup.'
Write-Host ''

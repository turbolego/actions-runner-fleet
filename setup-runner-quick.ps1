#Requires -Version 5.1
# setup-runner-quick.ps1 - Quick setup wizard for GitHub Actions runners

Set-StrictMode -Version Latest

$BaseDir = $PSScriptRoot

# Import libraries
Write-Host "Loading libraries..." -ForegroundColor Blue
. "$BaseDir\lib\Colors.ps1"
. "$BaseDir\lib\GitHub.ps1"
. "$BaseDir\lib\Download.ps1"
. "$BaseDir\lib\Setup.ps1"
. "$BaseDir\lib\Monitor.ps1"
. "$BaseDir\lib\Dependencies.ps1"
. "$BaseDir\lib\Cleanup.ps1"

Write-ColorOutput "GitHub Actions Runner Setup Wizard" -Color Green
Write-ColorOutput "===================================" -Color Blue
Write-Host ""

# Step 1: Check dependencies
Write-ColorOutput "Step 1: Checking system dependencies..." -Color Blue
Write-Host ""
Test-AllDependencies
Write-Host ""

# Step 2: Mass configure runners
Write-ColorOutput "Step 2: Setting up runners..." -Color Blue
Write-Host ""
Start-MassConfigureRunners
Write-Host ""

# Step 3: Start runners
Write-ColorOutput "Step 3: Starting runners..." -Color Blue
Write-Host ""
Start-AllRunners

Write-ColorOutput "Setup complete!" -Color Green

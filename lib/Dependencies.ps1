# Dependencies.ps1 - System dependency management functions

# Check all required and optional dependencies
function Test-AllDependencies {
    Write-ColorOutput '=== Checking System Dependencies ===' -Color Blue

    $missingDeps = @()

    $required = @('git', 'curl', 'node', 'npm')

    Write-ColorOutput 'Checking required dependencies...' -Color Blue
    foreach ($cmd in $required) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            try {
                $version = (& $cmd --version 2>&1 | Select-Object -First 1).ToString().Trim()
            }
            catch {
                $version = 'installed'
            }
            Write-ColorOutput "  [OK]      $cmd ($version)" -Color Green
        }
        else {
            $missingDeps += $cmd
            Write-ColorOutput "  [MISSING] $cmd" -Color Red
        }
    }

    # Python may be 'python' or 'python3' on Windows
    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
                 elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                 else { $null }

    if ($pythonCmd) {
        $pyVersion = (& $pythonCmd --version 2>&1 | Select-Object -First 1).ToString().Trim()
        Write-ColorOutput "  [OK]      $pythonCmd ($pyVersion)" -Color Green

        # Test venv
        $venvCheck = & $pythonCmd -c 'import venv' 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput '  [OK]      python venv module' -Color Green
        }
        else {
            Write-ColorOutput '  [MISSING] python venv module' -Color Red
            $missingDeps += 'python-venv'
        }
    }
    else {
        Write-ColorOutput '  [MISSING] python (python or python3)' -Color Red
        $missingDeps += 'python'
    }

    # Check that bash resolves to Git Bash, not WSL bash.
    # WSL bash (C:\Windows\system32\bash.EXE) cannot resolve Windows-style temp paths
    # used by the runner for 'shell: bash' steps, causing "No such file or directory".
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) {
        if ($bashCmd.Source -ilike '*system32*') {
            Write-ColorOutput "  [ERROR]   bash resolves to WSL ($($bashCmd.Source))" -Color Red
            Write-ColorOutput '            Workflows using shell: bash WILL FAIL on this runner.' -Color Red
            Write-ColorOutput "            Run 'Repair Git Bash PATH' from the menu to fix this." -Color Yellow
            $missingDeps += 'git-bash'
        }
        else {
            Write-ColorOutput "  [OK]      bash ($($bashCmd.Source))" -Color Green
        }
    }
    else {
        $gitBashExe = 'C:\Program Files\Git\bin\bash.exe'
        if (Test-Path $gitBashExe) {
            Write-ColorOutput "  [WARNING] bash not in PATH but found at $gitBashExe" -Color Yellow
            Write-ColorOutput "            Run 'Repair Git Bash PATH' from the menu to fix this." -Color Yellow
            $missingDeps += 'git-bash-path'
        }
        else {
            Write-ColorOutput '  [MISSING] bash — Git for Windows not found; install it to enable shell: bash.' -Color Red
            $missingDeps += 'git-bash'
        }
    }

    Write-Host ''
    Write-ColorOutput 'Checking optional dependencies...' -Color Blue
    $optional = @('docker', 'jq', 'winget', 'choco')
    foreach ($cmd in $optional) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            Write-ColorOutput "  [OK]      $cmd (optional)" -Color Green
        }
        else {
            Write-ColorOutput "  [-]       $cmd (optional, not required)" -Color Yellow
        }
    }

    Write-Host ''
    if ($missingDeps.Count -eq 0) {
        Write-ColorOutput 'All required dependencies are available!' -Color Green
    }
    else {
        Write-ColorOutput "Missing required dependencies: $($missingDeps -join ', ')" -Color Red
        Write-ColorOutput "Run 'Install Missing Dependencies' from the main menu to install them." -Color Yellow
    }

    Read-Host 'Press Enter to continue'
}

# Attempt to install missing dependencies via winget or Chocolatey
function Install-RequiredDependencies {
    Write-ColorOutput '=== Installing System Dependencies ===' -Color Blue
    Write-Host ''

    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $hasChoco  = [bool](Get-Command choco  -ErrorAction SilentlyContinue)

    if (-not $hasWinget -and -not $hasChoco) {
        Write-ColorOutput 'Neither winget nor Chocolatey was found on this system.' -Color Yellow
        Write-ColorOutput 'Please install one of the following package managers first:' -Color Blue
        Write-Host '  winget  : https://aka.ms/winget  (built into Windows 10/11)'
        Write-Host '  choco   : https://chocolatey.org/install'
        Write-Host ''
        Write-ColorOutput 'Alternatively, install dependencies manually:' -Color Blue
        Write-Host '  Git     : https://git-scm.com/download/win'
        Write-Host '  Node.js : https://nodejs.org'
        Write-Host '  Python  : https://www.python.org/downloads'
        Write-Host '  curl    : built into Windows 10+ (curl.exe)'
        Read-Host 'Press Enter to continue'
        return
    }

    # Map tool names to package IDs
    $wingetMap = @{
        git   = 'Git.Git'
        node  = 'OpenJS.NodeJS.LTS'
        npm   = 'OpenJS.NodeJS.LTS'
        curl  = 'cURL.cURL'
    }
    $chocoMap = @{
        git  = 'git'
        node = 'nodejs-lts'
        npm  = 'nodejs-lts'
        curl = 'curl'
    }

    $tools      = @('git', 'node', 'npm', 'curl')
    $toInstall  = $tools | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }

    # Deduplicate (node and npm share the same package)
    $packagesToInstall = @{}
    foreach ($tool in $toInstall) {
        $pkgId = if ($hasWinget) { $wingetMap[$tool] } else { $chocoMap[$tool] }
        if ($pkgId) { $packagesToInstall[$pkgId] = $true }
    }

    if ($packagesToInstall.Count -eq 0) {
        Write-ColorOutput 'All required dependencies are already installed!' -Color Green
        Read-Host 'Press Enter to continue'
        return
    }

    foreach ($pkgId in $packagesToInstall.Keys) {
        Write-ColorOutput "Installing $pkgId..." -Color Blue
        if ($hasWinget) {
            winget install --id $pkgId --silent --accept-package-agreements --accept-source-agreements
        }
        else {
            choco install $pkgId -y
        }
    }

    Write-Host ''
    Write-ColorOutput 'Dependency installation complete.' -Color Green
    Write-ColorOutput 'You may need to restart your terminal for PATH changes to take effect.' -Color Yellow
    Read-Host 'Press Enter to continue'
}

# Create a shared Python virtual environment for runners
function New-RunnerPythonEnvironment {
    Write-ColorOutput '=== Setting Up Python Environment ===' -Color Blue

    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
                 elseif (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
                 else { $null }

    if (-not $pythonCmd) {
        Write-ColorOutput 'Error: Python is not installed' -Color Red
        Write-ColorOutput 'Install Python from https://python.org or use option 9.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    $venvDir = Join-Path $script:BaseDir 'python-env'

    if (Test-Path $venvDir) {
        Write-ColorOutput "Python environment already exists at $venvDir" -Color Yellow
        $recreate = Read-Host 'Do you want to recreate it? (y/N)'
        if ($recreate -match '^[yY]$') {
            Remove-Item $venvDir -Recurse -Force
        }
        else {
            Write-ColorOutput 'Keeping existing environment.' -Color Green
            Read-Host 'Press Enter to continue'
            return
        }
    }

    Write-ColorOutput 'Creating Python virtual environment...' -Color Blue
    & $pythonCmd -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput 'Failed to create Python virtual environment' -Color Red
        Read-Host 'Press Enter to continue'
        return
    }

    Write-ColorOutput 'Installing common Python packages...' -Color Blue
    $pip = Join-Path $venvDir 'Scripts\pip.exe'
    & $pip install --upgrade pip
    & $pip install requests pytest playwright

    Write-ColorOutput "Python environment created at $venvDir" -Color Green
    Write-ColorOutput "Activate it with: $venvDir\Scripts\Activate.ps1" -Color Blue
    Read-Host 'Press Enter to continue'
}

# Repair PATH so Git Bash (from Git for Windows) comes before WSL bash.
# WSL bash cannot handle the Windows-style temp-script paths injected by the
# GitHub Actions runner, causing "No such file or directory" for shell: bash steps.
function Repair-RunnerGitBashPath {
    Write-ColorOutput '=== Repair Git Bash PATH ===' -Color Blue
    Write-Host ''

    $gitBashDir    = 'C:\Program Files\Git\bin'
    $gitUsrBinDir  = 'C:\Program Files\Git\usr\bin'

    if (-not (Test-Path $gitBashDir)) {
        Write-ColorOutput 'Git for Windows not found at the expected location.' -Color Red
        Write-ColorOutput "Install it first: winget install Git.Git" -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    # Verify current bash resolution
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd -and $bashCmd.Source -inotlike '*system32*') {
        Write-ColorOutput "bash already resolves to: $($bashCmd.Source)" -Color Green
        Write-ColorOutput 'No PATH repair needed.' -Color Green
        Read-Host 'Press Enter to continue'
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                   [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-ColorOutput 'Administrator privileges are required to modify the Machine PATH.' -Color Red
        Write-ColorOutput 'Restart runner-manager.ps1 as Administrator and try again.' -Color Yellow
        Read-Host 'Press Enter to continue'
        return
    }

    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')

    # Remove any existing Git bin entries, then prepend them in the correct order
    $pathParts = $machinePath -split ';' | Where-Object {
        $_ -and $_ -inotlike '*\Git\bin*' -and $_ -inotlike '*\Git\usr\bin*'
    }
    $newMachinePath = ($gitBashDir, $gitUsrBinDir + $pathParts) -join ';'

    [Environment]::SetEnvironmentVariable('PATH', $newMachinePath, 'Machine')
    $env:PATH = "$gitBashDir;$gitUsrBinDir;$env:PATH"

    Write-ColorOutput 'Machine PATH updated:' -Color Green
    Write-ColorOutput "  Prepended: $gitBashDir" -Color Green
    Write-ColorOutput "  Prepended: $gitUsrBinDir" -Color Green
    Write-Host ''
    Write-ColorOutput 'Restart all runner processes for the change to take effect.' -Color Yellow
    Read-Host 'Press Enter to continue'
}

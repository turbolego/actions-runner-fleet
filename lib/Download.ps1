# Download.ps1 - GitHub Actions runner download and verification functions

function Get-Runner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDir
    )

    Write-ColorOutput "Fetching latest GitHub Actions runner version..." -Color Blue

    try {
        $release = Invoke-RestMethod `
            -Uri 'https://api.github.com/repos/actions/runner/releases/latest' `
            -UseBasicParsing `
            -ErrorAction Stop
        $latestTag = $release.tag_name
    }
    catch {
        Write-ColorOutput "Error: Could not fetch latest runner version from GitHub API" -Color Red
        Write-ColorOutput $_.Exception.Message -Color Red
        return $null
    }

    if ([string]::IsNullOrEmpty($latestTag) -or $latestTag -eq 'null') {
        Write-ColorOutput "Error: Received empty version tag from GitHub API" -Color Red
        return $null
    }

    Write-ColorOutput "Latest runner version: $latestTag" -Color Green

    # Remove 'v' prefix for filename
    $versionNumber = $latestTag.TrimStart('v')

    # Detect architecture
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }

    $zipName    = "actions-runner-win-$arch-$versionNumber.zip"
    $zipPath    = Join-Path $TargetDir $zipName
    $downloadUrl = "https://github.com/actions/runner/releases/download/$latestTag/$zipName"

    # Skip download if a valid archive already exists
    if (Test-Path $zipPath) {
        $existingSize = (Get-Item $zipPath).Length
        if ($existingSize -gt 50MB) {
            Write-ColorOutput "Valid archive already exists, skipping download" -Color Yellow
            return $zipName
        }
        else {
            Write-ColorOutput "Existing archive appears corrupted (too small), re-downloading..." -Color Yellow
            Remove-Item $zipPath -Force
        }
    }

    Write-ColorOutput "Downloading $zipName..." -Color Blue
    Write-ColorOutput "URL: $downloadUrl" -Color Blue

    try {
        Invoke-WebRequest `
            -Uri $downloadUrl `
            -OutFile $zipPath `
            -UseBasicParsing `
            -ErrorAction Stop
    }
    catch {
        Write-ColorOutput "Error: Failed to download runner from GitHub" -Color Red
        Write-ColorOutput $_.Exception.Message -Color Red
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        return $null
    }

    # Verify downloaded file size
    $fileSize = (Get-Item $zipPath).Length
    if ($fileSize -lt 50MB) {
        Write-ColorOutput "Error: Downloaded file is too small ($fileSize bytes), expected ~150 MB+" -Color Red
        Remove-Item $zipPath -Force
        return $null
    }

    Write-ColorOutput "Successfully downloaded and verified $zipName" -Color Green
    return $zipName
}

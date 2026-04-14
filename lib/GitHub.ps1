# GitHub.ps1 - GitHub API and repository functions

# Function to get repository info from URL
function Get-RepoInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    # Remove trailing slash and .git if present
    $Url = $Url.TrimEnd('/') -replace '\.git$', ''

    if ($Url -match 'https://github\.com/([^/]+)/([^/]+)') {
        $script:RepoOwner = $Matches[1]
        $script:RepoName  = $Matches[2]
        Write-Host "Repository: $($script:RepoOwner)/$($script:RepoName)"
        return $true
    }
    else {
        Write-ColorOutput "Error: Invalid GitHub repository URL format" -Color Red
        Write-ColorOutput "Expected: https://github.com/owner/repo" -Color Yellow
        return $false
    }
}

# Get the GitHub URL stored inside a runner's config file
function Get-RepoForDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunnerDir
    )

    $runnerFile = $null
    if (Test-Path "$RunnerDir\.runner") {
        $runnerFile = "$RunnerDir\.runner"
    }
    elseif (Test-Path "$RunnerDir\.runner_migrated") {
        $runnerFile = "$RunnerDir\.runner_migrated"
    }

    if ($runnerFile) {
        $content = Get-Content $runnerFile -Raw -ErrorAction SilentlyContinue
        if ($content -match '"gitHubUrl"\s*:\s*"([^"]*)"') {
            return $Matches[1]
        }
    }

    return 'Unknown'
}

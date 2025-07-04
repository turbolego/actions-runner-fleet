#!/bin/bash
# github.sh - GitHub API and repository functions

# Function to get repository info from URL
get_repo_info() {
    local url="$1"
    # Remove trailing slash and .git if present
    url="${url%/}"
    url="${url%.git}"
    
    # Extract owner and repo name from GitHub URL
    if [[ "$url" =~ https://github\.com/([^/]+)/([^/]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        echo "Repository: $REPO_OWNER/$REPO_NAME"
        return 0
    else
        print_color $RED "Error: Invalid GitHub repository URL format"
        return 1
    fi
}

# Get repository info for a runner directory
get_repo_for_dir() {
    local runner_dir="$1"
    local runner_file
    
    [ -f "$runner_dir/.runner" ] && runner_file="$runner_dir/.runner" || runner_file="$runner_dir/.runner_migrated"
    
    if [ -f "$runner_file" ]; then
        sed -n 's/.*"gitHubUrl":\s*"\([^"]*\)".*/\1/p' "$runner_file" | head -1
    else
        echo "Unknown"
    fi
}

# Get repository info for monitoring (alias for compatibility)
get_repo_for_monitor() {
    get_repo_for_dir "$1"
}

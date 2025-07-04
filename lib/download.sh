#!/bin/bash
# download.sh - GitHub Actions runner download and verification functions

# Function to download latest GitHub Actions runner
download_runner() {
    local target_dir="$1"
    
    print_color $BLUE "Fetching latest GitHub Actions runner version..." >&2
    
    # Get latest release tag
    LATEST_TAG=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
    
    if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
        print_color $RED "Error: Could not fetch latest runner version" >&2
        return 1
    fi
    
    print_color $GREEN "Latest runner version: $LATEST_TAG" >&2
    
    # Remove 'v' prefix from version for filename
    local VERSION_NUMBER="${LATEST_TAG#v}"
    
    # Download runner if not already present
    local tarball="actions-runner-linux-x64-${VERSION_NUMBER}.tar.gz"
    local tarball_path="$target_dir/$tarball"
    
    # Check if file exists and is valid
    if [ -f "$tarball_path" ]; then
        print_color $BLUE "Checking existing tarball..." >&2
        if ! file "$tarball_path" | grep -q "gzip compressed"; then
            print_color $YELLOW "Existing tarball is corrupted, removing and re-downloading..." >&2
            rm -f "$tarball_path"
        else
            print_color $YELLOW "Valid tarball already exists, skipping download" >&2
            echo "$tarball"
            return 0
        fi
    fi
    
    print_color $BLUE "Downloading $tarball..." >&2
    
    # Use more verbose curl with better error handling
    if ! curl -L -f --show-error --silent \
        -o "$tarball_path" \
        "https://github.com/actions/runner/releases/download/${LATEST_TAG}/actions-runner-linux-x64-${VERSION_NUMBER}.tar.gz"; then
        print_color $RED "Error: Failed to download runner from GitHub" >&2
        
        # Show what we actually downloaded if file exists
        if [ -f "$tarball_path" ]; then
            print_color $RED "Downloaded file size: $(ls -lh "$tarball_path" | awk '{print $5}')" >&2
            print_color $RED "File type: $(file "$tarball_path")" >&2
            print_color $RED "First few lines of downloaded content:" >&2
            head -5 "$tarball_path" >&2
            rm -f "$tarball_path"  # Clean up the bad download
        fi
        
        print_color $RED "Download URL was: https://github.com/actions/runner/releases/download/${LATEST_TAG}/actions-runner-linux-x64-${VERSION_NUMBER}.tar.gz" >&2
        return 1
    fi
    
    # Verify the downloaded file
    local file_size=$(stat -f%z "$tarball_path" 2>/dev/null || stat -c%s "$tarball_path" 2>/dev/null || echo "0")
    
    if [ "$file_size" -lt 50000000 ]; then  # Less than 50MB is suspicious
        print_color $RED "Error: Downloaded file is too small ($file_size bytes)" >&2
        print_color $RED "Expected size should be around 150MB+" >&2
        print_color $RED "File type: $(file "$tarball_path")" >&2
        print_color $RED "File contents preview:" >&2
        head -5 "$tarball_path" >&2
        rm -f "$tarball_path"
        return 1
    fi
    
    if ! file "$tarball_path" | grep -q "gzip compressed"; then
        print_color $RED "Error: Downloaded file is not a valid gzip archive" >&2
        print_color $RED "File type: $(file "$tarball_path")" >&2
        # Show first few lines to help debug
        print_color $RED "File contents preview:" >&2
        head -3 "$tarball_path" >&2
        rm -f "$tarball_path"
        return 1
    fi
    
    print_color $GREEN "Successfully downloaded and verified $tarball" >&2
    echo "$tarball"
}

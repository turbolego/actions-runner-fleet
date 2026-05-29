#!/bin/bash
# download.sh - GitHub Actions runner download and verification functions

# Function to detect OS and architecture
detect_os_and_arch() {
    local os_type=$(uname -s)
    local arch=$(uname -m)
    
    # Normalize OS type
    case "$os_type" in
        Darwin)
            RUNNER_OS="osx"
            ;;
        Linux)
            RUNNER_OS="linux"
            ;;
        *)
            print_color $RED "Error: Unsupported operating system: $os_type" >&2
            return 1
            ;;
    esac
    
    # Normalize architecture
    case "$arch" in
        x86_64)
            RUNNER_ARCH="x64"
            ;;
        arm64|aarch64)
            RUNNER_ARCH="arm64"
            ;;
        *)
            print_color $RED "Error: Unsupported architecture: $arch" >&2
            return 1
            ;;
    esac
    
    print_color $GREEN "Detected OS: $RUNNER_OS, Architecture: $RUNNER_ARCH" >&2
    return 0
}

# Function to download latest GitHub Actions runner
download_runner() {
    local target_dir="$1"
    
    # Ensure cache directory exists
    mkdir -p "$target_dir"
    
    print_color $BLUE "Fetching latest GitHub Actions runner version..." >&2
    
    # Detect OS and architecture
    if ! detect_os_and_arch; then
        return 1
    fi
    
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
    local tarball="actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${VERSION_NUMBER}.tar.gz"
    local tarball_path="$target_dir/$tarball"
    
    # Check if file exists and is valid (tarball caching)
    if [ -f "$tarball_path" ]; then
        print_color $BLUE "Checking cached tarball..." >&2
        if ! file "$tarball_path" | grep -q "gzip compressed"; then
            print_color $YELLOW "Cached tarball is corrupted, removing and re-downloading..." >&2
            rm -f "$tarball_path"
        else
            print_color $YELLOW "Valid tarball found in cache, skipping download" >&2
            echo "$tarball"
            return 0
        fi
    fi
    
    # Remove old versions from cache to save space
    find "$target_dir" -name "actions-runner-*.tar.gz" ! -name "$tarball" -delete 2>/dev/null
    
    print_color $BLUE "Downloading $tarball..." >&2
    
    # Use more verbose curl with better error handling
    if ! curl -L -f --show-error --silent \
        -o "$tarball_path" \
        "https://github.com/actions/runner/releases/download/${LATEST_TAG}/actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${VERSION_NUMBER}.tar.gz"; then
        print_color $RED "Error: Failed to download runner from GitHub" >&2
        
        # Show what we actually downloaded if file exists
        if [ -f "$tarball_path" ]; then
            print_color $RED "Downloaded file size: $(ls -lh "$tarball_path" | awk '{print $5}')" >&2
            print_color $RED "File type: $(file "$tarball_path")" >&2
            print_color $RED "First few lines of downloaded content:" >&2
            head -5 "$tarball_path" >&2
            rm -f "$tarball_path"  # Clean up the bad download
        fi
        
        print_color $RED "Download URL was: https://github.com/actions/runner/releases/download/${LATEST_TAG}/actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${VERSION_NUMBER}.tar.gz" >&2
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

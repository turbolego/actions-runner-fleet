#!/bin/bash
# setup.sh - Runner setup and configuration functions

# Function to setup a single runner
setup_single_runner() {
    local runner_dir="$1"
    local repo_url="$2"
    local token="$3"
    local runner_name="$4"
    local tarball="$5"
    
    print_color $BLUE "Setting up runner: $runner_name in $runner_dir"
    
    # Create runner directory
    mkdir -p "$runner_dir"
    cd "$runner_dir"
    
    # Extract runner if not already done
    if [ ! -f "./config.sh" ]; then
        print_color $BLUE "Extracting runner tarball..."
        local tarball_path="$BASE_DIR/$tarball"
        
        # Verify tarball exists and is valid before extraction
        if [ ! -f "$tarball_path" ]; then
            print_color $RED "Error: Tarball not found at $tarball_path"
            return 1
        fi
        
        if ! file "$tarball_path" | grep -q "gzip compressed"; then
            print_color $RED "Error: Tarball is not a valid gzip archive"
            print_color $RED "File type: $(file "$tarball_path")"
            return 1
        fi
        
        tar xzf "$tarball_path"
        
        if [ $? -ne 0 ]; then
            print_color $RED "Error: Failed to extract runner tarball"
            return 1
        fi
        
        # Verify extraction was successful
        if [ ! -f "./config.sh" ]; then
            print_color $RED "Error: config.sh not found after extraction"
            return 1
        fi
        
        print_color $GREEN "Successfully extracted runner files"
    else
        print_color $YELLOW "Runner already extracted, skipping extraction"
    fi
    
    # Copy no-sudo setup script (preferred for non-interactive usage)
    if [ ! -f "./setup-runner-no-sudo.sh" ]; then
        cp "$BASE_DIR/setup-runner-no-sudo.sh" "./setup-runner-no-sudo.sh"
    fi
    
    # Fix line endings in setup script (convert Windows CRLF to Unix LF)
    if command -v dos2unix >/dev/null 2>&1; then
        dos2unix "./setup-runner-no-sudo.sh" 2>/dev/null || true
    else
        # Alternative method if dos2unix is not available
        sed -i 's/\r$//' "./setup-runner-no-sudo.sh" 2>/dev/null || true
    fi
    
    # Make setup script executable
    chmod +x "./setup-runner-no-sudo.sh"
    
    # Run no-sudo setup script (fast and non-interactive)
    print_color $BLUE "Running dependency check (no sudo required)..."
    bash "./setup-runner-no-sudo.sh"
    
    print_color $GREEN "Dependency check complete. Skipping sudo-based installations for automated setup."
    
    # Configure runner
    print_color $BLUE "Configuring runner..."
    ./config.sh --url "$repo_url" --token "$token" --name "$runner_name" --work "_work" --labels "Playwright" --runnergroup "Default" --replace --unattended
    
    if [ $? -eq 0 ]; then
        print_color $GREEN "Runner $runner_name configured successfully"
        return 0
    else
        print_color $RED "Error: Failed to configure runner $runner_name"
        return 1
    fi
}

# Function to mass configure runners
mass_configure_runners() {
    print_color $BLUE "=== Mass Runner Configuration ==="
    
    # Get number of runners
    read -p "How many runners do you want to set up? " num_runners
    
    # Validate input
    if ! [[ "$num_runners" =~ ^[0-9]+$ ]] || [ "$num_runners" -le 0 ]; then
        print_color $RED "Error: Please enter a valid positive number"
        return 1
    fi
    
    # Get repository URL
    read -p "Enter the GitHub repository URL: " repo_url
    
    # Validate and extract repo info
    if ! get_repo_info "$repo_url"; then
        return 1
    fi
    
    # Create base directory name from repo
    base_name="${REPO_OWNER}_${REPO_NAME}"
    
    # Check if any runners already exist
    existing_runners=()
    for i in $(seq 1 $num_runners); do
        runner_name="${base_name}-${i}"
        runner_dir="$BASE_DIR/$runner_name"
        if [ -d "$runner_dir" ]; then
            existing_runners+=("$runner_name")
        fi
    done
    
    # If runners exist, ask to remove them
    if [ ${#existing_runners[@]} -gt 0 ]; then
        print_color $YELLOW "Found ${#existing_runners[@]} existing runner(s):"
        for runner in "${existing_runners[@]}"; do
            echo "  - $runner"
        done
        echo
        print_color $YELLOW "Do you want to remove existing runners and recreate them? (y/N): "
        read remove_existing
        
        if [[ "$remove_existing" == [yY] ]]; then
            print_color $BLUE "Removing existing runners..."
            for runner in "${existing_runners[@]}"; do
                runner_dir="$BASE_DIR/$runner"
                print_color $YELLOW "Removing runner: $runner"
                
                # Try to unconfigure the runner first
                if [ -f "$runner_dir/config.sh" ]; then
                    cd "$runner_dir"
                    print_color $BLUE "Unconfiguring runner $runner..."
                    # Note: config.sh remove doesn't support --unattended, so we skip removal
                    # The runner will be removed from GitHub when we register the new one with --replace
                    print_color $YELLOW "Skipping runner unconfiguration (will be replaced during setup)"
                    cd "$BASE_DIR"
                fi
                
                # Remove the directory
                rm -rf "$runner_dir"
                print_color $GREEN "✓ Removed $runner"
            done
        else
            print_color $YELLOW "Operation cancelled. Existing runners will not be modified."
            read -p "Press Enter to return to main menu..."
            return 1
        fi
    fi
    
    # Get token
    echo
    print_color $YELLOW "WARNING: The token will be visible on screen. Ensure no one is watching."
    read -p "Enter the GitHub runner token: " token
    
    if [ -z "$token" ]; then
        print_color $RED "Error: Token cannot be empty"
        return 1
    fi
    
    # Ask if user wants to install missing dependencies
    echo
    print_color $YELLOW "Do you want to install missing system dependencies with sudo? (y/N)"
    print_color $BLUE "This will install python3-venv and other packages needed for GitHub Actions."
    read install_deps
    
    if [[ "$install_deps" == [yY] ]]; then
        print_color $BLUE "Installing dependencies first..."
        install_dependencies
        if [ $? -ne 0 ]; then
            print_color $RED "Dependency installation failed. Continuing with runner setup..."
            read -p "Press Enter to continue..."
        fi
    fi
    
    # Download runner tarball
    print_color $BLUE "Downloading GitHub Actions runner..."
    tarball=$(download_runner "$BASE_DIR")
    download_result=$?
    
    if [ $download_result -ne 0 ]; then
        print_color $RED "Failed to download GitHub Actions runner tarball."
        print_color $YELLOW "Please check your internet connection and try again."
        read -p "Press Enter to return to main menu..."
        return 1
    fi
    
    print_color $GREEN "Successfully downloaded: $tarball"
    
    # Create base directory name from repo (moved here after token input)
    base_name="${REPO_OWNER}_${REPO_NAME}"
    
    print_color $BLUE "Setting up $num_runners runners for $REPO_OWNER/$REPO_NAME..."
    
    # Setup each runner
    for i in $(seq 1 $num_runners); do
        runner_name="${base_name}-${i}"
        runner_dir="$BASE_DIR/$runner_name"
        
        print_color $YELLOW "Setting up runner $i of $num_runners..."
        
        if setup_single_runner "$runner_dir" "$repo_url" "$token" "$runner_name" "$tarball"; then
            print_color $GREEN "✓ Runner $runner_name setup complete"
        else
            print_color $RED "✗ Failed to setup runner $runner_name"
        fi
        
        echo "---"
    done
    
    print_color $GREEN "Mass configuration complete!"
    read -p "Press Enter to continue..."
}

# Function to start all runners
start_all_runners() {
    print_color $BLUE "=== Starting All Runners ==="
    
    local count=0
    find "$BASE_DIR" -maxdepth 2 -mindepth 2 -type f -name "run.sh" | while read -r script; do
        RUNNER_DIR="$(dirname "$script")"
        RUNNER_NAME="$(basename "$RUNNER_DIR")"
        
        print_color $BLUE "Checking runner: $RUNNER_NAME..."
        
        # Check if runner is already configured
        if [ ! -f "$RUNNER_DIR/.runner" ] && [ ! -f "$RUNNER_DIR/.runner_migrated" ]; then
            print_color $YELLOW "⚠ Runner $RUNNER_NAME is not configured. Skipping..."
            continue
        fi
        
        # Check if runner is already running
        if pgrep -f "$RUNNER_DIR/run.sh" >/dev/null 2>&1; then
            print_color $YELLOW "⚠ Runner $RUNNER_NAME is already running. Skipping..."
            continue
        fi
        
        # Make run.sh executable
        chmod +x "$script"
        
        # Start runner in background
        echo "Started runner $RUNNER_NAME at $(date)" >> "$RUNNER_DIR/run.log"
        print_color $GREEN "Starting runner: $RUNNER_NAME"
        nohup bash "$script" >> "$RUNNER_DIR/run.log" 2>&1 &
        
        count=$((count + 1))
    done
    
    print_color $GREEN "Started $count new runners in background"
    
    # Show current status
    echo
    local total_active=$(ps -eo pid,cmd --no-headers 2>/dev/null | grep -c '[b]ash .*run.sh' || echo "0")
    print_color $BLUE "Total active runners: $total_active"
    
    read -p "Press Enter to continue..."
}

# Function to terminate runners
terminate_runners() {
    print_color $BLUE "=== Terminate Runners ==="
    
    # Show current runners first
    show_runner_status
    
    print_color $YELLOW "Are you sure you want to kill all run.sh processes? (y/N): "
    read confirm
    
    if [[ "$confirm" == [yY] ]]; then
        # Find and kill all bash processes running run.sh
        PIDS=$(ps aux | grep '[b]ash .*run.sh' | awk '{print $2}')
        
        if [ -z "$PIDS" ]; then
            print_color $YELLOW "No run.sh processes found."
        else
            print_color $BLUE "Killing the following run.sh processes: $PIDS"
            kill $PIDS
            
            print_color $BLUE "Killing any orphaned node/npm/playwright processes..."
            pkill -f 'node|npm|playwright' 2>/dev/null
            
            print_color $GREEN "All run.sh and related processes have been terminated."
        fi
    else
        print_color $YELLOW "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..."
}

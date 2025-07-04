#!/bin/bash
# monitor.sh - Runner monitoring and status functions

# Function to show runner status
show_runner_status() {
    print_color $BLUE "=== Runner Status ==="
    
    # Find all runner directories with config files
    local total_configured=0
    local total_running=0
    
    # Check for existing runners
    if [ ! -d "$BASE_DIR" ] || [ -z "$(find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)" ]; then
        print_color $YELLOW "No runner directories found in $BASE_DIR"
        return 0
    fi
    
    # Get terminal width and calculate dynamic column widths
    local terminal_width=$(tput cols 2>/dev/null || echo "80")
    local name_width=30
    local status_width=12
    local type_width=15
    local repo_width=25
    
    # Adjust column widths for wider terminals
    if [ "$terminal_width" -gt 120 ]; then
        name_width=45
        repo_width=40
        if [ "$terminal_width" -gt 150 ]; then
            name_width=55
            repo_width=55
        fi
    fi
    
    # Header for status table
    printf "%-${name_width}s %-${status_width}s %-${type_width}s %-${repo_width}s\n" "Runner Name" "Status" "Type" "Repository"
    printf "%-${name_width}s %-${status_width}s %-${type_width}s %-${repo_width}s\n" "$(printf '%*s' $name_width '' | tr ' ' '-')" "$(printf '%*s' $status_width '' | tr ' ' '-')" "$(printf '%*s' $type_width '' | tr ' ' '-')" "$(printf '%*s' $repo_width '' | tr ' ' '-')"
    
    for runner_dir in "$BASE_DIR"/*; do
        if [ -d "$runner_dir" ]; then
            local runner_name=$(basename "$runner_dir")
            
            # Skip non-runner directories
            # Check if this directory contains runner-specific files
            if [ ! -f "$runner_dir/config.sh" ] && [ ! -f "$runner_dir/.runner" ] && [ ! -f "$runner_dir/.runner_migrated" ] && [ ! -f "$runner_dir/run.sh" ]; then
                # Skip directories that don't have any runner files
                continue
            fi
            
            # Also skip known system directories
            case "$runner_name" in
                "lib"|".git"|".idea"|"node_modules"|"_work"|"temp"|"tmp")
                    continue
                    ;;
            esac
            
            local config_file="$runner_dir/.runner"
            local config_file_migrated="$runner_dir/.runner_migrated"
            local status="Not Configured"
            local runner_type="Unknown"
            local repository="Not Set"
            
            # Check if runner is configured
            if [ -f "$config_file" ] || [ -f "$config_file_migrated" ]; then
                total_configured=$((total_configured + 1))
                
                # Get repository info
                repository=$(get_repo_for_monitor "$runner_dir")
                if [ -z "$repository" ]; then
                    repository="Not Available"
                fi
                
                # Determine runner type based on labels
                if [ -f "$runner_dir/.credentials" ]; then
                    local labels=$(grep -o '"labels":\[[^]]*\]' "$runner_dir/.credentials" 2>/dev/null | sed 's/"labels":\[\([^]]*\)\]/\1/' | tr -d '"' | tr ',' ' ')
                    if echo "$labels" | grep -q "Playwright"; then
                        runner_type="Playwright"
                    elif echo "$labels" | grep -q "linux"; then
                        runner_type="Linux"
                    else
                        runner_type="Custom"
                    fi
                fi
                
                # Check if runner is currently running
                if pgrep -f "$runner_dir/run.sh" >/dev/null 2>&1; then
                    status="Running"
                    total_running=$((total_running + 1))
                else
                    status="Configured"
                fi
            fi
            
            # Format output based on status
            local status_color=$YELLOW
            if [ "$status" = "Running" ]; then
                status_color=$GREEN
            elif [ "$status" = "Configured" ]; then
                status_color=$BLUE
            else
                status_color=$RED
            fi
            
            # Truncate long names for display
            local display_name="$runner_name"
            if [ ${#display_name} -gt $((name_width - 1)) ]; then
                display_name="${display_name:0:$((name_width - 4))}..."
            fi
            
            local display_repo="$repository"
            if [ ${#display_repo} -gt $((repo_width - 1)) ]; then
                display_repo="${display_repo:0:$((repo_width - 4))}..."
            fi
            
            printf "%-${name_width}s " "$display_name"
            printf "${status_color}%-${status_width}s${NC}" "$status"
            printf " %-${type_width}s %-${repo_width}s\n" "$runner_type" "$display_repo"
        fi
    done
    
    echo
    print_color $BLUE "Summary:"
    print_color $GREEN "  Configured runners: $total_configured"
    print_color $GREEN "  Running runners: $total_running"
    print_color $YELLOW "  Idle runners: $((total_configured - total_running))"
}

# Function to monitor runners in real-time
monitor_runners() {
    print_color $BLUE "=== Real-time Runner Monitor ==="
    print_color $YELLOW "Press 'q' or Enter to return to main menu"
    echo
    
    while true; do
        # Clear screen for better readability and redirect any error output
        clear 2>/dev/null
        
        print_color $BLUE "=== GitHub Actions Runner Fleet Monitor ==="
        print_color $YELLOW "$(date)"
        echo
        
        # Show runner status with error suppression
        show_runner_status 2>/dev/null
        
        echo
        print_color $BLUE "=== Process Information ==="
        
        # Show process count with better error handling
        local process_count=$(ps -eo pid,cmd 2>/dev/null | grep -c '[b]ash .*run.sh' 2>/dev/null || echo "0")
        print_color $GREEN "Active run.sh processes: $process_count"
        
        # Show recent activity from logs
        print_color $BLUE "=== Recent Activity (last 5 minutes) ==="
        local found_activity=false
        
        # Use a safer approach to find recent log activity
        for runner_dir in "$BASE_DIR"/*; do
            if [ -d "$runner_dir" ] && [ -f "$runner_dir/run.log" ]; then
                local runner_name=$(basename "$runner_dir")
                # Check if log file was modified in last 5 minutes
                if find "$runner_dir" -name "run.log" -mmin -5 2>/dev/null | grep -q "run.log" 2>/dev/null; then
                    local latest_line=$(tail -1 "$runner_dir/run.log" 2>/dev/null)
                    if [ -n "$latest_line" ]; then
                        print_color $YELLOW "[$runner_name] $latest_line"
                        found_activity=true
                    fi
                fi
            fi
        done 2>/dev/null
        
        if [ "$found_activity" != "true" ]; then
            print_color $GRAY "No recent activity in the last 5 minutes"
        fi
        
        echo
        print_color $BLUE "Refreshing in 30 seconds... (Press 'q' + Enter or just Enter to return to menu)"
        
        # Wait for 30 seconds with ability to interrupt
        local counter=30
        while [ $counter -gt 0 ]; do
            # Check if input is available (non-blocking) with better error handling
            if read -t 1 -n 1 user_input 2>/dev/null < /dev/tty; then
                # If user pressed 'q' or Enter, exit monitoring
                if [[ "$user_input" == "q" ]] || [[ "$user_input" == "" ]]; then
                    print_color $GREEN "Returning to main menu..."
                    return 0
                fi
                # For any other key, continue monitoring
                break
            fi
            counter=$((counter - 1))
        done 2>/dev/null
        
        # If user pressed any key other than 'q', refresh immediately
        if [ $counter -le 0 ]; then
            continue
        fi
    done
}

# Function to view detailed logs
view_logs() {
    print_color $BLUE "=== View Runner Logs ==="
    
    # List available runners with logs
    local runners_with_logs=()
    
    for runner_dir in "$BASE_DIR"/*; do
        if [ -d "$runner_dir" ] && [ -f "$runner_dir/run.log" ]; then
            runners_with_logs+=("$(basename "$runner_dir")")
        fi
    done
    
    if [ ${#runners_with_logs[@]} -eq 0 ]; then
        print_color $YELLOW "No runners with log files found."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $GREEN "Available runners with logs:"
    for i in "${!runners_with_logs[@]}"; do
        echo "$((i+1)). ${runners_with_logs[i]}"
    done
    echo "$((${#runners_with_logs[@]}+1)). View all logs (combined)"
    echo
    
    read -p "Select a runner to view logs (1-$((${#runners_with_logs[@]}+1))) or press Enter to cancel: " choice
    
    if [ -z "$choice" ]; then
        return
    fi
    
    if [ "$choice" -eq $((${#runners_with_logs[@]}+1)) ] 2>/dev/null; then
        print_color $BLUE "=== Combined logs from all runners ==="
        for runner_name in "${runners_with_logs[@]}"; do
            local log_file="$BASE_DIR/$runner_name/run.log"
            if [ -f "$log_file" ]; then
                print_color $YELLOW "--- Logs from $runner_name ---"
                tail -20 "$log_file" 2>/dev/null | while read line; do
                    echo "[$runner_name] $line"
                done
                echo
            fi
        done
    elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#runners_with_logs[@]} ] 2>/dev/null; then
        local selected_runner="${runners_with_logs[$((choice-1))]}"
        local log_file="$BASE_DIR/$selected_runner/run.log"
        
        print_color $BLUE "=== Logs for $selected_runner ==="
        print_color $YELLOW "Showing last 50 lines (press 'q' to exit if using less):"
        echo
        
        if command -v less >/dev/null 2>&1; then
            tail -50 "$log_file" | less
        else
            tail -50 "$log_file"
        fi
    else
        print_color $RED "Invalid selection."
    fi
    
    read -p "Press Enter to continue..."
}

# Function to check system health
check_system_health() {
    print_color $BLUE "=== System Health Check ==="
    
    # Check disk space
    print_color $YELLOW "Disk Space:"
    df -h "$BASE_DIR" 2>/dev/null || df -h /
    echo
    
    # Check memory usage
    print_color $YELLOW "Memory Usage:"
    if command -v free >/dev/null 2>&1; then
        free -h
    else
        # macOS alternative
        vm_stat 2>/dev/null | head -10 || echo "Memory info not available"
    fi
    echo
    
    # Check load average
    print_color $YELLOW "System Load:"
    if [ -f /proc/loadavg ]; then
        cat /proc/loadavg
    else
        uptime | grep -o 'load average.*'
    fi
    echo
    
    # Check runner directories
    print_color $YELLOW "Runner Directory Sizes:"
    for runner_dir in "$BASE_DIR"/*; do
        if [ -d "$runner_dir" ]; then
            local runner_name=$(basename "$runner_dir")
            local size=$(du -sh "$runner_dir" 2>/dev/null | cut -f1)
            printf "  %-30s %s\n" "$runner_name:" "$size"
        fi
    done
    echo
    
    # Check for large log files
    print_color $YELLOW "Large Log Files (>10MB):"
    find "$BASE_DIR" -name "*.log" -size +10M -exec ls -lh {} \; 2>/dev/null | \
    while read -r line; do
        echo "  $line"
    done
    
    # Count of large log files
    local large_logs=$(find "$BASE_DIR" -name "*.log" -size +10M 2>/dev/null | wc -l)
    if [ "$large_logs" -eq 0 ]; then
        print_color $GREEN "  No large log files found"
    else
        print_color $YELLOW "  Found $large_logs large log files"
    fi
    echo
    
    # Check for zombie processes
    print_color $YELLOW "GitHub Actions Related Processes:"
    ps aux | grep -E 'github|runner|node.*playwright' | grep -v grep || echo "  No related processes found"
    
    read -p "Press Enter to continue..."
}

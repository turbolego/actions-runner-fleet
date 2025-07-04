#!/bin/bash
# cleanup.sh - Runner cleanup and maintenance functions

# Function to remove specific runners
remove_specific_runners() {
    print_color $BLUE "=== Remove Specific Runners ==="
    
    # List available runners
    local runners=()
    for runner_dir in "$BASE_DIR"/*; do
        if [ -d "$runner_dir" ]; then
            runners+=($(basename "$runner_dir"))
        fi
    done
    
    if [ ${#runners[@]} -eq 0 ]; then
        print_color $YELLOW "No runners found to remove."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color $GREEN "Available runners:"
    for i in "${!runners[@]}"; do
        echo "$((i+1)). ${runners[i]}"
    done
    echo
    
    read -p "Enter runner numbers to remove (comma-separated, e.g., 1,3,5) or 'all' for all runners: " selection
    
    if [ -z "$selection" ]; then
        print_color $YELLOW "No selection made. Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    local runners_to_remove=()
    
    if [ "$selection" = "all" ]; then
        runners_to_remove=("${runners[@]}")
        print_color $YELLOW "Selected ALL runners for removal."
    else
        # Parse comma-separated list
        IFS=',' read -ra NUMBERS <<< "$selection"
        for num in "${NUMBERS[@]}"; do
            # Remove whitespace
            num=$(echo "$num" | tr -d ' ')
            
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#runners[@]} ]; then
                runners_to_remove+=("${runners[$((num-1))]}")
            else
                print_color $RED "Invalid selection: $num"
            fi
        done
    fi
    
    if [ ${#runners_to_remove[@]} -eq 0 ]; then
        print_color $RED "No valid runners selected."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show runners to be removed
    print_color $YELLOW "Runners to be removed:"
    for runner in "${runners_to_remove[@]}"; do
        echo "  - $runner"
    done
    echo
    
    print_color $RED "WARNING: This will permanently delete the selected runners!"
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ "$confirm" != [yY] ]]; then
        print_color $YELLOW "Operation cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Remove selected runners
    for runner_name in "${runners_to_remove[@]}"; do
        local runner_dir="$BASE_DIR/$runner_name"
        
        print_color $BLUE "Removing runner: $runner_name"
        
        # Stop runner if running
        if pgrep -f "$runner_dir/run.sh" >/dev/null 2>&1; then
            print_color $YELLOW "Stopping running processes for $runner_name..."
            pkill -f "$runner_dir/run.sh"
            sleep 2
        fi
        
        # Try to unconfigure the runner first
        if [ -f "$runner_dir/config.sh" ]; then
            cd "$runner_dir"
            print_color $BLUE "Attempting to unconfigure runner $runner_name..."
            
            # Note: config.sh remove doesn't support --unattended
            # We'll skip this step as it requires manual interaction
            print_color $YELLOW "Skipping unconfiguration (requires manual interaction)"
            cd "$BASE_DIR"
        fi
        
        # Remove the directory
        if [ -d "$runner_dir" ]; then
            rm -rf "$runner_dir"
            print_color $GREEN "✓ Removed $runner_name"
        else
            print_color $YELLOW "⚠ Directory $runner_dir not found"
        fi
    done
    
    print_color $GREEN "Runner removal completed!"
    read -p "Press Enter to continue..."
}

# Function to clean up orphaned processes
cleanup_orphaned_processes() {
    print_color $BLUE "=== Cleanup Orphaned Processes ==="
    
    # Find GitHub Actions related processes
    print_color $BLUE "Searching for GitHub Actions related processes..."
    
    # Look for run.sh processes
    local runsh_pids=$(ps aux | grep '[b]ash .*run.sh' | awk '{print $2}' | tr '\n' ' ')
    
    # Look for node processes that might be from runners
    local node_pids=$(ps aux | grep '[n]ode.*actions' | awk '{print $2}' | tr '\n' ' ')
    
    # Look for npm processes
    local npm_pids=$(ps aux | grep '[n]pm' | awk '{print $2}' | tr '\n' ' ')
    
    # Look for playwright processes
    local playwright_pids=$(ps aux | grep '[p]laywright' | awk '{print $2}' | tr '\n' ' ')
    
    echo
    
    if [ -n "$runsh_pids" ]; then
        print_color $YELLOW "Found run.sh processes: $runsh_pids"
    else
        print_color $GREEN "No run.sh processes found"
    fi
    
    if [ -n "$node_pids" ]; then
        print_color $YELLOW "Found node processes: $node_pids"
    else
        print_color $GREEN "No suspicious node processes found"
    fi
    
    if [ -n "$npm_pids" ]; then
        print_color $YELLOW "Found npm processes: $npm_pids"
    else
        print_color $GREEN "No npm processes found"
    fi
    
    if [ -n "$playwright_pids" ]; then
        print_color $YELLOW "Found playwright processes: $playwright_pids"
    else
        print_color $GREEN "No playwright processes found"
    fi
    
    # Ask user what to clean up
    echo
    local cleanup_needed=false
    
    if [ -n "$runsh_pids" ] || [ -n "$node_pids" ] || [ -n "$npm_pids" ] || [ -n "$playwright_pids" ]; then
        cleanup_needed=true
        print_color $YELLOW "Found processes that may be orphaned."
        echo
        print_color $BLUE "Cleanup options:"
        echo "1. Kill all run.sh processes"
        echo "2. Kill all node/npm/playwright processes"
        echo "3. Kill all GitHub Actions related processes"
        echo "4. Cancel"
        echo
        read -p "Select cleanup option (1-4): " cleanup_choice
        
        case "$cleanup_choice" in
            1)
                if [ -n "$runsh_pids" ]; then
                    print_color $BLUE "Killing run.sh processes: $runsh_pids"
                    kill $runsh_pids 2>/dev/null
                    print_color $GREEN "✓ run.sh processes terminated"
                else
                    print_color $YELLOW "No run.sh processes to kill"
                fi
                ;;
            2)
                local other_pids="$node_pids $npm_pids $playwright_pids"
                if [ -n "$other_pids" ]; then
                    print_color $BLUE "Killing node/npm/playwright processes: $other_pids"
                    kill $other_pids 2>/dev/null
                    print_color $GREEN "✓ node/npm/playwright processes terminated"
                else
                    print_color $YELLOW "No node/npm/playwright processes to kill"
                fi
                ;;
            3)
                local all_pids="$runsh_pids $node_pids $npm_pids $playwright_pids"
                if [ -n "$all_pids" ]; then
                    print_color $BLUE "Killing all GitHub Actions related processes: $all_pids"
                    kill $all_pids 2>/dev/null
                    print_color $GREEN "✓ All related processes terminated"
                else
                    print_color $YELLOW "No processes to kill"
                fi
                ;;
            4)
                print_color $YELLOW "Cleanup cancelled"
                ;;
            *)
                print_color $RED "Invalid selection"
                ;;
        esac
    else
        print_color $GREEN "No orphaned processes found!"
    fi
    
    read -p "Press Enter to continue..."
}

# Function to clean up log files
cleanup_log_files() {
    print_color $BLUE "=== Cleanup Log Files ==="
    
    # Find log files
    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$file")
    done < <(find "$BASE_DIR" -name "*.log" -type f -print0 2>/dev/null)
    
    if [ ${#log_files[@]} -eq 0 ]; then
        print_color $GREEN "No log files found."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show log file information
    print_color $BLUE "Found ${#log_files[@]} log files:"
    echo
    
    local total_size=0
    local large_files=()
    
    for log_file in "${log_files[@]}"; do
        local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
        local size_mb=$((size / 1024 / 1024))
        
        total_size=$((total_size + size))
        
        local runner_name=$(basename "$(dirname "$log_file")")
        local file_name=$(basename "$log_file")
        
        if [ "$size_mb" -gt 10 ]; then
            large_files+=("$log_file")
            print_color $RED "  $runner_name/$file_name (${size_mb}MB - LARGE)"
        elif [ "$size_mb" -gt 1 ]; then
            print_color $YELLOW "  $runner_name/$file_name (${size_mb}MB)"
        else
            print_color $GREEN "  $runner_name/$file_name (${size_mb}MB)"
        fi
    done
    
    local total_size_mb=$((total_size / 1024 / 1024))
    echo
    print_color $BLUE "Total log size: ${total_size_mb}MB"
    
    if [ ${#large_files[@]} -gt 0 ]; then
        print_color $YELLOW "Found ${#large_files[@]} large log files (>10MB)"
    fi
    
    echo
    print_color $BLUE "Cleanup options:"
    echo "1. Delete all log files"
    echo "2. Delete only large log files (>10MB)"
    echo "3. Truncate all log files (keep last 100 lines)"
    echo "4. View log file details"
    echo "5. Cancel"
    echo
    read -p "Select cleanup option (1-5): " cleanup_choice
    
    case "$cleanup_choice" in
        1)
            print_color $RED "WARNING: This will delete ALL log files!"
            read -p "Are you sure? (y/N): " confirm
            if [[ "$confirm" == [yY] ]]; then
                for log_file in "${log_files[@]}"; do
                    rm -f "$log_file"
                done
                print_color $GREEN "✓ All log files deleted"
            else
                print_color $YELLOW "Operation cancelled"
            fi
            ;;
        2)
            if [ ${#large_files[@]} -gt 0 ]; then
                print_color $YELLOW "Deleting ${#large_files[@]} large log files..."
                for log_file in "${large_files[@]}"; do
                    local runner_name=$(basename "$(dirname "$log_file")")
                    print_color $BLUE "Deleting $runner_name/$(basename "$log_file")"
                    rm -f "$log_file"
                done
                print_color $GREEN "✓ Large log files deleted"
            else
                print_color $GREEN "No large log files to delete"
            fi
            ;;
        3)
            print_color $BLUE "Truncating log files to last 100 lines..."
            for log_file in "${log_files[@]}"; do
                local runner_name=$(basename "$(dirname "$log_file")")
                print_color $BLUE "Truncating $runner_name/$(basename "$log_file")"
                
                # Keep last 100 lines
                tail -100 "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
            done
            print_color $GREEN "✓ All log files truncated"
            ;;
        4)
            print_color $BLUE "Log file details:"
            for log_file in "${log_files[@]}"; do
                local runner_name=$(basename "$(dirname "$log_file")")
                local file_name=$(basename "$log_file")
                local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
                local size_mb=$((size / 1024 / 1024))
                
                echo "  $runner_name/$file_name:"
                echo "    Size: ${size_mb}MB"
                echo "    Lines: $lines"
                
                # Show last modification time
                if command -v stat >/dev/null 2>&1; then
                    local mod_time=$(stat -f%Sm "$log_file" 2>/dev/null || stat -c%y "$log_file" 2>/dev/null | cut -d. -f1)
                    echo "    Modified: $mod_time"
                fi
                echo
            done
            ;;
        5)
            print_color $YELLOW "Cleanup cancelled"
            ;;
        *)
            print_color $RED "Invalid selection"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Function to clean up temporary files
cleanup_temp_files() {
    print_color $BLUE "=== Cleanup Temporary Files ==="
    
    # Find temporary files and directories
    local temp_items=()
    
    # Look for common temporary patterns
    while IFS= read -r -d '' item; do
        temp_items+=("$item")
    done < <(find "$BASE_DIR" \( -name "*.tmp" -o -name "*.temp" -o -name "*~" -o -name ".DS_Store" -o -name "Thumbs.db" \) -print0 2>/dev/null)
    
    # Look for _work directories that might be large
    while IFS= read -r -d '' item; do
        temp_items+=("$item")
    done < <(find "$BASE_DIR" -name "_work" -type d -print0 2>/dev/null)
    
    if [ ${#temp_items[@]} -eq 0 ]; then
        print_color $GREEN "No temporary files found."
        read -p "Press Enter to continue..."
        return
    fi
    
    # Show temporary files
    print_color $BLUE "Found ${#temp_items[@]} temporary items:"
    echo
    
    local total_size=0
    
    for item in "${temp_items[@]}"; do
        local runner_name=""
        local relative_path=""
        
        # Get relative path from BASE_DIR
        if [[ "$item" == "$BASE_DIR"/* ]]; then
            relative_path="${item#$BASE_DIR/}"
            runner_name=$(echo "$relative_path" | cut -d'/' -f1)
        else
            relative_path="$item"
            runner_name="unknown"
        fi
        
        if [ -d "$item" ]; then
            local size=$(du -sb "$item" 2>/dev/null | cut -f1 || echo "0")
            local size_mb=$((size / 1024 / 1024))
            total_size=$((total_size + size))
            print_color $YELLOW "  [DIR]  $relative_path (${size_mb}MB)"
        else
            local size=$(stat -f%z "$item" 2>/dev/null || stat -c%s "$item" 2>/dev/null || echo "0")
            local size_mb=$((size / 1024 / 1024))
            total_size=$((total_size + size))
            print_color $BLUE "  [FILE] $relative_path (${size_mb}MB)"
        fi
    done
    
    local total_size_mb=$((total_size / 1024 / 1024))
    echo
    print_color $BLUE "Total size: ${total_size_mb}MB"
    
    echo
    print_color $RED "WARNING: This will permanently delete all temporary files and directories!"
    read -p "Do you want to proceed? (y/N): " confirm
    
    if [[ "$confirm" == [yY] ]]; then
        print_color $BLUE "Deleting temporary items..."
        for item in "${temp_items[@]}"; do
            local relative_path="${item#$BASE_DIR/}"
            print_color $BLUE "Deleting $relative_path"
            rm -rf "$item"
        done
        print_color $GREEN "✓ All temporary files and directories deleted"
    else
        print_color $YELLOW "Operation cancelled"
    fi
    
    read -p "Press Enter to continue..."
}

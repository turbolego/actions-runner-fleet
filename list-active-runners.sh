#!/bin/bash
# list-active-runners.sh (RAM optimized)
# Continuously lists all active run.sh runners and their associated repositories

# Function to get repo for a runner dir (optimized)
get_repo() {
    local runner_dir="$1"
    local runner_file
    
    # Use single test with fallback
    [ -f "$runner_dir/.runner" ] && runner_file="$runner_dir/.runner" || runner_file="$runner_dir/.runner_migrated"
    
    if [ -f "$runner_file" ]; then
        # Use single sed command instead of grep+sed pipeline
        sed -n 's/.*"gitHubUrl":\s*"\([^"]*\)".*/\1/p' "$runner_file" | head -1
    else
        echo "Unknown"
    fi
}

# Main loop
while true; do
    clear
    echo "Active GitHub Actions Runners (run.sh):"
    echo "PID     | Job                          | Repository                  | Runner Dir"
    echo "--------+------------------------------+----------------------------+-----------------------------"
    
    count=0
    
    # Single ps command, process line by line without subshell
    while IFS=' ' read -r pid cmd; do
        [ -z "$pid" ] && continue
        
        # Extract runner dir more efficiently
        runner_dir="${cmd%/run.sh*}"
        runner_dir="${runner_dir##* }"
        
        # Get repo info
        repo=$(get_repo "$runner_dir")
        
        # Get job info more efficiently
        job="-"
        if [ -f "$runner_dir/run.log" ]; then
            # Use single tail+grep instead of grep+tail
            job=$(tail -50 "$runner_dir/run.log" 2>/dev/null | grep -E 'Job name:|Starting job|Running job' | tail -1)
            if [ -n "$job" ]; then
                # Clean up job name in single step
                job="${job#*Job name: }"
                job="${job#*job }"
                job="${job#Starting }"
                job="${job#Running }"
            else
                job="-"
            fi
        fi
        
        # Clean up paths more efficiently
        repo_short="${repo#https://github.com/}"
        runner_dir_short="${runner_dir#/home/tander/}"
        
        printf "%-8s| %-30.30s| %-27.27s| %s\n" "$pid" "$job" "$repo_short" "$runner_dir_short"
        count=$((count + 1))
        
    done < <(ps -eo pid,cmd --no-headers | grep '[b]ash .*run.sh')
    
    if [ "$count" -eq 0 ]; then
        echo "No active runners found."
    fi
    
    echo
    echo "Total active runners: $count"
    echo "(Press Ctrl+C to exit)"
    sleep 2
done

#!/bin/bash
# list-active-runners.sh
# Continuously lists all active run.sh runners and their associated repositories

# Function to get repo for a runner dir
get_repo() {
    local runner_dir="$1"
    # Try to find .runner or .runner_migrated file
    local runner_file=""
    if [ -f "$runner_dir/.runner" ]; then
        runner_file="$runner_dir/.runner"
    elif [ -f "$runner_dir/.runner_migrated" ]; then
        runner_file="$runner_dir/.runner_migrated"
    fi
    if [ -n "$runner_file" ]; then
        grep -m1 'gitHubUrl' "$runner_file" | sed 's/.*"gitHubUrl":\s*"\([^"]*\)".*/\1/'
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
    ps -eo pid,cmd | grep '[b]ash .*run.sh' | while read -r pid cmd; do
        # Extract runner dir from command
        runner_dir=$(echo "$cmd" | sed -E 's/.*bash ([^ ]*\/run.sh).*/\1/' | xargs dirname)
        repo=$(get_repo "$runner_dir")
        # Try to get current job from run.log (last line with 'Job name:' or similar)
        job="-"
        if [ -f "$runner_dir/run.log" ]; then
            job=$(grep -E 'Job name:|Starting job|Running job' "$runner_dir/run.log" | tail -1 | sed 's/.*Job name: //;s/.*job //;s/Starting //;s/Running //')
            [ -z "$job" ] && job="-"
        fi
        # Remove https://github.com/ from repo and /home/tander/ from runner_dir
        repo_short=$(echo "$repo" | sed 's|https://github.com/||')
        runner_dir_short=$(echo "$runner_dir" | sed 's|/home/tander/||')
        printf "%-8s| %-30s| %-27s| %s\n" "$pid" "$job" "$repo_short" "$runner_dir_short"
        count=$((count+1))
    done
    if [ "$count" -eq 0 ]; then
        echo "No active runners found."
    fi
    echo
    echo "Total active runners: $count"
    echo "(Press Ctrl+C to exit)"
    sleep 2

done

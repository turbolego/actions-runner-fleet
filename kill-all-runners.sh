#!/bin/bash
# kill-all-runners.sh
# Kills all running run.sh scripts used for GitHub Actions runners

# Prompt for confirmation before killing processes
read -p "Are you sure you want to kill all run.sh processes? (y/N): " confirm
[[ "$confirm" == [yY] ]] || exit 1

# Find and kill all bash processes running run.sh
PIDS=$(ps aux | grep '[b]ash .*run.sh' | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "No run.sh processes found."
else
    echo "Killing the following run.sh processes: $PIDS"
    kill $PIDS
    # Optionally kill node/npm/Playwright processes
    echo "Killing any orphaned node/npm/Playwright processes..."
    pkill -f 'node|npm|playwright' 2>/dev/null
    echo "All run.sh and related processes have been terminated."
fi

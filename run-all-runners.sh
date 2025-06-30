#!/bin/bash
# filepath: \\wsl.localhost\Ubuntu\home\tander\run-all-runners.sh

# This script copies setup-runner.sh to each runner folder (if not present),
# runs setup-runner.sh, then runs run.sh in each subfolder one level below the current directory

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$BASE_DIR/setup-runner.sh"

find "$BASE_DIR" -maxdepth 2 -mindepth 2 -type f -name "run.sh" | while read -r script; do
    RUNNER_DIR="$(dirname "$script")"
    # Copy setup-runner.sh if not present
    if [ ! -f "$RUNNER_DIR/setup-runner.sh" ]; then
        echo "Copying setup-runner.sh to $RUNNER_DIR"
        cp "$SETUP_SCRIPT" "$RUNNER_DIR/"
    fi
    echo "Running setup-runner.sh in $RUNNER_DIR"
    bash "$RUNNER_DIR/setup-runner.sh"
    chmod +x "$script"
    echo "Started runner in $RUNNER_DIR at $(date)" >> "$RUNNER_DIR/run.log"
    echo "Running: $script in a new background shell"
    nohup bash "$script" >> "$RUNNER_DIR/run.log" 2>&1 &
done

echo "All runners started in background shells. Logs are in each runner's run.log."

# Start the active runner monitor script
echo "Starting active runner monitor..."
bash "$BASE_DIR/list-active-runners.sh"
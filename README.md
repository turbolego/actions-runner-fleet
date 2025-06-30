# Self-Hosted GitHub Actions Runner Management Scripts

This repository provides scripts to automate setup, starting, monitoring, and stopping of multiple self-hosted GitHub Actions runners on a Linux (WSL2/Ubuntu) system.

## Scripts Overview

### 1. `setup-runner.sh`
Installs all required dependencies for a GitHub Actions runner, including Python, Node.js, jq, and Playwright browser dependencies.

**Usage:**
```bash
bash setup-runner.sh
```
- Installs Python3, venv, pip, jq, Node.js, and Playwright dependencies.
- Installs Playwright browsers if Playwright is present.
- Creates necessary cache directories.

---

### 2. `run-all-runners.sh`
Finds all `run.sh` scripts in subdirectories (one level below the current directory), ensures each has a `setup-runner.sh`, runs setup, and starts each runner in a background shell. Also launches the runner monitor.

**Usage:**
```bash
bash run-all-runners.sh
```
- Copies `setup-runner.sh` to each runner directory if missing.
- Runs `setup-runner.sh` in each runner directory.
- Starts each `run.sh` in a background shell (logs output to `run.log`).
- Launches `list-active-runners.sh` to monitor runners.

---

### 3. `list-active-runners.sh`
Continuously displays all active `run.sh` runner processes, showing their PID, current job, associated repository, and runner directory. Updates every 2 seconds.

**Usage:**
```bash
bash list-active-runners.sh
```
- Lists all active runner processes.
- Shows job name (if available), repository, and runner directory.
- Updates live in the terminal.

---

### 4. `kill-all-runners.sh`
Safely terminates all running `run.sh` processes and optionally cleans up orphaned Node.js, npm, and Playwright processes. Prompts for confirmation before killing processes.

**Usage:**
```bash
bash kill-all-runners.sh
```
- Prompts for confirmation.
- Kills all `run.sh` runner processes.
- Kills any orphaned Node.js, npm, or Playwright processes.

---

## Example Workflow

1. **Set up dependencies for all runners:**
   ```bash
   bash run-all-runners.sh
   # This will set up and start all runners, and launch the monitor.
   ```

2. **Monitor active runners:**
   ```bash
   bash list-active-runners.sh
   # View all running runners and their status.
   ```

3. **Stop all runners:**
   ```bash
   bash kill-all-runners.sh
   # Safely stop all runner processes.
   ```

4. **Set up a new runner manually (if needed):**
   ```bash
   cd actions-runner-your-repo
   bash setup-runner.sh
   bash run.sh
   ```

---

## Notes
- All scripts are designed for use in WSL2/Ubuntu environments.
- Ensure you have appropriate permissions to install packages and manage processes.
- Logs for each runner are written to `run.log` in the respective runner directory.
- If you encounter permission issues, check directory ownership and permissions for the runner user.

---

## Troubleshooting
- If a runner fails to start, check its `run.log` for errors.
- If dependencies are missing, re-run `setup-runner.sh` in the affected directory.
- If you see orphaned Node.js or Playwright processes, use `kill-all-runners.sh` to clean them up.

---

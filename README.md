# GitHub Actions Runner Fleet Management System

A comprehensive, modular system for managing multiple self-hosted GitHub Actions runners with automated setup, monitoring, and maintenance capabilities.

## 🚀 Features

- **Interactive Menu System** - Easy-to-use interface with 15 management options
- **Mass Configuration** - Set up multiple runners automatically with intelligent naming
- **Real-time Monitoring** - Live status updates and health monitoring
- **Advanced Cleanup** - Granular cleanup options for logs, processes, and temporary files
- **Dependency Management** - Automated installation and checking of system dependencies
- **Modular Architecture** - Clean, maintainable code structure with focused libraries

## 📁 Project Structure

### Main Scripts
- **`runner-manager.sh`** - Main interactive management system
- **`setup-runner-no-sudo.sh`** - Individual runner setup script (no sudo required)

### Modular Libraries (`lib/` directory)
- **`colors.sh`** - Color definitions and output formatting
- **`github.sh`** - GitHub API interactions and repository parsing
- **`download.sh`** - GitHub Actions runner download and verification
- **`setup.sh`** - Runner setup and configuration functions
- **`monitor.sh`** - Runner monitoring and status functions
- **`dependencies.sh`** - System dependency management
- **`cleanup.sh`** - Cleanup and maintenance functions

## 🛠️ Quick Start

### Prerequisites
- Linux/WSL2/Ubuntu system
- Internet connection for downloading runners
- Basic system tools (curl, wget, tar)

### Getting Started

1. **Clone or download this repository**
   ```bash
   git clone https://github.com/turbolego/actions-runner-fleet.git
   cd actions-runner-fleet
   ```

2. **Make the main script executable**
   ```bash
   chmod +x runner-manager.sh
   ```

3. **Run the interactive manager**
   ```bash
   ./runner-manager.sh
   ```

4. **Follow the menu prompts:**
   - First, install dependencies (option 9)
   - Then mass configure new runners (option 1)
   - Start all runners (option 2)
   - Monitor status (option 4 or 5)

## 📋 Menu Options

### 🚀 Runner Management
1. **Mass Configure New Runners** - Set up multiple runners with automated naming
2. **Start All Existing Runners** - Start all configured runners in background
3. **Terminate All Runners** - Safely stop all running processes

### 📊 Monitoring & Status
4. **Show Runner Status** - One-time status display of all runners
5. **Monitor Runners** - Real-time continuous monitoring (press 'q' + Enter to return)
6. **View Runner Logs** - Browse and analyze runner log files
7. **Check System Health** - Disk space, memory, load average analysis

### ⚙️ System Management
8. **Check Dependencies** - Verify required system packages
9. **Install Missing Dependencies** - Automated dependency installation
10. **Setup Python Environment** - Create shared Python virtual environment

### 🧹 Cleanup & Maintenance
11. **Remove Specific Runners** - Selectively remove runners
12. **Cleanup Orphaned Processes** - Remove stuck GitHub Actions processes
13. **Cleanup Log Files** - Manage and clean runner log files
14. **Cleanup Temporary Files** - Remove temporary and work directories

## 🔧 Advanced Usage

### Mass Configuration
The system supports intelligent mass configuration:
- Automatically names runners as `{owner}_{repo}-{number}`
- Downloads latest GitHub Actions runner automatically
- Configures runners with Playwright labels
- Handles existing runners with replacement options

### Monitoring Features
- **Real-time Status** - Live updates every 30 seconds (press 'q' + Enter to exit)
- **Process Tracking** - Monitor run.sh processes and related activities
- **Log Analysis** - View recent activity and detailed logs
- **Health Checks** - System resource monitoring

### Dependency Management
Supports multiple Linux distributions:
- **Ubuntu/Debian** - apt-get based installation
- **CentOS/RHEL/Fedora** - yum/dnf based installation
- **SUSE/openSUSE** - zypper based installation
- **macOS** - Homebrew based installation

## 📝 Configuration Examples

### Setting up 5 runners for a repository
1. Run `./runner-manager.sh`
2. Select option 1 (Mass Configure New Runners)
3. Enter: `5` (number of runners)
4. Enter: `https://github.com/your-org/your-repo`
5. Enter your GitHub runner token
6. Wait for automatic setup completion

### Monitoring runner status
```bash
./runner-manager.sh
# Select option 4 for one-time status
# Or option 5 for real-time monitoring
```

## 🔍 Troubleshooting

### Common Issues

**Missing Dependencies**
```bash
./runner-manager.sh
# Select option 8 to check dependencies
# Select option 9 to install missing packages
```

**Runners Not Starting**
- Check logs with option 6 (View Runner Logs)
- Verify system health with option 7
- Ensure proper GitHub token permissions

**Orphaned Processes**
- Use option 12 (Cleanup Orphaned Processes)
- Check system processes with option 7

**Storage Issues**
- Use option 13 (Cleanup Log Files) for large logs
- Use option 14 (Cleanup Temporary Files) for _work directories
- Check system health with option 7 for disk usage

### Log Locations
- Runner logs: `{runner-directory}/run.log`
- Setup logs: Written to console during configuration
- System logs: Available through monitoring options

## 🏗️ Architecture Benefits

### Modular Design
- **Maintainability** - Each module has a single responsibility
- **Extensibility** - Easy to add new features without touching existing code
- **Reusability** - Functions can be used across different modules
- **Testing** - Individual modules can be tested independently

### Enhanced Features vs. Previous Version
- **15 menu options** vs. 7 in the old monolithic version
- **52KB of functionality** vs. 28KB in the old version
- **Advanced log management** - View, analyze, and cleanup capabilities
- **System health monitoring** - Comprehensive system analysis
- **Granular cleanup options** - Targeted maintenance operations
- **Python environment setup** - Automated virtual environment creation

## 🔒 Security Notes

- Scripts avoid sudo requirements where possible
- Token input is clearly marked as visible on screen
- No tokens are stored or logged
- Runners are configured with `--replace` to avoid conflicts
- Process cleanup is selective and safe

## 🤝 Contributing

This project uses a modular architecture making it easy to contribute:
- Add new features by creating focused library modules
- Extend existing functionality within the appropriate lib/ file
- Update the main menu system in `runner-manager.sh`
- All modules follow consistent patterns and error handling

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

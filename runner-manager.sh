#!/bin/bash
# runner-manager.sh - Interactive GitHub Actions Runner Management System
# Modular design with separate libraries for better maintainability

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source modular libraries
source "$BASE_DIR/lib/colors.sh"
source "$BASE_DIR/lib/github.sh"
source "$BASE_DIR/lib/download.sh"
source "$BASE_DIR/lib/setup.sh"
source "$BASE_DIR/lib/monitor.sh"
source "$BASE_DIR/lib/dependencies.sh"
source "$BASE_DIR/lib/cleanup.sh"

# Function to show main menu
show_menu() {
    clear
    print_color $BLUE "====================================="
    print_color $BLUE "  GitHub Actions Runner Manager"
    print_color $BLUE "      Modular Fleet Management"
    print_color $BLUE "====================================="
    echo
    print_color $GREEN "🚀 RUNNER MANAGEMENT"
    print_color $GREEN "1. Mass Configure New Runners"
    print_color $GREEN "2. Start All Existing Runners"
    print_color $GREEN "3. Terminate All Runners"
    echo
    print_color $BLUE "📊 MONITORING & STATUS"
    print_color $BLUE "4. Show Runner Status (One-time)"
    print_color $BLUE "5. Monitor Runners (Real-time)"
    print_color $BLUE "6. View Runner Logs"
    print_color $BLUE "7. Check System Health"
    echo
    print_color $YELLOW "⚙️  SYSTEM MANAGEMENT"
    print_color $YELLOW "8. Check Dependencies"
    print_color $YELLOW "9. Install Missing Dependencies"
    print_color $YELLOW "10. Setup Python Environment"
    echo
    print_color $RED "🧹 CLEANUP & MAINTENANCE"
    print_color $RED "11. Remove Specific Runners"
    print_color $RED "12. Cleanup Orphaned Processes"
    print_color $RED "13. Cleanup Log Files"
    print_color $RED "14. Cleanup Temporary Files"
    echo
    print_color $GREEN "15. Exit"
    echo
    print_color $YELLOW "Enter your choice (1-15): "
}

# Function to check if libraries are available
check_libraries() {
    local missing_libs=()
    
    # Check each library file
    local lib_files=("colors.sh" "github.sh" "download.sh" "setup.sh" "monitor.sh" "dependencies.sh" "cleanup.sh")
    
    for lib in "${lib_files[@]}"; do
        if [ ! -f "$BASE_DIR/lib/$lib" ]; then
            missing_libs+=("$lib")
        fi
    done
    
    if [ ${#missing_libs[@]} -gt 0 ]; then
        print_color $RED "Error: Missing library files:"
        for lib in "${missing_libs[@]}"; do
            print_color $RED "  - lib/$lib"
        done
        print_color $YELLOW "Please ensure all library files are present in the lib/ directory."
        exit 1
    fi
}

# Function to check basic dependencies
check_basic_dependencies() {
    local missing_deps=()
    
    # Check for absolutely required commands
    local required_commands=("curl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_color $RED "Error: Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            print_color $RED "  - $dep"
        done
        print_color $YELLOW "Please install missing dependencies first (option 9 in menu)."
        print_color $YELLOW "Or install manually:"
        print_color $BLUE "  Ubuntu/Debian: sudo apt-get install curl jq"
        print_color $BLUE "  CentOS/RHEL:   sudo yum install curl jq"
        print_color $BLUE "  macOS:         brew install curl jq"
        echo
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ "$continue_anyway" != [yY] ]]; then
            exit 1
        fi
    fi
}

# Main program loop
main() {
    # Check if libraries are available
    check_libraries
    
    # Check basic dependencies
    check_basic_dependencies
    
    # Welcome message
    print_color $GREEN "GitHub Actions Runner Manager loaded successfully!"
    print_color $BLUE "Modular libraries initialized."
    echo
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                mass_configure_runners
                ;;
            2)
                start_all_runners
                ;;
            3)
                terminate_runners
                ;;
            4)
                show_runner_status
                ;;
            5)
                monitor_runners
                ;;
            6)
                view_logs
                ;;
            7)
                check_system_health
                ;;
            8)
                check_dependencies
                ;;
            9)
                install_dependencies
                ;;
            10)
                setup_python_environment
                ;;
            11)
                remove_specific_runners
                ;;
            12)
                cleanup_orphaned_processes
                ;;
            13)
                cleanup_log_files
                ;;
            14)
                cleanup_temp_files
                ;;
            15)
                print_color $GREEN "Thanks for using GitHub Actions Runner Manager!"
                print_color $BLUE "All runners remain active in the background."
                exit 0
                ;;
            *)
                print_color $RED "Invalid choice. Please enter 1-15."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Run main program
main "$@"

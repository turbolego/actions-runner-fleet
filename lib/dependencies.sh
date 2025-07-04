#!/bin/bash
# dependencies.sh - System dependency management functions

# Function to install missing dependencies with sudo
install_dependencies() {
    print_color $BLUE "=== Installing System Dependencies ==="
    
    # Check if we're running as root
    if [ "$EUID" -eq 0 ]; then
        print_color $YELLOW "Warning: Running as root. Some operations may behave differently."
    fi
    
    # Detect the operating system
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    print_color $BLUE "Detected OS: $OS $VER"
    
    # Install dependencies based on the operating system
    case "$OS" in
        *Ubuntu*|*Debian*)
            print_color $BLUE "Installing dependencies for Ubuntu/Debian..."
            
            # Update package list
            print_color $YELLOW "Updating package list..."
            sudo apt-get update
            
            # Install required packages
            print_color $YELLOW "Installing required packages..."
            sudo apt-get install -y \
                curl \
                wget \
                tar \
                gzip \
                git \
                jq \
                python3 \
                python3-pip \
                python3-venv \
                nodejs \
                npm \
                build-essential \
                libssl-dev \
                libffi-dev \
                python3-dev
            
            # Install dos2unix if available
            sudo apt-get install -y dos2unix 2>/dev/null || print_color $YELLOW "dos2unix not available, using alternative method for line endings"
            ;;
            
        *CentOS*|*Red\ Hat*|*Fedora*|*Rocky*|*AlmaLinux*)
            print_color $BLUE "Installing dependencies for RHEL/CentOS/Fedora..."
            
            # Determine package manager
            if command -v dnf >/dev/null 2>&1; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            print_color $YELLOW "Using package manager: $PKG_MGR"
            
            # Install EPEL repository if needed (for CentOS/RHEL)
            if [[ "$OS" == *CentOS* ]] || [[ "$OS" == *Red\ Hat* ]]; then
                print_color $YELLOW "Installing EPEL repository..."
                sudo $PKG_MGR install -y epel-release 2>/dev/null || true
            fi
            
            # Install required packages
            print_color $YELLOW "Installing required packages..."
            sudo $PKG_MGR install -y \
                curl \
                wget \
                tar \
                gzip \
                git \
                jq \
                python3 \
                python3-pip \
                nodejs \
                npm \
                gcc \
                gcc-c++ \
                make \
                openssl-devel \
                libffi-devel \
                python3-devel
            
            # Install dos2unix if available
            sudo $PKG_MGR install -y dos2unix 2>/dev/null || print_color $YELLOW "dos2unix not available, using alternative method for line endings"
            ;;
            
        *SUSE*|*openSUSE*)
            print_color $BLUE "Installing dependencies for SUSE/openSUSE..."
            
            # Update package list
            print_color $YELLOW "Updating package list..."
            sudo zypper refresh
            
            # Install required packages
            print_color $YELLOW "Installing required packages..."
            sudo zypper install -y \
                curl \
                wget \
                tar \
                gzip \
                git \
                jq \
                python3 \
                python3-pip \
                nodejs \
                npm \
                gcc \
                gcc-c++ \
                make \
                libopenssl-devel \
                libffi-devel \
                python3-devel
            
            # Install dos2unix if available
            sudo zypper install -y dos2unix 2>/dev/null || print_color $YELLOW "dos2unix not available, using alternative method for line endings"
            ;;
            
        *macOS*|*Darwin*)
            print_color $BLUE "Installing dependencies for macOS..."
            
            # Check if Homebrew is installed
            if ! command -v brew >/dev/null 2>&1; then
                print_color $YELLOW "Homebrew not found. Please install Homebrew first:"
                print_color $BLUE "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                return 1
            fi
            
            # Update Homebrew
            print_color $YELLOW "Updating Homebrew..."
            brew update
            
            # Install required packages
            print_color $YELLOW "Installing required packages..."
            brew install \
                curl \
                wget \
                git \
                jq \
                python3 \
                node \
                dos2unix
            ;;
            
        *)
            print_color $YELLOW "Unknown operating system: $OS"
            print_color $BLUE "Please install the following packages manually:"
            print_color $BLUE "  - curl, wget, tar, gzip, git, jq"
            print_color $BLUE "  - python3, python3-pip, python3-venv"
            print_color $BLUE "  - nodejs, npm"
            print_color $BLUE "  - build tools (gcc, make, etc.)"
            read -p "Press Enter to continue with the assumption that dependencies are installed..."
            return 0
            ;;
    esac
    
    # Check if installation was successful
    print_color $BLUE "Verifying installation..."
    
    local missing_deps=()
    
    # Check for required commands
    local required_commands=("curl" "wget" "tar" "git" "jq" "python3" "node" "npm")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check Python venv module
    if ! python3 -c "import venv" 2>/dev/null; then
        missing_deps+=("python3-venv")
    fi
    
    # Report results
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_color $GREEN "✓ All required dependencies are installed"
        
        # Show versions
        print_color $BLUE "Installed versions:"
        echo "  Python: $(python3 --version 2>/dev/null || echo 'Not found')"
        echo "  Node.js: $(node --version 2>/dev/null || echo 'Not found')"
        echo "  npm: $(npm --version 2>/dev/null || echo 'Not found')"
        echo "  Git: $(git --version 2>/dev/null || echo 'Not found')"
        echo "  jq: $(jq --version 2>/dev/null || echo 'Not found')"
        echo "  curl: $(curl --version 2>/dev/null | head -1 || echo 'Not found')"
        
    else
        print_color $RED "✗ Missing dependencies detected:"
        for dep in "${missing_deps[@]}"; do
            print_color $RED "  - $dep"
        done
        print_color $YELLOW "Please install missing dependencies manually or try running this script again."
        return 1
    fi
    
    print_color $GREEN "Dependency installation completed successfully!"
    return 0
}

# Function to check dependencies without installing
check_dependencies() {
    print_color $BLUE "=== Checking System Dependencies ==="
    
    local missing_deps=()
    local optional_deps=()
    
    # Required commands
    local required_commands=("curl" "wget" "tar" "git" "jq" "python3" "node" "npm")
    
    print_color $BLUE "Checking required dependencies..."
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local version=""
            case "$cmd" in
                python3) version="$(python3 --version 2>/dev/null | cut -d' ' -f2)" ;;
                node) version="$(node --version 2>/dev/null)" ;;
                npm) version="$(npm --version 2>/dev/null)" ;;
                git) version="$(git --version 2>/dev/null | cut -d' ' -f3)" ;;
                jq) version="$(jq --version 2>/dev/null | cut -d'-' -f2)" ;;
                curl) version="$(curl --version 2>/dev/null | head -1 | cut -d' ' -f2)" ;;
                wget) version="$(wget --version 2>/dev/null | head -1 | cut -d' ' -f3)" ;;
                tar) version="$(tar --version 2>/dev/null | head -1 | cut -d' ' -f4)" ;;
            esac
            print_color $GREEN "  ✓ $cmd${version:+ ($version)}"
        else
            missing_deps+=("$cmd")
            print_color $RED "  ✗ $cmd"
        fi
    done
    
    # Check Python venv module
    if python3 -c "import venv" 2>/dev/null; then
        print_color $GREEN "  ✓ python3-venv module"
    else
        missing_deps+=("python3-venv")
        print_color $RED "  ✗ python3-venv module"
    fi
    
    # Check optional dependencies
    print_color $BLUE "Checking optional dependencies..."
    
    local optional_commands=("dos2unix" "less" "file")
    
    for cmd in "${optional_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            print_color $GREEN "  ✓ $cmd (optional)"
        else
            optional_deps+=("$cmd")
            print_color $YELLOW "  - $cmd (optional, not required)"
        fi
    done
    
    # Summary
    echo
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_color $GREEN "✓ All required dependencies are available"
        if [ ${#optional_deps[@]} -gt 0 ]; then
            print_color $BLUE "Optional dependencies missing: ${optional_deps[*]}"
            print_color $BLUE "These are not required but may provide enhanced functionality."
        fi
        return 0
    else
        print_color $RED "✗ Missing required dependencies: ${missing_deps[*]}"
        print_color $YELLOW "Run the 'Install Dependencies' option from the main menu to install them."
        return 1
    fi
}

# Function to create Python virtual environment for runners
setup_python_environment() {
    print_color $BLUE "=== Setting Up Python Environment ==="
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        print_color $RED "Error: Python 3 is not installed"
        print_color $YELLOW "Please install Python 3 first using the dependency installation option."
        return 1
    fi
    
    # Check if venv module is available
    if ! python3 -c "import venv" 2>/dev/null; then
        print_color $RED "Error: Python venv module is not available"
        print_color $YELLOW "Please install python3-venv package using the dependency installation option."
        return 1
    fi
    
    # Create global Python environment for runners
    local venv_dir="$BASE_DIR/python-env"
    
    if [ -d "$venv_dir" ]; then
        print_color $YELLOW "Python environment already exists at $venv_dir"
        read -p "Do you want to recreate it? (y/N): " recreate
        
        if [[ "$recreate" == [yY] ]]; then
            print_color $BLUE "Removing existing Python environment..."
            rm -rf "$venv_dir"
        else
            print_color $BLUE "Using existing Python environment"
            return 0
        fi
    fi
    
    # Create virtual environment
    print_color $BLUE "Creating Python virtual environment..."
    python3 -m venv "$venv_dir"
    
    if [ $? -ne 0 ]; then
        print_color $RED "Failed to create Python virtual environment"
        return 1
    fi
    
    # Activate virtual environment and install common packages
    print_color $BLUE "Installing common Python packages..."
    source "$venv_dir/bin/activate"
    
    # Upgrade pip first
    pip install --upgrade pip
    
    # Install common packages for GitHub Actions
    pip install \
        requests \
        pyyaml \
        jinja2 \
        pytest \
        flake8 \
        black \
        coverage
    
    deactivate
    
    print_color $GREEN "Python environment setup completed at $venv_dir"
    print_color $BLUE "Runners can use this environment by sourcing: $venv_dir/bin/activate"
    
    return 0
}

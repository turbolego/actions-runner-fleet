#!/bin/bash
# setup-runner-no-sudo.sh - Simple runner setup without sudo requirements
# This script sets up basic dependencies for GitHub Actions self-hosted runners without requiring sudo

set -e

echo "Setting up self-hosted runner dependencies (no sudo)..."

# Check if we're running as root
if [ "$EUID" -eq 0 ]; then
    echo "Warning: Running as root. Consider running as a regular user."
fi

# Check Python3
echo "Checking Python3..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "✓ Python3 is available: $PYTHON_VERSION"
    
    # Check if python3-venv is available
    if python3 -c "import venv" 2>/dev/null; then
        echo "✓ Python3 venv module is available"
        
        # Test if we can actually create a venv (this catches the python3.x-venv package issue)
        echo "Testing virtual environment creation..."
        test_venv_dir="/tmp/test_venv_$$"
        if python3 -m venv "$test_venv_dir" >/dev/null 2>&1; then
            echo "✓ Virtual environment creation works"
            rm -rf "$test_venv_dir" 2>/dev/null
        else
            echo "✗ Virtual environment creation failed"
            echo "⚠ This usually means python3-venv or python3.x-venv package is missing"
            
            # Detect Python version for specific package recommendation
            python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            if [ -n "$python_version" ]; then
                echo "🔧 Manual installation needed: sudo apt-get install -y python${python_version}-venv"
            else
                echo "🔧 Manual installation needed: sudo apt-get install -y python3-venv"
            fi
            rm -rf "$test_venv_dir" 2>/dev/null
        fi
    else
        echo "⚠ Warning: Python3 venv not available. Some workflows may not work."
        echo "🔧 Manual installation needed: sudo apt-get install -y python3-venv"
    fi
else
    echo "⚠ Warning: Python3 not found. Some workflows may not work."
fi

# Check Node.js
echo "Checking Node.js..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo "✓ Node.js is available: $NODE_VERSION"
    
    # Check npm
    if command -v npm >/dev/null 2>&1; then
        NPM_VERSION=$(npm --version)
        echo "✓ npm is available: $NPM_VERSION"
    else
        echo "⚠ Warning: npm not found"
    fi
else
    echo "⚠ Warning: Node.js not found. JavaScript workflows may not work."
    echo "  Consider installing Node.js manually or ask your system administrator."
fi

# Check basic tools
echo "Checking basic tools..."
for tool in git curl wget jq; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✓ $tool is available"
    else
        echo "⚠ $tool not found"
    fi
done

# Check Docker (optional but useful for some workflows)
echo "Checking Docker..."
if command -v docker >/dev/null 2>&1; then
    if docker --version >/dev/null 2>&1; then
        echo "✓ Docker is available: $(docker --version)"
    else
        echo "⚠ Docker command found but not working (may need permissions)"
    fi
else
    echo "⚠ Docker not found (optional - some workflows may need it)"
fi

# Check if we can create directories and files
echo "Testing write permissions..."
TEST_DIR="/tmp/runner-test-$$"
if mkdir -p "$TEST_DIR" && touch "$TEST_DIR/test-file" && rm -rf "$TEST_DIR"; then
    echo "✓ Write permissions OK"
else
    echo "✗ Write permission test failed"
fi

# Create common directories that runners might need
echo "Creating runner directories..."
mkdir -p ~/.npm ~/.cache ~/.local/bin
echo "✓ Runner directories created"

echo ""
echo "🎉 Basic dependency check complete!"
echo ""
echo "✅ Summary:"
echo "  - Basic tools checked"
echo "  - Write permissions verified"
echo "  - Runner directories created"
echo ""
echo "📝 Note: This setup doesn't install packages via sudo."
echo "   Most GitHub Actions should work with the current setup."
echo "   If you need additional dependencies, install them manually."
echo ""

#!/bin/bash

# Setup script for self-hosted GitHub Actions runner
# Run this script once on your runner to install required dependencies

echo "Setting up self-hosted runner dependencies..."

# Update package list
echo "Updating package list..."
sudo apt-get update

# Install Python3 and venv if not available
echo "Installing Python3 and venv..."
if ! python3 -m venv --help >/dev/null 2>&1; then
    echo "Installing python3-venv..."
    sudo apt-get install -y python3-venv python3-pip
else
    echo "Python3 venv is already available"
fi

# Install jq if not available
echo "Installing jq..."
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    sudo apt-get install -y jq
else
    echo "jq is already available"
fi

# Install Node.js if not available (though GitHub Actions should handle this)
echo "Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already available: $(node --version)"
fi

# Install additional dependencies that might be needed for Playwright
echo "Installing additional dependencies for Playwright..."
sudo apt-get install -y \
    libnss3-dev \
    libatk-bridge2.0-dev \
    libdrm-dev \
    libxcomposite-dev \
    libxdamage-dev \
    libxrandr-dev \
    libgbm-dev \
    libgtk-3-dev \
    libasound2-dev

# Set up permissions for the runner user (optional)
echo "Setting up runner permissions..."
RUNNER_USER=$(whoami)
echo "Current runner user: $RUNNER_USER"

# Create necessary directories with proper permissions
mkdir -p ~/.npm
mkdir -p ~/.cache/ms-playwright

# Install Playwright browsers if Playwright is installed
if npx playwright --version &>/dev/null; then
    echo "Installing Playwright browsers..."
    npx playwright install
else
    echo "Playwright is not installed. You may want to run: npm install -D playwright"
fi

echo "Setup complete!"
echo ""
echo "Dependencies installed:"
echo "- Python3 with venv: $(python3 --version)"
echo "- jq: $(jq --version)"
echo "- Node.js: $(node --version)"
echo "- npm: $(npm --version)"
echo ""
echo "Your self-hosted runner should now be able to run the workflow without requiring sudo passwords."
echo ""
echo "Note: If you still encounter permission issues with specific directories,"
echo "you may need to ensure the runner user has appropriate permissions to those directories."

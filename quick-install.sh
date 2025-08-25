#!/bin/bash

# Quick Install Script for Conduit
# Can be run directly from curl/wget

set -euo pipefail

# Configuration
REPO_URL="https://github.com/yourusername/conduit"
INSTALL_DIR="${HOME}/.conduit"
BIN_DIR="${HOME}/.local/bin"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================"
echo "     Conduit Quick Installer"
echo "================================================"
echo ""

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is required but not installed${NC}"
    echo "Please install git first:"
    echo "  Ubuntu/Debian: sudo apt-get install git"
    echo "  macOS: brew install git"
    exit 1
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo "Cloning Conduit repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Make installer executable
chmod +x install.sh

# Run installer
echo ""
echo "Starting installation..."
echo ""
./install.sh --standard

echo ""
echo -e "${GREEN}Quick installation complete!${NC}"
echo ""
echo "To get started:"
echo "  1. Restart your terminal or run: source ~/.bashrc"
echo "  2. Configure your API key"
echo "  3. Run: conduit"
#!/bin/bash

# Update Script for Conduit
# Updates Conduit to the latest version

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Version files
CURRENT_VERSION_FILE="$SCRIPT_DIR/VERSION"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/yourusername/conduit/main/VERSION"

echo "================================================"
echo "     Conduit Update Checker"
echo "================================================"
echo ""

# Get current version
if [ -f "$CURRENT_VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
else
    CURRENT_VERSION="unknown"
fi

echo "Current version: $CURRENT_VERSION"

# Check for git repository
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "Detected git repository. Updating via git..."
    
    # Save any local changes
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}Warning: You have local changes${NC}"
        read -p "Stash local changes and continue? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
            echo "Local changes stashed"
        else
            echo "Update cancelled"
            exit 0
        fi
    fi
    
    # Fetch and pull latest changes
    echo "Fetching latest changes..."
    git fetch origin
    
    # Check if update is needed
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo -e "${GREEN}✓ Already up to date!${NC}"
        exit 0
    fi
    
    # Pull changes
    echo "Pulling latest version..."
    git pull origin main
    
    # Check new version
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        NEW_VERSION=$(cat "$CURRENT_VERSION_FILE")
        echo -e "${GREEN}✓ Updated to version $NEW_VERSION${NC}"
    fi
    
    # Re-apply stashed changes if any
    if git stash list | grep -q "Auto-stash before update"; then
        echo "Re-applying local changes..."
        git stash pop || echo -e "${YELLOW}Could not re-apply local changes. Run 'git stash pop' manually${NC}"
    fi
    
else
    # Non-git installation - download latest
    echo "Checking for updates..."
    
    # Try to get remote version
    if command -v curl &> /dev/null; then
        REMOTE_VERSION=$(curl -s "$REMOTE_VERSION_URL" 2>/dev/null || echo "unknown")
    elif command -v wget &> /dev/null; then
        REMOTE_VERSION=$(wget -qO- "$REMOTE_VERSION_URL" 2>/dev/null || echo "unknown")
    else
        echo -e "${RED}Error: curl or wget required to check for updates${NC}"
        exit 1
    fi
    
    if [ "$REMOTE_VERSION" = "unknown" ]; then
        echo -e "${RED}Could not check remote version${NC}"
        exit 1
    fi
    
    echo "Latest version: $REMOTE_VERSION"
    
    # Compare versions
    if [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        echo -e "${GREEN}✓ Already up to date!${NC}"
        exit 0
    fi
    
    # Download update
    echo "Downloading update..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    if command -v curl &> /dev/null; then
        curl -L "https://github.com/yourusername/conduit/archive/main.tar.gz" -o "$TEMP_DIR/conduit.tar.gz"
    else
        wget "https://github.com/yourusername/conduit/archive/main.tar.gz" -O "$TEMP_DIR/conduit.tar.gz"
    fi
    
    # Extract and update
    echo "Installing update..."
    tar -xzf "$TEMP_DIR/conduit.tar.gz" -C "$TEMP_DIR"
    
    # Backup current installation
    BACKUP_DIR="$SCRIPT_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup at $BACKUP_DIR"
    cp -r "$SCRIPT_DIR" "$BACKUP_DIR"
    
    # Copy new files
    cp -r "$TEMP_DIR/conduit-main/"* "$SCRIPT_DIR/"
    
    echo -e "${GREEN}✓ Updated to version $REMOTE_VERSION${NC}"
fi

# Make scripts executable
echo "Setting permissions..."
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Show changelog
if [ -f "$SCRIPT_DIR/CHANGELOG.md" ]; then
    echo ""
    echo "Recent changes:"
    echo "---------------"
    head -n 20 "$SCRIPT_DIR/CHANGELOG.md" | grep -A 10 "^## \[.*\]" | head -15
fi

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo ""
echo "Please restart any running Conduit instances to use the new version."

# Check if reinstall is needed
read -p "Run installer to update dependencies? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec "$SCRIPT_DIR/install.sh"
fi
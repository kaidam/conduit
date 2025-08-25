#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Error handler
error_exit() {
    local line_no=$1
    local exit_code=$2
    echo "=========================================="
    echo "ERROR: Installation failed"
    echo "Line: $line_no, Exit code: $exit_code"
    echo "=========================================="
    echo "Please check the error messages above."
    echo "You may need to:"
    echo "  1. Run with sudo if permission denied"
    echo "  2. Check your internet connection"
    echo "  3. Verify system requirements"
    echo "=========================================="
    exit $exit_code
}

# Set up error trap
trap 'error_exit $LINENO $?' ERR

# Cleanup function for installation
cleanup_install() {
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "=========================================="
        echo "✓ Installation completed successfully!"
        echo "=========================================="
    else
        echo "=========================================="
        echo "✗ Installation failed with exit code: $exit_code"
        echo "=========================================="
    fi
}

# Set up cleanup trap
trap cleanup_install EXIT

# OS Detection and Compatibility Check
check_os_compatibility() {
    local os_type="$OSTYPE"
    local kernel_name="$(uname -s)"
    
    # Check if running on Linux
    if [[ "$os_type" != "linux-gnu"* ]] && [[ "$kernel_name" != "Linux" ]]; then
        echo "=========================================="
        echo "ERROR: Operating System Not Supported"
        echo "=========================================="
        echo "This tool is designed for Linux systems only."
        echo ""
        echo "Detected OS: $os_type"
        echo "Kernel: $kernel_name"
        echo ""
        echo "Supported systems:"
        echo "  - Ubuntu (20.04+)"
        echo "  - Linux Mint (20+)"
        echo "  - Debian (10+)"
        echo "  - Other apt-based Linux distributions"
        echo ""
        echo "For macOS support, please check the project's"
        echo "GitHub repository for alternative versions."
        echo "=========================================="
        exit 1
    fi
    
    # Check for required package manager
    if ! command -v apt-get &> /dev/null; then
        echo "=========================================="
        echo "ERROR: Package Manager Not Found"
        echo "=========================================="
        echo "This installer requires apt-get package manager."
        echo "Your Linux distribution may not be supported."
        echo ""
        echo "Please install dependencies manually:"
        echo "  - sox"
        echo "  - curl"
        echo "  - jq"
        echo "  - xdotool"
        echo "  - yad"
        echo "  - xclip"
        echo "=========================================="
        exit 1
    fi
    
    echo "✓ Operating system check passed: Linux detected"
}

# Get the directory where conduit.sh is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Installation script
install_dependencies() {
    echo "Installing required dependencies..."
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        echo "This installer requires sudo access to install system packages."
        echo "Please enter your password when prompted."
    fi
    
    # Update package list with timeout
    echo "Updating package list..."
    if ! sudo timeout 60 apt-get update; then
        echo "Warning: Failed to update package list. Continuing with cached data..."
    fi
    
    # Install dependencies with error handling
    local packages=("sox" "curl" "jq" "xdotool" "yad" "xclip")
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        echo "Installing $package..."
        if ! sudo apt-get install -y "$package"; then
            failed_packages+=("$package")
            echo "Warning: Failed to install $package"
        fi
    done
    
    # Check if any critical packages failed
    if [ ${#failed_packages[@]} -gt 0 ]; then
        echo "=========================================="
        echo "WARNING: Some packages failed to install:"
        printf '%s\n' "${failed_packages[@]}"
        echo "You may need to install them manually."
        echo "=========================================="
        
        # Check if critical packages are missing
        for critical in "sox" "curl" "jq"; do
            if [[ " ${failed_packages[@]} " =~ " ${critical} " ]]; then
                echo "Error: Critical package '$critical' is required"
                return 1
            fi
        done
    fi
    
    # Create directory for scripts
    mkdir -p ~/.local/bin/speech-tools
    
    # Create symlink to transcribe.sh instead of copying
    echo "Creating symlink to transcribe.sh in ~/.local/bin/speech-tools/"
    ln -sf "${SCRIPT_DIR}/transcribe.sh" ~/.local/bin/speech-tools/transcribe.sh
    
    # Make original script executable
    chmod +x "${SCRIPT_DIR}/transcribe.sh"
    
    # Add to PATH if not already present
    if ! grep -q "speech-tools" ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/.local/bin/speech-tools"' >> ~/.bashrc
    fi
    
    # Handle .env file setup with enhanced security
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
        else
            cat > "${SCRIPT_DIR}/.env" << 'EOF'
# Groq API Configuration
# IMPORTANT: Keep this file secure and never commit it to version control
GROQ_API_KEY=your_api_key_here

# Security Notes:
# - Your API key should start with 'gsk_' followed by 52 alphanumeric characters
# - This file has restricted permissions (600) for security
# - Never share your API key or commit it to git
# - If you suspect your key is compromised, regenerate it immediately at https://console.groq.com/
EOF
        fi
        
        # Set secure permissions
        chmod 600 "${SCRIPT_DIR}/.env"
        
        echo "=========================================="
        echo "SECURITY: API Key Configuration Required"
        echo "=========================================="
        echo "Created .env file with secure permissions (600)"
        echo ""
        echo "To complete setup:"
        echo "1. Get your API key from: https://console.groq.com/"
        echo "2. Edit: ${SCRIPT_DIR}/.env"
        echo "3. Replace 'your_api_key_here' with your actual key"
        echo ""
        echo "Your API key should look like: gsk_XXXXXXXX..."
        echo "=========================================="
        
        # Prompt to open editor
        read -p "Would you like to edit the .env file now? (y/n): " edit_now
        if [[ $edit_now =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "${SCRIPT_DIR}/.env"
        fi
    else
        # Check existing file permissions
        local perms=$(stat -c %a "${SCRIPT_DIR}/.env" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            echo "Fixing .env file permissions for security..."
            chmod 600 "${SCRIPT_DIR}/.env"
        fi
        echo "✓ Existing .env file found and preserved"
    fi
    
    # Create symlink to .env file in speech-tools directory
    ln -sf "${SCRIPT_DIR}/.env" ~/.local/bin/speech-tools/.env
}

# Setup keyboard shortcuts
setup_shortcuts() {
    echo "----------------------------------------"
    echo "Shortcut Setup"
    echo "Would you like to:"
    echo "1) Set up default keyboard shortcut (Shift+Super+T)"
    echo "2) Set up a touchpad gesture"
    echo "3) Open System Settings to set up manually"
    echo "4) Skip shortcut setup"
    echo "----------------------------------------"
    echo "Pro tip: You can also use Shift+Ctrl+Print (or Shift+Ctrl+Fn+F12) for screenshots in Cursor"
    echo "----------------------------------------"
    read -p "Enter your choice (1-4): " choice
    
    # Detect desktop environment
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        DE="gnome"
    elif [ "$XDG_CURRENT_DESKTOP" = "X-Cinnamon" ] || [ "$XDG_CURRENT_DESKTOP" = "CINNAMON" ]; then
        DE="cinnamon"
    else
        DE="unknown"
    fi
    
    case $choice in
        1)
            if ! command -v gsettings &> /dev/null; then
                echo "gsettings not found. Please set up shortcuts manually through System Settings."
                return 1
            fi
            
            if [ "$DE" = "gnome" ]; then
                # GNOME shortcut setup
                gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/']"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ name "Speech Transcription"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ command "$HOME/.local/bin/speech-tools/transcribe.sh"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ binding "<Shift><Super>t"
            elif [ "$DE" = "cinnamon" ]; then
                # Cinnamon shortcut setup (existing code)
                local CURRENT_LIST=$(gsettings get org.cinnamon.desktop.keybindings custom-list)
                if [ "$CURRENT_LIST" = "@as []" ]; then
                    gsettings set org.cinnamon.desktop.keybindings custom-list "['speech']"
                else
                    CURRENT_LIST=${CURRENT_LIST//[\[\]\'\"]/}
                    if [[ ! $CURRENT_LIST =~ "speech" ]]; then
                        NEW_LIST="[$(echo "'$CURRENT_LIST'" | sed "s/,/, /g")${CURRENT_LIST:+, }'speech']"
                        gsettings set org.cinnamon.desktop.keybindings custom-list "$NEW_LIST"
                    fi
                fi
                
                gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ binding "['<Shift><Super>t']"
                gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ command "$HOME/.local/bin/speech-tools/transcribe.sh"
                gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ name "Speech Transcription"
            else
                echo "Your desktop environment is not directly supported for automatic shortcut setup."
                echo "Please use option 3 to set up shortcuts manually."
                return 1
            fi
            
            echo "Default shortcut (Shift+Super+T) has been set up."
            echo "You may need to log out and back in for changes to take effect."
            ;;
            
        2)
            echo "----------------------------------------"
            echo "To set up a gesture:"
            echo "1. Opening System Settings > Gestures"
            echo "2. Add a new gesture"
            echo "3. Use this command: $HOME/.local/bin/speech-tools/transcribe.sh"
            echo "4. Choose your preferred gesture (e.g., four finger swipe up)"
            echo "----------------------------------------"
            
            if [ "$DE" = "gnome" ]; then
                gnome-control-center gestures
            elif [ "$DE" = "cinnamon" ]; then
                cinnamon-settings gestures
            else
                echo "Could not detect your desktop environment's settings command."
                echo "Please open System Settings > Gestures manually."
            fi
            ;;
            
        3)
            echo "----------------------------------------"
            echo "To set up your own shortcut:"
            echo "1. Open System Settings"
            echo "2. Go to Keyboard > Shortcuts > Custom Shortcuts"
            echo "3. Click Add custom shortcut"
            echo "4. Name: Speech Transcription"
            echo "5. Command: $HOME/.local/bin/speech-tools/transcribe.sh"
            echo "6. Click Add"
            echo "7. Click on 'unassigned' and press your desired key combination"
            echo "----------------------------------------"
            
            read -p "Would you like to open System Settings now? (y/n): " open_settings
            if [[ $open_settings =~ ^[Yy]$ ]]; then
                if [ "$DE" = "gnome" ]; then
                    gnome-control-center keyboard
                elif [ "$DE" = "cinnamon" ]; then
                    cinnamon-settings keyboard
                else
                    echo "Could not detect your desktop environment's settings command."
                    echo "Please open System Settings manually."
                fi
            fi
            ;;
            
        4)
            echo "Skipping shortcut setup."
            echo "You can set up shortcuts or gestures later through System Settings."
            ;;
            
        *)
            echo "Invalid choice. Skipping shortcut setup."
            ;;
    esac
}

# Main installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # First check OS compatibility
    check_os_compatibility
    
    # Check if transcribe.sh exists in the same directory
    if [ ! -f "${SCRIPT_DIR}/transcribe.sh" ]; then
        echo "Error: transcribe.sh not found in the same directory as conduit.sh"
        echo "Please ensure both scripts are in the same directory."
        exit 1
    fi
    
    # Verify script is executable
    if [ ! -x "${SCRIPT_DIR}/transcribe.sh" ]; then
        echo "Making transcribe.sh executable..."
        chmod +x "${SCRIPT_DIR}/transcribe.sh"
    fi
    
    # Run installation steps with error handling
    echo "=========================================="
    echo "Starting Conduit Installation"
    echo "=========================================="
    
    # Install dependencies (critical - must succeed)
    if ! install_dependencies; then
        echo "Failed to install required dependencies"
        exit 1
    fi
    
    # Setup shortcuts (optional - can fail)
    set +e  # Temporarily disable error exit
    setup_shortcuts
    local shortcut_result=$?
    set -e
    
    if [ $shortcut_result -ne 0 ]; then
        echo "Note: Shortcut setup was skipped or failed"
        echo "You can set up shortcuts manually later"
    fi
    
    echo ""
    echo "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run: source ~/.bashrc"
    echo "2. Configure your Groq API key in: ${SCRIPT_DIR}/.env"
    echo "3. Test the tool by running: transcribe.sh"
    echo ""
    
    # Exit with success
    exit 0
fi

#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Get the directory where install script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLATFORM=""

# Detect platform
detect_platform() {
    case "$OSTYPE" in
        linux-gnu*)
            PLATFORM="linux"
            ;;
        darwin*)
            PLATFORM="macos"
            ;;
        msys*|cygwin*|mingw*)
            PLATFORM="windows"
            echo "Error: Windows is not yet supported"
            exit 1
            ;;
        *)
            echo "Error: Unknown operating system: $OSTYPE"
            exit 1
            ;;
    esac
    
    echo "=========================================="
    echo "Detected platform: $PLATFORM"
    echo "=========================================="
}

# Platform-specific dependency installation
install_dependencies() {
    case "$PLATFORM" in
        linux)
            install_linux_dependencies
            ;;
        macos)
            install_macos_dependencies
            ;;
    esac
}

# Linux dependency installation
install_linux_dependencies() {
    echo "Installing Linux dependencies..."
    
    # Check for package manager
    if command -v apt-get &> /dev/null; then
        echo "Using apt-get package manager..."
        
        # Check for sudo access
        if ! sudo -n true 2>/dev/null; then
            echo "This installer requires sudo access to install system packages."
            echo "Please enter your password when prompted."
        fi
        
        # Update package list
        echo "Updating package list..."
        sudo apt-get update || echo "Warning: Failed to update package list"
        
        # Install packages
        local packages=("sox" "curl" "jq" "xdotool" "yad" "xclip")
        for package in "${packages[@]}"; do
            echo "Installing $package..."
            sudo apt-get install -y "$package" || echo "Warning: Failed to install $package"
        done
        
    elif command -v yum &> /dev/null; then
        echo "Using yum package manager..."
        sudo yum install -y sox curl jq xdotool yad xclip
        
    elif command -v pacman &> /dev/null; then
        echo "Using pacman package manager..."
        sudo pacman -S --noconfirm sox curl jq xdotool yad xclip
        
    else
        echo "=========================================="
        echo "ERROR: No supported package manager found"
        echo "Please install these packages manually:"
        echo "  - sox (for audio recording)"
        echo "  - curl (for API calls)"
        echo "  - jq (for JSON parsing)"
        echo "  - xdotool (optional, for auto-paste)"
        echo "  - yad (optional, for GUI dialogs)"
        echo "  - xclip (for clipboard)"
        echo "=========================================="
        exit 1
    fi
}

# macOS dependency installation
install_macos_dependencies() {
    echo "Installing macOS dependencies..."
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        echo "=========================================="
        echo "Homebrew is not installed!"
        echo ""
        echo "Homebrew is required to install dependencies."
        echo "Would you like to install Homebrew now?"
        echo "=========================================="
        read -p "Install Homebrew? (y/n): " install_brew
        
        if [[ $install_brew =~ ^[Yy]$ ]]; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        else
            echo "=========================================="
            echo "Cannot proceed without Homebrew."
            echo "Please install these tools manually:"
            echo "  - curl"
            echo "  - jq"
            echo "  - sox (optional, for better recording)"
            echo "=========================================="
            exit 1
        fi
    fi
    
    # Install required packages
    echo "Installing required packages with Homebrew..."
    
    local packages=("curl" "jq")
    for package in "${packages[@]}"; do
        if brew list "$package" &> /dev/null; then
            echo "✓ $package is already installed"
        else
            echo "Installing $package..."
            brew install "$package" || echo "Warning: Failed to install $package"
        fi
    done
    
    # Install optional sox for better audio recording
    echo ""
    echo "=========================================="
    echo "Optional: Install sox for better audio recording?"
    echo "Without sox, the tool will use macOS QuickTime"
    echo "=========================================="
    read -p "Install sox? (y/n): " install_sox
    
    if [[ $install_sox =~ ^[Yy]$ ]]; then
        if brew list sox &> /dev/null; then
            echo "✓ sox is already installed"
        else
            echo "Installing sox..."
            brew install sox || echo "Warning: Failed to install sox"
        fi
    fi
}

# Setup .env file
setup_env_file() {
    echo ""
    echo "=========================================="
    echo "Setting up API configuration..."
    echo "=========================================="
    
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
        
        echo "Created .env file with secure permissions (600)"
        echo ""
        echo "To complete setup:"
        echo "1. Get your API key from: https://console.groq.com/"
        echo "2. Edit: ${SCRIPT_DIR}/.env"
        echo "3. Replace 'your_api_key_here' with your actual key"
        echo ""
        echo "Your API key should look like: gsk_XXXXXXXX..."
        
        # Prompt to open editor
        read -p "Would you like to edit the .env file now? (y/n): " edit_now
        if [[ $edit_now =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "${SCRIPT_DIR}/.env"
        fi
    else
        # Check existing file permissions
        if [ "$PLATFORM" = "linux" ]; then
            local perms=$(stat -c %a "${SCRIPT_DIR}/.env" 2>/dev/null)
        elif [ "$PLATFORM" = "macos" ]; then
            local perms=$(stat -f %A "${SCRIPT_DIR}/.env" 2>/dev/null)
        fi
        
        if [ -n "${perms:-}" ] && [ "$perms" != "600" ]; then
            echo "Fixing .env file permissions for security..."
            chmod 600 "${SCRIPT_DIR}/.env"
        fi
        echo "✓ Existing .env file found and preserved"
    fi
}

# Setup shell integration
setup_shell_integration() {
    echo ""
    echo "=========================================="
    echo "Setting up shell integration..."
    echo "=========================================="
    
    # Determine shell config file
    local shell_config=""
    if [ -n "${SHELL:-}" ]; then
        case "$SHELL" in
            */bash)
                shell_config="$HOME/.bashrc"
                ;;
            */zsh)
                shell_config="$HOME/.zshrc"
                ;;
            */fish)
                shell_config="$HOME/.config/fish/config.fish"
                ;;
        esac
    fi
    
    if [ -z "$shell_config" ]; then
        echo "Could not determine shell configuration file"
        echo "Please add this directory to your PATH manually:"
        echo "  export PATH=\"\$PATH:${SCRIPT_DIR}\""
        return
    fi
    
    # Add to PATH if not already present
    if ! grep -q "${SCRIPT_DIR}" "$shell_config" 2>/dev/null; then
        echo "Adding ${SCRIPT_DIR} to PATH in $shell_config"
        echo "" >> "$shell_config"
        echo "# Conduit speech-to-text tool" >> "$shell_config"
        echo "export PATH=\"\$PATH:${SCRIPT_DIR}\"" >> "$shell_config"
        echo ""
        echo "✓ Added to PATH. Please restart your terminal or run:"
        echo "  source $shell_config"
    else
        echo "✓ Directory already in PATH"
    fi
}

# Setup keyboard shortcuts for macOS
setup_macos_shortcuts() {
    echo ""
    echo "=========================================="
    echo "macOS Keyboard Shortcut Setup"
    echo "=========================================="
    echo ""
    echo "To set up a keyboard shortcut on macOS:"
    echo ""
    echo "1. Open System Preferences > Keyboard > Shortcuts"
    echo "2. Select 'Services' from the left sidebar"
    echo "3. Click the '+' button to add a new service"
    echo "4. Set up as follows:"
    echo "   - Service receives: 'no input'"
    echo "   - Run Shell Script: ${SCRIPT_DIR}/transcribe-cross-platform.sh"
    echo "5. Assign your preferred keyboard shortcut"
    echo ""
    echo "Alternatively, you can use third-party tools like:"
    echo "  - Raycast (https://raycast.com)"
    echo "  - Alfred (https://alfredapp.com)"
    echo "  - Keyboard Maestro"
    echo ""
    read -p "Press Enter to continue..."
}

# Setup keyboard shortcuts for Linux
setup_linux_shortcuts() {
    echo ""
    echo "=========================================="
    echo "Linux Keyboard Shortcut Setup"
    echo "=========================================="
    echo ""
    
    # Try to detect desktop environment
    local desktop_env=""
    if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
        desktop_env="$XDG_CURRENT_DESKTOP"
    elif [ -n "${DESKTOP_SESSION:-}" ]; then
        desktop_env="$DESKTOP_SESSION"
    fi
    
    case "$desktop_env" in
        *GNOME*|*gnome*)
            echo "Detected GNOME desktop"
            echo "Would you like to set up a keyboard shortcut (Shift+Super+T)?"
            read -p "Setup shortcut? (y/n): " setup_shortcut
            
            if [[ $setup_shortcut =~ ^[Yy]$ ]]; then
                gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/']"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ name "Speech Transcription"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ command "${SCRIPT_DIR}/transcribe-cross-platform.sh"
                gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/ binding "<Shift><Super>t"
                echo "✓ Shortcut configured: Shift+Super+T"
            fi
            ;;
            
        *KDE*|*kde*)
            echo "For KDE Plasma:"
            echo "1. Open System Settings > Shortcuts > Custom Shortcuts"
            echo "2. Create a new Global Shortcut > Command/URL"
            echo "3. Set the command to: ${SCRIPT_DIR}/transcribe-cross-platform.sh"
            echo "4. Assign your preferred shortcut"
            ;;
            
        *)
            echo "To set up a keyboard shortcut:"
            echo "1. Open your system's keyboard settings"
            echo "2. Add a custom shortcut"
            echo "3. Set the command to: ${SCRIPT_DIR}/transcribe-cross-platform.sh"
            echo "4. Assign your preferred key combination"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main installation
main() {
    echo "=========================================="
    echo "Conduit Cross-Platform Installer"
    echo "=========================================="
    echo ""
    
    # Detect platform
    detect_platform
    
    # Check for transcribe script
    if [ ! -f "${SCRIPT_DIR}/transcribe-cross-platform.sh" ]; then
        echo "Error: transcribe-cross-platform.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "${SCRIPT_DIR}/transcribe-cross-platform.sh"
    if [ -f "${SCRIPT_DIR}/transcribe.sh" ]; then
        chmod +x "${SCRIPT_DIR}/transcribe.sh"
    fi
    if [ -f "${SCRIPT_DIR}/conduit.sh" ]; then
        chmod +x "${SCRIPT_DIR}/conduit.sh"
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup .env file
    setup_env_file
    
    # Setup shell integration
    setup_shell_integration
    
    # Setup keyboard shortcuts
    case "$PLATFORM" in
        linux)
            setup_linux_shortcuts
            ;;
        macos)
            setup_macos_shortcuts
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "✓ Installation Complete!"
    echo "=========================================="
    echo ""
    echo "To use Conduit:"
    echo "1. Make sure your Groq API key is configured in .env"
    echo "2. Run: transcribe-cross-platform.sh"
    echo "3. Start speaking, then press Ctrl+C to stop"
    echo ""
    echo "The transcribed text will be copied to your clipboard."
    echo ""
    echo "For issues or questions, check the README.md file."
    echo "=========================================="
}

# Run main installation
main
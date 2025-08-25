#!/bin/bash

# Conduit Uninstaller Script
# Safely removes Conduit and all its components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Platform detection
PLATFORM=""
detect_platform() {
    case "$OSTYPE" in
        linux-gnu*)
            PLATFORM="linux"
            ;;
        darwin*)
            PLATFORM="macos"
            ;;
        *)
            echo -e "${RED}Error: Unknown operating system: $OSTYPE${NC}"
            exit 1
            ;;
    esac
}

# Log function
log() {
    echo -e "${GREEN}[UNINSTALL]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Confirmation prompt
confirm_uninstall() {
    echo ""
    echo "=========================================="
    echo "       Conduit Uninstaller"
    echo "=========================================="
    echo ""
    echo "This will remove:"
    echo "  • Conduit scripts from PATH"
    echo "  • Symbolic links"
    echo "  • Shell configuration entries"
    echo "  • Keyboard shortcuts (if possible)"
    echo ""
    echo "This will NOT remove:"
    echo "  • Your .env file with API key"
    echo "  • System dependencies (sox, curl, jq)"
    echo "  • The project directory itself"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
}

# Remove from PATH
remove_from_path() {
    log "Removing from PATH..."
    
    local shell_configs=()
    
    # Determine shell config files to check
    [ -f "$HOME/.bashrc" ] && shell_configs+=("$HOME/.bashrc")
    [ -f "$HOME/.zshrc" ] && shell_configs+=("$HOME/.zshrc")
    [ -f "$HOME/.bash_profile" ] && shell_configs+=("$HOME/.bash_profile")
    [ -f "$HOME/.profile" ] && shell_configs+=("$HOME/.profile")
    [ -f "$HOME/.config/fish/config.fish" ] && shell_configs+=("$HOME/.config/fish/config.fish")
    
    for config in "${shell_configs[@]}"; do
        if grep -q "$SCRIPT_DIR" "$config" 2>/dev/null; then
            log "Removing PATH entry from $config"
            # Create backup
            cp "$config" "${config}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Remove lines containing the script directory
            if [ "$PLATFORM" = "macos" ]; then
                sed -i '' "\|$SCRIPT_DIR|d" "$config"
            else
                sed -i "\|$SCRIPT_DIR|d" "$config"
            fi
            
            # Also remove comment lines we added
            if [ "$PLATFORM" = "macos" ]; then
                sed -i '' '/# Conduit speech-to-text tool/d' "$config"
            else
                sed -i '/# Conduit speech-to-text tool/d' "$config"
            fi
        fi
    done
}

# Remove symbolic links
remove_symlinks() {
    log "Removing symbolic links..."
    
    # Common locations for symlinks
    local link_locations=(
        "$HOME/.local/bin/speech-tools"
        "$HOME/.local/bin/conduit"
        "$HOME/.local/bin/transcribe.sh"
        "$HOME/.local/bin/transcribe-cross-platform.sh"
        "/usr/local/bin/conduit"
        "/usr/local/bin/transcribe.sh"
    )
    
    for link in "${link_locations[@]}"; do
        if [ -L "$link" ]; then
            # Check if it points to our scripts
            local target=$(readlink "$link" 2>/dev/null || true)
            if [[ "$target" == *"$SCRIPT_DIR"* ]]; then
                log "Removing symlink: $link"
                rm -f "$link"
            fi
        fi
    done
    
    # Remove speech-tools directory if empty
    if [ -d "$HOME/.local/bin/speech-tools" ]; then
        if [ -z "$(ls -A "$HOME/.local/bin/speech-tools")" ]; then
            log "Removing empty directory: $HOME/.local/bin/speech-tools"
            rmdir "$HOME/.local/bin/speech-tools"
        fi
    fi
}

# Remove keyboard shortcuts
remove_shortcuts() {
    log "Removing keyboard shortcuts..."
    
    case "$PLATFORM" in
        linux)
            remove_linux_shortcuts
            ;;
        macos)
            remove_macos_shortcuts
            ;;
    esac
}

# Remove Linux shortcuts
remove_linux_shortcuts() {
    # Detect desktop environment
    local desktop_env="${XDG_CURRENT_DESKTOP:-}"
    
    case "$desktop_env" in
        *GNOME*|*gnome*)
            log "Removing GNOME keyboard shortcuts..."
            
            # Remove custom keybinding
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]" 2>/dev/null || true
            
            # Reset the specific binding
            local binding_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/"
            gsettings reset-recursively "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$binding_path" 2>/dev/null || true
            ;;
            
        *CINNAMON*|*X-Cinnamon*)
            log "Removing Cinnamon keyboard shortcuts..."
            
            # Get current custom list
            local current_list=$(gsettings get org.cinnamon.desktop.keybindings custom-list 2>/dev/null || echo "[]")
            
            # Remove 'speech' from the list
            if [[ "$current_list" == *"speech"* ]]; then
                local new_list=$(echo "$current_list" | sed "s/'speech'//g" | sed 's/, ,/,/g' | sed 's/\[, /\[/g' | sed 's/, \]/\]/g')
                gsettings set org.cinnamon.desktop.keybindings custom-list "$new_list" 2>/dev/null || true
            fi
            
            # Reset the binding
            local binding_path="/org/cinnamon/desktop/keybindings/custom-keybindings/speech/"
            gsettings reset-recursively "org.cinnamon.desktop.keybindings.custom-keybinding:$binding_path" 2>/dev/null || true
            ;;
            
        *)
            warning "Cannot automatically remove shortcuts for your desktop environment."
            warning "Please remove manually from your keyboard settings."
            ;;
    esac
}

# Remove macOS shortcuts
remove_macos_shortcuts() {
    warning "macOS shortcuts must be removed manually:"
    echo "  1. Open System Preferences > Keyboard > Shortcuts"
    echo "  2. Select 'Services' from the left sidebar"
    echo "  3. Find and remove any Conduit-related services"
    echo ""
    echo "If using third-party tools (Raycast, Alfred, etc.), remove shortcuts there."
}

# Remove temporary files
clean_temp_files() {
    log "Cleaning temporary files..."
    
    # Remove temp audio and text files
    rm -f /tmp/audio*.wav 2>/dev/null || true
    rm -f /tmp/text* 2>/dev/null || true
    rm -f /tmp/response* 2>/dev/null || true
    
    # Remove log files
    rm -f /tmp/conduit.log 2>/dev/null || true
}

# Remove Homebrew installation (macOS)
remove_homebrew_install() {
    if [ "$PLATFORM" = "macos" ] && command -v brew &> /dev/null; then
        if brew list conduit &> /dev/null; then
            log "Removing Homebrew installation..."
            brew uninstall conduit || true
        fi
    fi
}

# Final cleanup suggestions
suggest_manual_cleanup() {
    echo ""
    echo "=========================================="
    echo "     Uninstallation Complete"
    echo "=========================================="
    echo ""
    echo "Automatic removal complete. For full cleanup, you may also want to:"
    echo ""
    echo "1. Remove the project directory:"
    echo "   rm -rf $SCRIPT_DIR"
    echo ""
    echo "2. Remove your API key file (if no longer needed):"
    echo "   rm $SCRIPT_DIR/.env"
    echo ""
    echo "3. Uninstall system dependencies (if no longer needed):"
    
    case "$PLATFORM" in
        linux)
            echo "   sudo apt-get remove sox curl jq xdotool yad xclip"
            ;;
        macos)
            echo "   brew uninstall sox curl jq"
            ;;
    esac
    
    echo ""
    echo "4. Remove any backups created:"
    echo "   ls ~/.bashrc.backup.* ~/.zshrc.backup.*"
    echo ""
    echo "Thank you for using Conduit!"
}

# Main uninstallation process
main() {
    # Detect platform
    detect_platform
    
    # Confirm with user
    confirm_uninstall
    
    echo ""
    log "Starting uninstallation for $PLATFORM..."
    echo ""
    
    # Perform uninstallation steps
    remove_from_path
    remove_symlinks
    remove_shortcuts
    clean_temp_files
    remove_homebrew_install
    
    # Show final suggestions
    suggest_manual_cleanup
}

# Run main function
main "$@"
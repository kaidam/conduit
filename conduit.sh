#!/bin/bash

# Enhanced Conduit - Cross-platform Linux speech-to-text transcription tool
# Compatible with multiple Linux distributions and desktop environments

# Get the directory where conduit.sh is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_FAMILY=$ID_LIKE
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
        DISTRO_FAMILY="rhel fedora"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        DISTRO_FAMILY="debian"
    else
        DISTRO="unknown"
        DISTRO_FAMILY="unknown"
    fi
    
    log_info "Detected distribution: $DISTRO"
}

# Detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        INSTALL_CMD="sudo apt update && sudo apt install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD="sudo yum install -y"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        INSTALL_CMD="sudo zypper install -y"
    elif command -v emerge &> /dev/null; then
        PKG_MANAGER="emerge"
        INSTALL_CMD="sudo emerge"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
        INSTALL_CMD="sudo apk add"
    else
        PKG_MANAGER="unknown"
        INSTALL_CMD="unknown"
    fi
    
    log_info "Detected package manager: $PKG_MANAGER"
}

# Detect desktop environment
detect_desktop_environment() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')
    elif [ -n "$DESKTOP_SESSION" ]; then
        DE=$(echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]')
    elif [ -n "$GDMSESSION" ]; then
        DE=$(echo "$GDMSESSION" | tr '[:upper:]' '[:lower:]')
    elif pgrep -x "gnome-session" > /dev/null; then
        DE="gnome"
    elif pgrep -x "cinnamon-session" > /dev/null; then
        DE="cinnamon"
    elif pgrep -x "xfce4-session" > /dev/null; then
        DE="xfce"
    elif pgrep -x "lxsession" > /dev/null; then
        DE="lxde"
    elif pgrep -x "mate-session" > /dev/null; then
        DE="mate"
    elif pgrep -x "ksmserver" > /dev/null; then
        DE="kde"
    else
        DE="unknown"
    fi
    
    log_info "Detected desktop environment: $DE"
}

# Map package names for different distributions
get_package_names() {
    case $PKG_MANAGER in
        "apt")
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
        "dnf"|"yum")
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
        "pacman")
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
        "zypper")
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
        "emerge")
            PACKAGES="media-sound/sox net-misc/curl app-misc/jq x11-misc/xdotool x11-misc/yad x11-misc/xclip"
            ;;
        "apk")
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
        *)
            PACKAGES="sox curl jq xdotool yad xclip"
            ;;
    esac
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install missing dependencies
install_dependencies() {
    log_info "Checking and installing required dependencies..."
    
    detect_distro
    detect_package_manager
    get_package_names
    
    if [ "$PKG_MANAGER" = "unknown" ]; then
        log_error "Could not detect package manager. Please install these packages manually:"
        log_error "sox, curl, jq, xdotool, yad, xclip"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        # Update package lists for apt-based systems
        if [ "$PKG_MANAGER" = "apt" ]; then
            log_info "Updating package lists..."
            sudo apt update
        fi
        
        # Install packages
        log_info "Installing packages: $PACKAGES"
        if ! $INSTALL_CMD $PACKAGES; then
            log_error "Failed to install some packages. Please install them manually."
            log_error "Required packages: sox, curl, jq, xdotool, yad, xclip"
        else
            log_success "Dependencies installed successfully"
        fi
    fi
    
    # Verify critical dependencies
    missing_deps=()
    for dep in sox curl jq xdotool xclip; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_warning "The tool may not work properly without these."
    fi
    
    # Check for yad specifically (fallback notification method)
    if ! command_exists "yad"; then
        log_warning "yad not found. Will use notify-send for notifications."
        if ! command_exists "notify-send"; then
            log_warning "notify-send also not found. Please install libnotify or similar."
        fi
    fi
    
    # Create directory for scripts
    mkdir -p ~/.local/bin/speech-tools
    
    # Create symlink to transcribe.sh
    log_info "Creating symlink to transcribe.sh in ~/.local/bin/speech-tools/"
    ln -sf "${SCRIPT_DIR}/transcribe.sh" ~/.local/bin/speech-tools/transcribe.sh
    
    # Make original script executable
    chmod +x "${SCRIPT_DIR}/transcribe.sh"
    
    # Add to PATH if not already present
    if ! grep -q "speech-tools" ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/.local/bin/speech-tools"' >> ~/.bashrc
        log_info "Added speech-tools to PATH in ~/.bashrc"
    fi
    
    # Also try other shell configs
    for shell_config in ~/.zshrc ~/.profile ~/.bash_profile; do
        if [ -f "$shell_config" ] && ! grep -q "speech-tools" "$shell_config"; then
            echo 'export PATH="$PATH:$HOME/.local/bin/speech-tools"' >> "$shell_config"
            log_info "Added speech-tools to PATH in $shell_config"
        fi
    done
    
    setup_env_file
}

# Setup .env file
setup_env_file() {
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            chmod 600 "${SCRIPT_DIR}/.env"
            log_success "Created .env file from .env.example"
        else
            echo "GROQ_API_KEY=your_api_key_here" > "${SCRIPT_DIR}/.env"
            chmod 600 "${SCRIPT_DIR}/.env"
            log_success "Created new .env file"
        fi
        
        echo "----------------------------------------"
        log_warning "You will need a Groq API key to use this tool."
        echo "1. Get your API key from: https://console.groq.com/"
        echo "2. Edit ${SCRIPT_DIR}/.env"
        echo "3. Replace 'your_api_key_here' with your actual Groq API key"
        echo "----------------------------------------"
    else
        log_info "Existing .env file found and preserved"
    fi
    
    # Create symlink to .env file in speech-tools directory
    ln -sf "${SCRIPT_DIR}/.env" ~/.local/bin/speech-tools/.env
}

# Setup keyboard shortcuts for different desktop environments
setup_shortcuts() {
    detect_desktop_environment
    
    echo "----------------------------------------"
    echo "Shortcut Setup"
    echo "Would you like to:"
    echo "1) Set up default keyboard shortcut (Shift+Super+T)"
    echo "2) Set up a touchpad gesture (if supported)"
    echo "3) Open System Settings to set up manually"
    echo "4) Skip shortcut setup"
    echo "----------------------------------------"
    echo "Pro tip: You can also use Shift+Ctrl+Print (or Shift+Ctrl+Fn+F12) for screenshots in some editors"
    echo "----------------------------------------"
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            setup_default_shortcut
            ;;
        2)
            setup_gesture
            ;;
        3)
            open_settings_manual
            ;;
        4)
            log_info "Skipping shortcut setup."
            echo "You can set up shortcuts or gestures later through System Settings."
            ;;
        *)
            log_warning "Invalid choice. Skipping shortcut setup."
            ;;
    esac
}

# Setup default keyboard shortcut
setup_default_shortcut() {
    local shortcut_cmd="$HOME/.local/bin/speech-tools/transcribe.sh"
    
    case $DE in
        *gnome*|*ubuntu*)
            if command_exists gsettings; then
                setup_gnome_shortcut "$shortcut_cmd"
            else
                log_error "gsettings not found. Cannot set up GNOME shortcuts automatically."
                fallback_manual_setup
            fi
            ;;
        *cinnamon*)
            if command_exists gsettings; then
                setup_cinnamon_shortcut "$shortcut_cmd"
            else
                log_error "gsettings not found. Cannot set up Cinnamon shortcuts automatically."
                fallback_manual_setup
            fi
            ;;
        *kde*|*plasma*)
            setup_kde_shortcut "$shortcut_cmd"
            ;;
        *xfce*)
            setup_xfce_shortcut "$shortcut_cmd"
            ;;
        *mate*)
            setup_mate_shortcut "$shortcut_cmd"
            ;;
        *lxde*|*lxqt*)
            setup_lxde_shortcut "$shortcut_cmd"
            ;;
        *)
            log_warning "Desktop environment '$DE' not directly supported for automatic shortcut setup."
            fallback_manual_setup
            ;;
    esac
}

# GNOME shortcut setup
setup_gnome_shortcut() {
    local cmd="$1"
    
    # Get current custom keybindings
    local current_bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    local speech_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/speech/"
    
    # Add our path to the list if not already there
    if [[ "$current_bindings" != *"$speech_path"* ]]; then
        if [ "$current_bindings" = "@as []" ]; then
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$speech_path']"
        else
            # Remove the closing bracket and add our entry
            local new_bindings=$(echo "$current_bindings" | sed "s/]$/, '$speech_path']/")
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_bindings"
        fi
    fi
    
    # Set the actual shortcut
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$speech_path name "Speech Transcription"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$speech_path command "$cmd"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$speech_path binding "<Shift><Super>t"
    
    log_success "GNOME shortcut (Shift+Super+T) has been set up."
}

# Cinnamon shortcut setup
setup_cinnamon_shortcut() {
    local cmd="$1"
    
    local current_list=$(gsettings get org.cinnamon.desktop.keybindings custom-list)
    if [ "$current_list" = "@as []" ]; then
        gsettings set org.cinnamon.desktop.keybindings custom-list "['speech']"
    else
        current_list=${current_list//[\[\]\'\"]/}
        if [[ ! $current_list =~ "speech" ]]; then
            local new_list="[$(echo "'$current_list'" | sed "s/,/, /g")${current_list:+, }'speech']"
            gsettings set org.cinnamon.desktop.keybindings custom-list "$new_list"
        fi
    fi
    
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ binding "['<Shift><Super>t']"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ command "$cmd"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ name "Speech Transcription"
    
    log_success "Cinnamon shortcut (Shift+Super+T) has been set up."
}

# KDE shortcut setup
setup_kde_shortcut() {
    local cmd="$1"
    
    if command_exists kwriteconfig5; then
        # Create a desktop file for the shortcut
        local desktop_file="$HOME/.local/share/applications/speech-transcription.desktop"
        cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=Speech Transcription
Exec=$cmd
NoDisplay=true
StartupNotify=false
EOF
        
        log_info "Created desktop file for KDE. Please set up the shortcut manually:"
        log_info "1. Open System Settings > Shortcuts > Custom Shortcuts"
        log_info "2. Add new shortcut with command: $cmd"
        log_info "3. Assign Shift+Meta+T as the key combination"
    else
        fallback_manual_setup
    fi
}

# XFCE shortcut setup
setup_xfce_shortcut() {
    local cmd="$1"
    
    if command_exists xfconf-query; then
        xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Shift><Super>t" -n -t string -s "$cmd"
        log_success "XFCE shortcut (Shift+Super+T) has been set up."
    else
        fallback_manual_setup
    fi
}

# MATE shortcut setup
setup_mate_shortcut() {
    local cmd="$1"
    
    if command_exists gsettings && gsettings list-schemas | grep -q "org.mate."; then
        # MATE uses similar structure to GNOME but with different schema
        local current_bindings=$(gsettings get org.mate.media-keys custom-keybindings)
        local speech_path="/org/mate/desktop/keybindings/speech/"
        
        if [[ "$current_bindings" != *"$speech_path"* ]]; then
            if [ "$current_bindings" = "@as []" ]; then
                gsettings set org.mate.media-keys custom-keybindings "['$speech_path']"
            else
                local new_bindings=$(echo "$current_bindings" | sed "s/]$/, '$speech_path']/")
                gsettings set org.mate.media-keys custom-keybindings "$new_bindings"
            fi
        fi
        
        gsettings set org.mate.desktop.keybinding:/org/mate/desktop/keybindings/speech/ name "Speech Transcription"
        gsettings set org.mate.desktop.keybinding:/org/mate/desktop/keybindings/speech/ action "$cmd"
        gsettings set org.mate.desktop.keybinding:/org/mate/desktop/keybindings/speech/ binding "<Shift><Super>t"
        
        log_success "MATE shortcut (Shift+Super+T) has been set up."
    else
        fallback_manual_setup
    fi
}

# LXDE/LXQt shortcut setup
setup_lxde_shortcut() {
    local cmd="$1"
    
    log_info "For LXDE/LXQt, please set up the shortcut manually:"
    log_info "1. Right-click on desktop > Desktop Preferences > Advanced"
    log_info "2. Or use your window manager's shortcut settings"
    log_info "3. Add command: $cmd"
    log_info "4. Assign Shift+Super+T as the key combination"
}

# Fallback manual setup instructions
fallback_manual_setup() {
    echo "----------------------------------------"
    echo "To set up your own shortcut:"
    echo "1. Open System Settings / Control Panel"
    echo "2. Look for Keyboard, Shortcuts, or Hotkeys section"
    echo "3. Add a new custom shortcut with:"
    echo "   Name: Speech Transcription"
    echo "   Command: $HOME/.local/bin/speech-tools/transcribe.sh"
    echo "   Key combination: Shift+Super+T (or your preference)"
    echo "----------------------------------------"
}

# Setup gesture
setup_gesture() {
    echo "----------------------------------------"
    echo "To set up a gesture:"
    echo "1. Open System Settings"
    echo "2. Look for Gestures, Touchpad, or Mouse & Touchpad"
    echo "3. Add a new gesture"
    echo "4. Use this command: $HOME/.local/bin/speech-tools/transcribe.sh"
    echo "5. Choose your preferred gesture (e.g., four finger swipe up)"
    echo "----------------------------------------"
    
    case $DE in
        *gnome*|*ubuntu*)
            if command_exists gnome-control-center; then
                gnome-control-center gestures 2>/dev/null || gnome-control-center mouse 2>/dev/null
            fi
            ;;
        *cinnamon*)
            if command_exists cinnamon-settings; then
                cinnamon-settings gestures 2>/dev/null || cinnamon-settings mouse 2>/dev/null
            fi
            ;;
        *kde*|*plasma*)
            if command_exists systemsettings5; then
                systemsettings5 kcm_touchpad 2>/dev/null
            fi
            ;;
        *)
            log_info "Please open your system settings manually to configure gestures."
            ;;
    esac
}

# Open settings for manual configuration
open_settings_manual() {
    echo "----------------------------------------"
    echo "Opening system settings for manual shortcut configuration..."
    echo "Look for: Keyboard > Shortcuts > Custom Shortcuts"
    echo "Command to use: $HOME/.local/bin/speech-tools/transcribe.sh"
    echo "----------------------------------------"
    
    case $DE in
        *gnome*|*ubuntu*)
            if command_exists gnome-control-center; then
                gnome-control-center keyboard
            fi
            ;;
        *cinnamon*)
            if command_exists cinnamon-settings; then
                cinnamon-settings keyboard
            fi
            ;;
        *kde*|*plasma*)
            if command_exists systemsettings5; then
                systemsettings5 kcm_keys
            elif command_exists systemsettings; then
                systemsettings kcm_keys
            fi
            ;;
        *xfce*)
            if command_exists xfce4-settings-manager; then
                xfce4-settings-manager
            fi
            ;;
        *mate*)
            if command_exists mate-control-center; then
                mate-control-center keyboard
            fi
            ;;
        *)
            log_info "Could not detect how to open settings for your desktop environment."
            log_info "Please open System Settings manually and look for keyboard shortcuts."
            ;;
    esac
}

# Main installation function
main() {
    log_info "Starting Conduit installation..."
    
    # Check if transcribe.sh exists in the same directory
    if [ ! -f "${SCRIPT_DIR}/transcribe.sh" ]; then
        log_error "transcribe.sh not found in the same directory as conduit.sh"
        exit 1
    fi
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is designed for Linux systems only."
        exit 1
    fi
    
    # Check if we have basic tools
    if ! command_exists "bash"; then
        log_error "Bash is required but not found."
        exit 1
    fi
    
    install_dependencies
    setup_shortcuts
    
    log_success "Installation complete!"
    echo "----------------------------------------"
    echo "Next steps:"
    echo "1. Restart your terminal or run 'source ~/.bashrc'"
    echo "2. Edit ${SCRIPT_DIR}/.env and add your Groq API key"
    echo "3. Test the tool with your configured shortcut"
    echo "----------------------------------------"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

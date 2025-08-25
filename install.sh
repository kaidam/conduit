#!/bin/bash

# Universal Installer for Conduit
# Comprehensive installation script with multiple installation methods

set -euo pipefail

# Version
VERSION=$(cat VERSION 2>/dev/null || echo "1.1.0")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="${CONDUIT_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conduit"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Platform detection
PLATFORM=""
DISTRO=""
PACKAGE_MANAGER=""

# Log functions
log() {
    echo -e "${GREEN}[INSTALL]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Detect platform and distribution
detect_platform() {
    case "$OSTYPE" in
        linux-gnu*)
            PLATFORM="linux"
            detect_linux_distro
            ;;
        darwin*)
            PLATFORM="macos"
            PACKAGE_MANAGER="brew"
            ;;
        msys*|cygwin*|mingw*)
            error "Windows is not yet supported"
            ;;
        *)
            error "Unknown operating system: $OSTYPE"
            ;;
    esac
    
    log "Detected platform: $PLATFORM"
    [ -n "$DISTRO" ] && log "Detected distribution: $DISTRO"
    [ -n "$PACKAGE_MANAGER" ] && log "Package manager: $PACKAGE_MANAGER"
}

# Detect Linux distribution and package manager
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
    fi
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
    elif command -v apk &> /dev/null; then
        PACKAGE_MANAGER="apk"
    else
        PACKAGE_MANAGER="unknown"
    fi
}

# Show installation banner
show_banner() {
    cat << 'EOF'
    ╔═══════════════════════════════════════╗
    ║        Conduit Installer v1.1.0       ║
    ║   Speech-to-Text Transcription Tool   ║
    ╚═══════════════════════════════════════╝
EOF
    echo ""
}

# Check for root/sudo
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        warning "Running as root is not recommended."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
}

# Installation menu
show_install_menu() {
    echo "Select installation type:"
    echo ""
    echo "  1) Standard Install (recommended)"
    echo "     - Install to $INSTALL_DIR"
    echo "     - Set up PATH automatically"
    echo "     - Configure API key"
    echo ""
    echo "  2) System-wide Install (requires sudo)"
    echo "     - Install to /usr/local/bin"
    echo "     - Available to all users"
    echo ""
    echo "  3) Development Install"
    echo "     - Symlink from current directory"
    echo "     - Best for contributors"
    echo ""
    echo "  4) Custom Install"
    echo "     - Choose your own directory"
    echo ""
    echo "  5) Exit"
    echo ""
    read -p "Enter choice [1-5]: " install_choice
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_required=()
    local missing_optional=()
    
    # Required tools
    local required_tools=("curl" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_required+=("$tool")
        fi
    done
    
    # Optional tools
    case "$PLATFORM" in
        linux)
            local optional_tools=("sox" "xclip" "xdotool" "notify-send")
            ;;
        macos)
            local optional_tools=("sox")
            ;;
    esac
    
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_optional+=("$tool")
        fi
    done
    
    # Report findings
    if [ ${#missing_required[@]} -gt 0 ]; then
        error "Missing required tools: ${missing_required[*]}\nPlease install them first."
    fi
    
    if [ ${#missing_optional[@]} -gt 0 ]; then
        warning "Missing optional tools: ${missing_optional[*]}"
        info "Some features may be limited. Install them for full functionality."
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt-get update
            sudo apt-get install -y curl jq sox xclip xdotool libnotify-bin
            ;;
        yum|dnf)
            sudo $PACKAGE_MANAGER install -y curl jq sox xclip xdotool libnotify
            ;;
        pacman)
            sudo pacman -S --noconfirm curl jq sox xclip xdotool libnotify
            ;;
        brew)
            brew install curl jq
            read -p "Install sox for better audio quality? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && brew install sox
            ;;
        *)
            warning "Cannot auto-install dependencies for your system"
            info "Please install manually: curl, jq, sox"
            ;;
    esac
}

# Standard installation
install_standard() {
    log "Performing standard installation..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Copy scripts
    log "Installing scripts to $INSTALL_DIR..."
    cp "$SCRIPT_DIR/transcribe-cross-platform.sh" "$INSTALL_DIR/conduit"
    chmod +x "$INSTALL_DIR/conduit"
    
    # Create convenience symlinks
    ln -sf "$INSTALL_DIR/conduit" "$INSTALL_DIR/transcribe"
    
    # Copy configuration
    if [ ! -f "$CONFIG_DIR/.env" ]; then
        cp "$SCRIPT_DIR/.env.example" "$CONFIG_DIR/.env"
        chmod 600 "$CONFIG_DIR/.env"
    fi
    
    if [ -f "$SCRIPT_DIR/.conduit.yml" ]; then
        cp "$SCRIPT_DIR/.conduit.yml" "$CONFIG_DIR/conduit.yml"
    fi
    
    # Update PATH
    update_path "$INSTALL_DIR"
    
    log "Standard installation complete!"
}

# System-wide installation
install_system() {
    log "Performing system-wide installation..."
    
    if ! sudo -v; then
        error "System-wide installation requires sudo access"
    fi
    
    # Install to /usr/local/bin
    sudo cp "$SCRIPT_DIR/transcribe-cross-platform.sh" /usr/local/bin/conduit
    sudo chmod +x /usr/local/bin/conduit
    sudo ln -sf /usr/local/bin/conduit /usr/local/bin/transcribe
    
    # Create system config directory
    sudo mkdir -p /etc/conduit
    
    # Copy config template
    if [ ! -f /etc/conduit/.env ]; then
        sudo cp "$SCRIPT_DIR/.env.example" /etc/conduit/.env
        sudo chmod 600 /etc/conduit/.env
        warning "Remember to add your API key to /etc/conduit/.env"
    fi
    
    log "System-wide installation complete!"
}

# Development installation
install_development() {
    log "Performing development installation..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR"
    
    # Create symlinks to development directory
    ln -sf "$SCRIPT_DIR/transcribe-cross-platform.sh" "$INSTALL_DIR/conduit"
    ln -sf "$SCRIPT_DIR/transcribe.sh" "$INSTALL_DIR/transcribe-linux"
    
    # Symlink config
    mkdir -p "$CONFIG_DIR"
    ln -sf "$SCRIPT_DIR/.env" "$CONFIG_DIR/.env" 2>/dev/null || true
    ln -sf "$SCRIPT_DIR/.conduit.yml" "$CONFIG_DIR/conduit.yml" 2>/dev/null || true
    
    # Update PATH
    update_path "$INSTALL_DIR"
    
    log "Development installation complete!"
    info "Scripts are symlinked from: $SCRIPT_DIR"
}

# Custom installation
install_custom() {
    read -p "Enter installation directory: " custom_dir
    custom_dir="${custom_dir/#\~/$HOME}"  # Expand tilde
    
    if [ -z "$custom_dir" ]; then
        error "No directory specified"
    fi
    
    INSTALL_DIR="$custom_dir"
    install_standard
}

# Update PATH in shell configuration
update_path() {
    local dir="$1"
    log "Updating PATH..."
    
    # Determine shell config file
    local shell_config=""
    case "${SHELL##*/}" in
        bash)
            shell_config="$HOME/.bashrc"
            [ -f "$HOME/.bash_profile" ] && shell_config="$HOME/.bash_profile"
            ;;
        zsh)
            shell_config="$HOME/.zshrc"
            ;;
        fish)
            shell_config="$HOME/.config/fish/config.fish"
            ;;
        *)
            shell_config="$HOME/.profile"
            ;;
    esac
    
    # Check if already in PATH
    if ! echo "$PATH" | grep -q "$dir"; then
        if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
            # Add to PATH
            echo "" >> "$shell_config"
            echo "# Conduit speech-to-text tool" >> "$shell_config"
            echo "export PATH=\"\$PATH:$dir\"" >> "$shell_config"
            
            info "Added $dir to PATH in $shell_config"
            info "Run 'source $shell_config' or restart your terminal"
        else
            warning "Could not determine shell configuration file"
            info "Add this to your shell configuration: export PATH=\"\$PATH:$dir\""
        fi
    else
        info "Directory already in PATH"
    fi
}

# Configure API key
configure_api_key() {
    log "Configuring API key..."
    
    local env_file="$CONFIG_DIR/.env"
    [ ! -f "$env_file" ] && env_file="$SCRIPT_DIR/.env"
    
    echo ""
    echo "To use Conduit, you need a Groq API key."
    echo "Get one free at: https://console.groq.com/"
    echo ""
    read -p "Do you have a Groq API key? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your API key (starts with gsk_): " api_key
        
        if [[ "$api_key" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
            # Update .env file
            if [ "$PLATFORM" = "macos" ]; then
                sed -i '' "s/your_api_key_here/$api_key/" "$env_file"
            else
                sed -i "s/your_api_key_here/$api_key/" "$env_file"
            fi
            chmod 600 "$env_file"
            log "API key configured successfully!"
        else
            warning "Invalid API key format. Please update $env_file manually."
        fi
    else
        info "You can add your API key later to: $env_file"
    fi
}

# Setup keyboard shortcuts
setup_shortcuts() {
    log "Setting up keyboard shortcuts..."
    
    case "$PLATFORM" in
        linux)
            "$SCRIPT_DIR/install-cross-platform.sh" shortcuts 2>/dev/null || \
            info "Run 'conduit --setup-shortcuts' to configure keyboard shortcuts"
            ;;
        macos)
            info "To set up keyboard shortcuts on macOS:"
            echo "  1. Open System Preferences > Keyboard > Shortcuts"
            echo "  2. Add a new service with command: $INSTALL_DIR/conduit"
            echo "  Or use tools like Raycast, Alfred, or Keyboard Maestro"
            ;;
    esac
}

# Post-installation message
show_completion_message() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║         Installation Complete! 🎉              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    echo "Conduit v$VERSION has been installed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Reload your shell: source ~/.${SHELL##*/}rc"
    echo "  2. Configure API key: $CONFIG_DIR/.env"
    echo "  3. Test the tool: conduit"
    echo ""
    echo "Quick commands:"
    echo "  conduit           - Start transcription"
    echo "  conduit --help    - Show help"
    echo "  conduit --version - Show version"
    echo ""
    echo "For issues or questions:"
    echo "  https://github.com/yourusername/conduit/issues"
    echo ""
}

# Main installation flow
main() {
    # Show banner
    show_banner
    
    # Detect platform
    detect_platform
    
    # Check if running as root
    check_sudo
    
    # Show installation menu
    show_install_menu
    
    case $install_choice in
        1)
            check_prerequisites
            read -p "Install dependencies automatically? (y/N): " -n 1 -r
            echo ""
            [[ $REPLY =~ ^[Yy]$ ]] && install_dependencies
            install_standard
            configure_api_key
            setup_shortcuts
            ;;
        2)
            check_prerequisites
            install_system
            ;;
        3)
            check_prerequisites
            install_development
            configure_api_key
            ;;
        4)
            check_prerequisites
            install_custom
            configure_api_key
            ;;
        5)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
    
    # Show completion message
    show_completion_message
}

# Handle command line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --help|-h)
            echo "Conduit Installer"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --standard    Standard installation"
            echo "  --system      System-wide installation"
            echo "  --dev         Development installation"
            echo "  --uninstall   Run uninstaller"
            echo "  --help        Show this help"
            exit 0
            ;;
        --standard)
            detect_platform
            check_prerequisites
            install_standard
            configure_api_key
            show_completion_message
            exit 0
            ;;
        --system)
            detect_platform
            check_prerequisites
            install_system
            show_completion_message
            exit 0
            ;;
        --dev)
            detect_platform
            check_prerequisites
            install_development
            configure_api_key
            show_completion_message
            exit 0
            ;;
        --uninstall)
            exec "$SCRIPT_DIR/uninstall.sh"
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
else
    # Interactive installation
    main
fi
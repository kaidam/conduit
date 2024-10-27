#!/bin/bash

# Get the directory where conduit.sh is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Installation script
install_dependencies() {
    echo "Installing required dependencies..."
    sudo apt-get update
    sudo apt-get install -y sox curl jq xdotool yad xclip
    
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
    
    # Handle .env file setup
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            chmod 600 "${SCRIPT_DIR}/.env"
            echo "----------------------------------------"
            echo "Created .env file from .env.example"
            echo "You will need a Groq API key to use this tool."
            echo "1. Get your API key from: https://console.groq.com/"
            echo "2. Edit ${SCRIPT_DIR}/.env"
            echo "3. Replace 'your_api_key_here' with your actual Groq API key"
            echo "----------------------------------------"
        else
            echo "GROQ_API_KEY=your_api_key_here" > "${SCRIPT_DIR}/.env"
            chmod 600 "${SCRIPT_DIR}/.env"
            echo "----------------------------------------"
            echo "Created new .env file"
            echo "You will need a Groq API key to use this tool."
            echo "1. Get your API key from: https://console.groq.com/"
            echo "2. Edit ${SCRIPT_DIR}/.env"
            echo "3. Replace 'your_api_key_here' with your actual Groq API key"
            echo "----------------------------------------"
        fi
    else
        echo "Existing .env file found and preserved"
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
    
    case $choice in
        1)
            # Check if gsettings is available
            if ! command -v gsettings &> /dev/null; then
                echo "gsettings not found. Please set up shortcuts manually through System Settings."
                return 1
            fi
            
            # First, ensure the custom keybindings list includes our shortcut
            local CURRENT_LIST=$(gsettings get org.cinnamon.desktop.keybindings custom-list)
            
            # If the list is empty, initialize it with just our binding
            if [ "$CURRENT_LIST" = "@as []" ]; then
                gsettings set org.cinnamon.desktop.keybindings custom-list "['speech']"
            else
                # Remove brackets and quotes from current list
                CURRENT_LIST=${CURRENT_LIST//[\[\]\'\"]/}
                
                # Add our custom keybinding if not present
                if [[ ! $CURRENT_LIST =~ "speech" ]]; then
                    # Properly format the new list
                    NEW_LIST="[$(echo "'$CURRENT_LIST'" | sed "s/,/, /g")${CURRENT_LIST:+, }'speech']"
                    gsettings set org.cinnamon.desktop.keybindings custom-list "$NEW_LIST"
                fi
            fi
            
            # Set up the speech transcription shortcut
            gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ binding "['<Shift><Super>t']"
            gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ command "$HOME/.local/bin/speech-tools/transcribe.sh"
            gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/speech/ name "Speech Transcription"
            
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
            
            if command -v cinnamon-settings &> /dev/null; then
                cinnamon-settings gestures
            elif command -v gnome-control-center &> /dev/null; then
                gnome-control-center gestures
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
                if command -v cinnamon-settings &> /dev/null; then
                    cinnamon-settings keyboard
                elif command -v gnome-control-center &> /dev/null; then
                    gnome-control-center keyboard
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
    # Check if transcribe.sh exists in the same directory
    if [ ! -f "${SCRIPT_DIR}/transcribe.sh" ]; then
        echo "Error: transcribe.sh not found in the same directory as conduit.sh"
        exit 1
    fi
    
    install_dependencies
    setup_shortcuts
    echo "Installation complete! Please restart your terminal or run 'source ~/.bashrc'"
fi

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
    
    # Copy the latest transcribe.sh to the correct location
    echo "Copying latest transcribe.sh to ~/.local/bin/speech-tools/"
    cp "${SCRIPT_DIR}/transcribe.sh" ~/.local/bin/speech-tools/transcribe.sh
    
    # Make script executable
    chmod +x ~/.local/bin/speech-tools/transcribe.sh
    
    # Add to PATH if not already present
    if ! grep -q "speech-tools" ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/.local/bin/speech-tools"' >> ~/.bashrc
    fi
    
    # Handle .env file setup
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            echo "Created .env file from .env.example. Please edit .env and add your Groq API key"
        else
            echo "GROQ_API_KEY=your_api_key_here" > "${SCRIPT_DIR}/.env"
            echo "Created .env file. Please edit it and add your Groq API key"
        fi
        chmod 600 "${SCRIPT_DIR}/.env"
    else
        echo "Existing .env file found and preserved"
    fi
    
    # Create symlink to .env file in speech-tools directory
    ln -sf "${SCRIPT_DIR}/.env" ~/.local/bin/speech-tools/.env
}

# Setup keyboard shortcuts
setup_shortcuts() {
    # Check if gsettings is available
    if ! command -v gsettings &> /dev/null; then
        echo "gsettings not found. Please set up shortcuts manually."
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
    
    echo "Shortcut has been set up. You may need to log out and back in for changes to take effect."
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

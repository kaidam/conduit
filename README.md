# Conduit - Speech-to-Text Transcription Tool

A cross-platform speech-to-text transcription tool that uses the Groq API with Whisper for accurate audio transcription. Originally built for Linux Mint, now supports both Linux and macOS.

## Features

- 🎤 Record audio directly from your microphone
- 🔤 Transcribe speech to text using Groq's Whisper API
- 📋 Automatically copy transcribed text to clipboard
- ⌨️ Auto-paste into the active application (Linux)
- 🔒 Secure API key management
- 🖥️ Cross-platform support (Linux & macOS)

## Prerequisites

- **Groq API Key**: Get one free at [console.groq.com](https://console.groq.com/)
- **Linux**: apt-based distros (Ubuntu, Debian, Mint) or pacman/yum-based distros
- **macOS**: Homebrew package manager (installer will offer to install it)

## Installation

### Quick Install (Cross-Platform)

```bash
# Clone the repository
git clone https://github.com/yourusername/conduit.git
cd conduit

# Run the cross-platform installer
chmod +x install-cross-platform.sh
./install-cross-platform.sh
```

### Linux-Only Install

```bash
# For Linux systems with apt package manager
chmod +x conduit.sh
./conduit.sh
```

### What the installer does:

- ✅ Detects your operating system
- 📦 Installs required dependencies (curl, jq, sox)
- 🔐 Creates secure .env file for API key (permissions 600)
- 🛠️ Sets up shell integration (adds to PATH)
- ⌨️ Offers to configure keyboard shortcuts
- 🎯 Makes all scripts executable

## Dependencies

### Linux
- **Required**: curl, jq, sox
- **Optional**: xdotool (auto-paste), xclip (clipboard), notify-send (notifications)

### macOS
- **Required**: curl, jq
- **Optional**: sox (better recording quality, otherwise uses QuickTime)

## Usage

### Running the Tool

```bash
# Cross-platform version
transcribe-cross-platform.sh

# Or Linux-specific version
transcribe.sh
```

### How it Works

1. **Start Recording**: Run the script or use your configured keyboard shortcut
2. **Speak**: Talk naturally into your microphone
3. **Stop Recording**: Press `Ctrl+C` to stop recording
4. **Automatic Processing**: 
   - Audio is sent to Groq API for transcription
   - Text is copied to your clipboard
   - On Linux: Text is auto-pasted to the active window
   - On macOS: Use `Cmd+V` to paste

### Keyboard Shortcuts

#### Linux
- Default: `Shift+Super+T`
- Configure via System Settings > Keyboard > Shortcuts

#### macOS
- Set up via System Preferences > Keyboard > Shortcuts > Services
- Or use tools like Raycast, Alfred, or Keyboard Maestro

## Configuration

### API Key Setup

1. Get your API key from [Groq Console](https://console.groq.com/)
2. Edit the `.env` file in the project directory
3. Replace `your_api_key_here` with your actual API key

Your API key should look like: `gsk_xxxxxxxxxx...`

### Security Notes

- The `.env` file is automatically secured with 600 permissions
- Never commit your `.env` file to version control
- The `.env` file is already in `.gitignore`
- Regenerate your API key if you suspect it's compromised

## Troubleshooting

### Linux Issues
- **"Command not found"**: Run `source ~/.bashrc` or restart terminal
- **No audio recording**: Check microphone permissions and sox installation
- **Auto-paste not working**: Install xdotool: `sudo apt-get install xdotool`

### macOS Issues
- **"Command not found"**: Run `source ~/.zshrc` or restart terminal
- **Poor recording quality**: Install sox with `brew install sox`
- **Notifications not showing**: Check System Preferences > Notifications

### Common Issues
- **Invalid API key**: Ensure your key starts with `gsk_` and is 56 characters
- **Rate limit exceeded**: Wait a few minutes and try again
- **No transcription**: Check internet connection and API key validity

## Files

- `transcribe-cross-platform.sh` - Main cross-platform transcription script
- `install-cross-platform.sh` - Cross-platform installer
- `conduit.sh` - Original Linux installer
- `transcribe.sh` - Original Linux-only script
- `.env.example` - Template for API configuration
- `.env` - Your API key configuration (not in version control)

## License

MIT License - See LICENSE file for details

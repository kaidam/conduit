# Conduit - Enhanced Cross-Platform Speech-to-Text Transcription Tool

A robust, cross-platform Linux speech-to-text transcription tool that works across multiple distributions and desktop environments. This enhanced version provides automatic detection and configuration for various Linux setups.

## ✨ What's New in the Enhanced Version

### 🐧 **Multi-Distribution Support**
- **Automatic package manager detection**: Works with apt, dnf, yum, pacman, zypper, emerge, and apk
- **Cross-distro compatibility**: Tested on Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, Gentoo, and Alpine
- **Smart dependency installation**: Automatically installs required packages using your system's package manager

### 🎵 **Enhanced Audio System Support**
- **Multi-audio-system compatibility**: Supports PipeWire, PulseAudio, and ALSA
- **Automatic audio detection**: Detects and uses the best available recording method
- **Fallback recording options**: Multiple recording backends (pw-record, parecord, arecord, sox)
- **Robust audio handling**: Better error handling and audio format optimization

### 🖥️ **Expanded Desktop Environment Support**
- **Universal DE compatibility**: GNOME, KDE/Plasma, XFCE, Cinnamon, MATE, LXDE/LXQt
- **Automatic shortcut setup**: Intelligent detection and configuration for each desktop environment
- **Gesture support**: Enhanced touchpad gesture configuration across different DEs
- **Fallback options**: Manual setup instructions when automatic configuration isn't available

### 🔧 **Improved User Experience**
- **Colored logging**: Clear, informative output with color-coded messages
- **Better notifications**: Multi-method notification support (notify-send, kdialog, zenity, xmessage)
- **Enhanced error handling**: Comprehensive error checking and user feedback
- **Multiple clipboard support**: Works with both X11 (xclip) and Wayland (wl-copy)
- **Input method fallback**: Supports both xdotool and ydotool for text input

## 📋 Requirements

### Minimum Requirements
- Linux operating system (any distribution)
- Bash shell
- Internet connection for API calls
- Groq API key (free at [console.groq.com](https://console.groq.com/))

### Audio Requirements (one of these will be automatically detected):
- **PipeWire**: `pipewire` + `pw-record`
- **PulseAudio**: `pulseaudio` + `parecord`
- **ALSA**: `alsa-utils` (arecord)
- **SOX**: `sox` package

## 🚀 Installation Instructions

### Quick Installation

1. **Clone or download the repository:**
   ```bash
   git clone <repository-url>
   cd conduit
   ```

2. **Make the installer executable:**
   ```bash
   chmod +x conduit.sh
   ```

3. **Run the enhanced installer:**
   ```bash
   ./conduit.sh
   ```

4. **Follow the interactive setup:**
   - The script will detect your Linux distribution and package manager
   - Install required dependencies automatically
   - Set up your Groq API key
   - Configure keyboard shortcuts or gestures for your desktop environment

5. **Restart your terminal:**
   ```bash
   source ~/.bashrc
   ```

### Manual Installation (if automatic fails)

If the automatic installation doesn't work for your system:

1. **Install dependencies manually:**
   
   **For Debian/Ubuntu:**
   ```bash
   sudo apt update
   sudo apt install sox curl jq xdotool yad xclip
   ```
   
   **For Fedora/RHEL:**
   ```bash
   sudo dnf install sox curl jq xdotool yad xclip
   ```
   
   **For Arch Linux:**
   ```bash
   sudo pacman -S sox curl jq xdotool yad xclip
   ```
   
   **For openSUSE:**
   ```bash
   sudo zypper install sox curl jq xdotool yad xclip
   ```

2. **Set up the scripts:**
   ```bash
   mkdir -p ~/.local/bin/speech-tools
   cp transcribe.sh ~/.local/bin/speech-tools/
   chmod +x ~/.local/bin/speech-tools/transcribe.sh
   echo 'export PATH="$PATH:$HOME/.local/bin/speech-tools"' >> ~/.bashrc
   ```

3. **Configure API key:**
   ```bash
   cp .env.example .env
   # Edit .env and add your Groq API key
   ```

## ⚙️ Configuration

### API Key Setup

1. **Get your Groq API key:**
   - Visit [console.groq.com](https://console.groq.com/)
   - Create a free account
   - Generate an API key

2. **Configure the key:**
   ```bash
   # Edit the .env file in your installation directory
   nano .env
   # Replace 'your_api_key_here' with your actual API key
   ```

### Keyboard Shortcuts

The installer will automatically configure shortcuts based on your desktop environment:

| Desktop Environment | Method | Default Shortcut |
|-------------------|---------|------------------|
| GNOME/Ubuntu | gsettings | Shift+Super+T |
| KDE/Plasma | Manual setup required | (custom) |
| XFCE | xfconf-query | Shift+Super+T |
| Cinnamon | gsettings | Shift+Super+T |
| MATE | gsettings | Shift+Super+T |
| LXDE/LXQt | Manual setup required | (custom) |

### Gesture Configuration

For touchpad gestures, the installer will guide you to your system's gesture settings:
- **GNOME**: Settings → Gestures
- **KDE**: System Settings → Touchpad
- **Other DEs**: Check your system settings for gesture/touchpad configuration

## 🎯 Usage

### Basic Usage

1. **Use your configured shortcut** (default: Shift+Super+T) to start recording
2. **Speak clearly** into your microphone
3. **Stop recording** by clicking the system tray icon or closing the progress dialog
4. **Text is automatically pasted** into your active application

### Command Line Usage

You can also run the transcription tool directly:

```bash
# Run from anywhere (after installation)
transcribe.sh

# Or run directly
~/.local/bin/speech-tools/transcribe.sh
```

### Tips for Best Results

- **Speak clearly** and at a normal pace
- **Use a good microphone** or headset for better audio quality
- **Minimize background noise** when possible
- **Ensure stable internet connection** for API calls

## 🔧 Troubleshooting

### Common Issues

**"No audio recording method found"**
- Install audio utilities: `sudo apt install sox pulseaudio-utils` (or equivalent for your distro)
- Check if your audio system is running: `pulseaudio --check -v` or `pipewire --version`

**"API key not found"**
- Verify your `.env` file exists and contains your Groq API key
- Check file permissions: `chmod 600 .env`

**"No text was transcribed"**
- Ensure you have a working microphone
- Test audio recording: `arecord -d 5 test.wav && aplay test.wav`
- Check internet connection and API key validity

**Shortcut not working**
- Try logging out and back in
- Manually set up shortcuts through System Settings
- Check if the transcribe.sh script is executable: `chmod +x ~/.local/bin/speech-tools/transcribe.sh`

### Audio System Issues

**For PipeWire users:**
```bash
# Check PipeWire status
systemctl --user status pipewire

# Install PipeWire tools if missing
sudo apt install pipewire-audio-client-libraries pipewire-pulse
```

**For PulseAudio users:**
```bash
# Restart PulseAudio if needed
pulseaudio --kill && pulseaudio --start

# Check audio devices
pactl list sources short
```

**For ALSA users:**
```bash
# Test ALSA recording
arecord -l  # List recording devices
arecord -d 5 -f cd test.wav  # Test recording
```

## 🤝 Contributing

Contributions are welcome! This enhanced version is designed to be more maintainable and extensible:

- **Add support for new distributions**: Extend the package manager detection
- **Improve desktop environment support**: Add configuration for additional DEs
- **Enhance audio handling**: Add support for more audio systems
- **Bug fixes and improvements**: Always appreciated

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original concept and implementation
- Enhanced cross-platform compatibility
- Community feedback and testing across various Linux distributions

## 🔗 Links

- [Groq API Documentation](https://console.groq.com/docs)
- [Report Issues](https://github.com/your-repo/issues)
- [Latest Releases](https://github.com/your-repo/releases)

---

**Note**: This enhanced version maintains backward compatibility while significantly expanding platform support. If you encounter any issues with your specific Linux setup, please report them so we can continue improving cross-platform compatibility.

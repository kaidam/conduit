# Conduit - Speech-to-Text Transcription Tool

Hey, this is my first public project. This was made for me to use on my Linux Mint machines, should in theory work with Ubuntu, but I make no promises. You just need a Groq API key and you should be good to go. I made this for me and makes assumptions about my system. I might make it more universal in the future!

## Installation Instructions

1. Clone the repository or download the `conduit.sh` and `transcribe.sh` files.

2. Open a terminal and navigate to the directory containing the scripts.

3. Make the `conduit.sh` script executable:
   ```
   chmod +x conduit.sh
   ```

4. Run the installation script:
   ```
   ./conduit.sh
   ```

5. The script will:
   - Install required dependencies (sox, curl, jq, xdotool, yad, xclip)
   - Create necessary directories
   - Set up symlinks
   - Create a `.env` file for your Groq API key
   - Offer to set up keyboard shortcuts or gestures

6. Follow the prompts to complete the setup:
   - Choose how you want to set up shortcuts (default, gesture, manual, or skip)
   - If prompted, enter your Groq API key in the `.env` file

7. Restart your terminal or run `source ~/.bashrc` to apply changes.

8. You're all set! You can now use the speech-to-text transcription tool.

## Usage

- Use the configured keyboard shortcut (default: Shift+Super+T) or gesture to start transcription.
- Speak clearly into your microphone.
- The transcribed text will be automatically pasted into your active text field.

For more detailed information, refer to the comments in the `conduit.sh` and `transcribe.sh` files.

#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Global variables for cleanup
TEMP_FILES=()
PIDS_TO_KILL=()
CLEANUP_DONE=0
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
    
    echo "✓ Detected platform: $PLATFORM"
}

# Cleanup function
cleanup() {
    # Prevent double cleanup
    if [ "$CLEANUP_DONE" -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1
    
    local exit_code=$?
    
    # Kill any running processes
    if [ ${#PIDS_TO_KILL[@]} -gt 0 ]; then
        for pid in "${PIDS_TO_KILL[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                wait "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Remove temporary files
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        for file in "${TEMP_FILES[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file" 2>/dev/null || true
            fi
        done
    fi
    
    # Show error notification if script failed
    if [ $exit_code -ne 0 ] && [ $exit_code -ne 130 ]; then  # 130 is Ctrl+C
        show_notification "Error" "Transcription failed. Check the terminal for details."
    fi
    
    exit $exit_code
}

# Set up cleanup trap for all exit scenarios
trap cleanup EXIT INT TERM HUP

# Error handler
error_exit() {
    local line_no=$1
    local exit_code=$2
    echo "Error on line $line_no: Command exited with status $exit_code" >&2
    exit $exit_code
}

# Set up error trap
trap 'error_exit $LINENO $?' ERR

# Platform-specific notification function
show_notification() {
    local title="$1"
    local message="$2"
    
    case "$PLATFORM" in
        linux)
            if command -v notify-send &> /dev/null; then
                notify-send "$title" "$message"
            else
                echo "[$title] $message"
            fi
            ;;
        macos)
            osascript -e "display notification \"$message\" with title \"$title\""
            ;;
        *)
            echo "[$title] $message"
            ;;
    esac
}

# Platform-specific clipboard copy function
copy_to_clipboard() {
    local text="$1"
    
    case "$PLATFORM" in
        linux)
            if command -v xclip &> /dev/null; then
                echo -n "$text" | xclip -selection clipboard
            elif command -v xsel &> /dev/null; then
                echo -n "$text" | xsel --clipboard
            else
                echo "Error: No clipboard tool found (xclip or xsel)"
                return 1
            fi
            ;;
        macos)
            echo -n "$text" | pbcopy
            ;;
        *)
            echo "Error: Clipboard not supported on this platform"
            return 1
            ;;
    esac
}

# Platform-specific paste function
paste_text() {
    case "$PLATFORM" in
        linux)
            if command -v xdotool &> /dev/null; then
                xdotool key --clearmodifiers ctrl+v
            else
                echo "Warning: xdotool not found, cannot auto-paste"
                show_notification "Info" "Text copied to clipboard - use Ctrl+V to paste"
            fi
            ;;
        macos)
            # Use AppleScript to paste
            osascript -e 'tell application "System Events" to keystroke "v" using command down'
            ;;
        *)
            echo "Warning: Auto-paste not supported on this platform"
            ;;
    esac
}

# Platform-specific audio recording function
record_audio() {
    local output_file="$1"
    
    case "$PLATFORM" in
        linux)
            if ! command -v rec &> /dev/null; then
                echo "Error: 'rec' command not found. Please install 'sox'."
                exit 1
            fi
            
            show_notification "Recording Started" "Press Ctrl+C to stop recording"
            
            # Record with timeout
            timeout --preserve-status 120 rec "$output_file" rate 16k &
            local REC_PID=$!
            PIDS_TO_KILL+=("$REC_PID")
            
            # Wait for recording to finish
            wait $REC_PID || true
            
            # Remove from kill list
            PIDS_TO_KILL=("${PIDS_TO_KILL[@]/$REC_PID}")
            ;;
            
        macos)
            # Check for sox/rec first (preferred)
            if command -v rec &> /dev/null; then
                show_notification "Recording Started" "Press Ctrl+C to stop recording"
                
                # Use rec if available
                rec "$output_file" rate 16k &
                local REC_PID=$!
                PIDS_TO_KILL+=("$REC_PID")
                
                # Wait for recording (with 2 minute timeout using a different method on macOS)
                local count=0
                while kill -0 $REC_PID 2>/dev/null && [ $count -lt 120 ]; do
                    sleep 1
                    ((count++))
                done
                
                if kill -0 $REC_PID 2>/dev/null; then
                    kill $REC_PID
                    show_notification "Warning" "Recording stopped after 2 minutes timeout"
                fi
                
                wait $REC_PID || true
                PIDS_TO_KILL=("${PIDS_TO_KILL[@]/$REC_PID}")
            else
                # Fallback to using built-in macOS recording (requires user interaction)
                show_notification "Recording" "Using system audio recording. Press Stop when done."
                
                # Create a temporary AIFF file (macOS native format)
                local temp_aiff="${output_file%.wav}.aiff"
                
                # Use afrecord (Audio File Record) if available, or use a simple osascript solution
                if command -v afrecord &> /dev/null; then
                    afrecord -f 'WAVE' -r 16000 "$output_file"
                else
                    # Use QuickTime Player via AppleScript as fallback
                    osascript <<EOF
tell application "QuickTime Player"
    set newRecording to new audio recording
    start newRecording
    delay 1
    display dialog "Click Stop when you're done recording" buttons {"Stop"} default button "Stop"
    stop newRecording
    export newRecording in POSIX file "$output_file" using settings preset "Audio Only"
    close newRecording without saving
end tell
EOF
                fi
            fi
            ;;
            
        *)
            echo "Error: Audio recording not supported on this platform"
            exit 1
            ;;
    esac
}

# Check for required tools based on platform
check_requirements() {
    local missing_tools=()
    
    case "$PLATFORM" in
        linux)
            local required_tools=("curl" "jq")
            local optional_tools=("rec" "notify-send" "xclip" "xdotool")
            
            for tool in "${required_tools[@]}"; do
                if ! command -v "$tool" &> /dev/null; then
                    missing_tools+=("$tool")
                fi
            done
            
            if [ ${#missing_tools[@]} -gt 0 ]; then
                echo "Error: Missing required tools: ${missing_tools[*]}"
                echo "Please install them first."
                exit 1
            fi
            
            for tool in "${optional_tools[@]}"; do
                if ! command -v "$tool" &> /dev/null; then
                    echo "Warning: Optional tool '$tool' not found. Some features may be limited."
                fi
            done
            ;;
            
        macos)
            local required_tools=("curl" "jq")
            
            for tool in "${required_tools[@]}"; do
                if ! command -v "$tool" &> /dev/null; then
                    missing_tools+=("$tool")
                fi
            done
            
            if [ ${#missing_tools[@]} -gt 0 ]; then
                echo "Error: Missing required tools: ${missing_tools[*]}"
                echo "Install them using Homebrew:"
                echo "  brew install ${missing_tools[*]}"
                exit 1
            fi
            
            # Check for optional sox
            if ! command -v rec &> /dev/null; then
                echo "Note: 'sox' not found. Install with 'brew install sox' for better recording."
            fi
            ;;
    esac
}

# Secure API Key Loading and Validation
load_and_validate_api_key() {
    local env_file="$(dirname "$0")/.env"
    
    # Check if .env file exists
    if [ ! -f "$env_file" ]; then
        show_notification "Error" ".env file not found. Please run installer first."
        exit 1
    fi
    
    # Check file permissions (should be 600 for security)
    if [ "$PLATFORM" = "linux" ]; then
        local perms=$(stat -c %a "$env_file" 2>/dev/null)
    elif [ "$PLATFORM" = "macos" ]; then
        local perms=$(stat -f %A "$env_file" 2>/dev/null)
    fi
    
    if [ -n "${perms:-}" ] && [ "$perms" != "600" ]; then
        echo "Warning: .env file permissions are not secure. Fixing..."
        chmod 600 "$env_file"
    fi
    
    # Source the file in a subshell to avoid pollution
    GROQ_API_KEY=$(grep -E '^GROQ_API_KEY=' "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    # Remove any whitespace
    GROQ_API_KEY="${GROQ_API_KEY// /}"
    
    # Validate API key format (Groq keys start with 'gsk_' and are 56 chars total)
    if [ -z "$GROQ_API_KEY" ]; then
        show_notification "Error" "API key not found in .env file"
        exit 1
    elif [ "$GROQ_API_KEY" = "your_api_key_here" ]; then
        show_notification "Error" "Please replace 'your_api_key_here' with your actual Groq API key"
        exit 1
    elif [[ ! "$GROQ_API_KEY" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
        show_notification "Warning" "API key format appears invalid. Groq keys should start with 'gsk_'"
        # Don't exit here as the format might change
    fi
    
    # Export for use in functions
    export GROQ_API_KEY
}

# Record audio and transcribe
record_and_transcribe() {
    local TEMP_AUDIO=$(mktemp --suffix=.wav 2>/dev/null || mktemp -t 'audio.XXXXXX.wav')
    local TEMP_TEXT=$(mktemp 2>/dev/null || mktemp -t 'text.XXXXXX')
    local TEMP_RESPONSE=$(mktemp 2>/dev/null || mktemp -t 'response.XXXXXX')
    
    # Register temp files for cleanup
    TEMP_FILES+=("$TEMP_AUDIO" "$TEMP_TEXT" "$TEMP_RESPONSE")
    
    # Check if API key exists
    if [ -z "$GROQ_API_KEY" ]; then
        show_notification "Error" "Groq API key not found. Please check your .env file"
        return 1
    fi
    
    # Record audio
    echo "Recording audio... Press Ctrl+C to stop"
    record_audio "$TEMP_AUDIO"
    
    # Check if audio file was created and has content
    if [ ! -s "$TEMP_AUDIO" ]; then
        show_notification "Error" "No audio was recorded"
        return 1
    fi
    
    echo "Processing audio file..."
    show_notification "Processing" "Transcribing audio..."
    
    # Securely call Groq API with proper escaping and error handling
    local http_code
    http_code=$(curl -s -w "\n%{http_code}" -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
        -H "Authorization: Bearer ${GROQ_API_KEY}" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@${TEMP_AUDIO}" \
        -F "model=whisper-large-v3" \
        -F "response_format=json" \
        -F "language=en" \
        --max-time 30 \
        -o "$TEMP_RESPONSE")
    
    # Check HTTP response code
    if [ "$http_code" != "200" ]; then
        local error_msg="API request failed (HTTP $http_code)"
        
        # Try to extract error message from response
        if [ -f "$TEMP_RESPONSE" ]; then
            local api_error=$(jq -r '.error.message // .error // .message // empty' "$TEMP_RESPONSE" 2>/dev/null)
            if [ -n "$api_error" ]; then
                error_msg="$error_msg: $api_error"
            fi
        fi
        
        # Check for common error codes
        case "$http_code" in
            401) show_notification "Error" "Invalid API key. Please check your .env file" ;;
            429) show_notification "Error" "Rate limit exceeded. Please try again later" ;;
            500|502|503) show_notification "Error" "Groq service temporarily unavailable" ;;
            *) show_notification "Error" "$error_msg" ;;
        esac
        
        return 1
    fi
    
    # Extract the text from the response with error checking
    local transcribed_text
    transcribed_text=$(jq -r '.text // empty' "$TEMP_RESPONSE" 2>/dev/null)
    
    if [ -z "$transcribed_text" ]; then
        # Try to get error message
        local error_detail=$(jq -r '.error.message // .error // "Unknown error"' "$TEMP_RESPONSE" 2>/dev/null)
        show_notification "Error" "Transcription failed: $error_detail"
        return 1
    fi
    
    # Save transcribed text
    echo "$transcribed_text" > "$TEMP_TEXT"
    
    # Copy to clipboard
    if ! copy_to_clipboard "$transcribed_text"; then
        show_notification "Error" "Failed to copy to clipboard"
        return 1
    fi
    
    show_notification "Success" "Text copied to clipboard"
    
    # Try to paste (platform-specific)
    echo "Attempting to paste text..."
    paste_text
    
    # Show the transcribed text in terminal
    echo ""
    echo "Transcribed text:"
    echo "=================="
    echo "$transcribed_text"
    echo "=================="
    
    return 0
}

# Main execution with error handling
main() {
    # Detect platform
    detect_platform
    
    # Check requirements
    check_requirements
    
    # Load and validate API key
    load_and_validate_api_key
    
    # Run transcription
    set +e
    record_and_transcribe
    local result=$?
    set -e
    
    if [ $result -eq 0 ]; then
        exit 0
    else
        exit $result
    fi
}

# Run main function
main
#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Global variables for cleanup
TEMP_FILES=()
PIDS_TO_KILL=()
CLEANUP_DONE=0

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
        notify-send "Error" "Transcription failed. Check the terminal for details." 2>/dev/null || true
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

# OS Detection - Exit early if not on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]] && [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script requires Linux with X11 window system"
    echo "Detected OS: $OSTYPE"
    exit 1
fi

# Check for required commands
for cmd in xdotool xprop sox curl jq xclip notify-send; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found"
        echo "Please run the installer script first: ./conduit.sh"
        exit 1
    fi
done

# Store the original window ID before anything else
ORIGINAL_WINDOW_ID=$(xdotool getactivewindow)

# Get window info using xprop directly since it's more reliable
WINDOW_PROPS=$(xprop -id $ORIGINAL_WINDOW_ID 2>/dev/null)

# More specific check for text input windows
ORIGINAL_HAD_FOCUS=$(echo "$WINDOW_PROPS" | grep 'WM_CLASS' | grep -i 'cursor' && echo "yes" || echo "no")

# Secure API Key Loading and Validation
load_and_validate_api_key() {
    local env_file="$(dirname "$0")/.env"
    
    # Check if .env file exists
    if [ ! -f "$env_file" ]; then
        notify-send "Error" ".env file not found. Please run installer first."
        exit 1
    fi
    
    # Check file permissions (should be 600 for security)
    local perms=$(stat -c %a "$env_file" 2>/dev/null || stat -f %A "$env_file" 2>/dev/null)
    if [ "$perms" != "600" ]; then
        echo "Warning: .env file permissions are not secure. Fixing..."
        chmod 600 "$env_file"
    fi
    
    # Source the file in a subshell to avoid pollution
    GROQ_API_KEY=$(grep -E '^GROQ_API_KEY=' "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    # Remove any whitespace
    GROQ_API_KEY="${GROQ_API_KEY// /}"
    
    # Validate API key format (Groq keys start with 'gsk_' and are 56 chars total)
    if [ -z "$GROQ_API_KEY" ]; then
        notify-send "Error" "API key not found in .env file"
        exit 1
    elif [ "$GROQ_API_KEY" = "your_api_key_here" ]; then
        notify-send "Error" "Please replace 'your_api_key_here' with your actual Groq API key"
        exit 1
    elif [[ ! "$GROQ_API_KEY" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
        notify-send "Warning" "API key format appears invalid. Groq keys should start with 'gsk_'"
        # Don't exit here as the format might change
    fi
    
    # Export for use in functions
    export GROQ_API_KEY
}

# Load and validate API key
load_and_validate_api_key

# Record audio and transcribe
record_and_transcribe() {
    local TEMP_AUDIO=$(mktemp --suffix=.wav)
    local TEMP_TEXT=$(mktemp)
    local TEMP_RESPONSE=$(mktemp)
    
    # Register temp files for cleanup
    TEMP_FILES+=("$TEMP_AUDIO" "$TEMP_TEXT" "$TEMP_RESPONSE")
    
    # Check if API key exists
    if [ -z "$GROQ_API_KEY" ]; then
        notify-send "Error" "Groq API key not found. Please check your .env file"
        return 1
    fi
    
    # Show notification about recording
    notify-send "Recording Started" "Click the microphone icon in system tray to stop"
    
    # Start recording in background with timeout
    timeout --preserve-status 120 rec "$TEMP_AUDIO" rate 16k &
    local REC_PID=$!
    PIDS_TO_KILL+=("$REC_PID")
    
    # Create system tray icon with yad
    yad --notification \
        --image=audio-input-microphone \
        --text="Recording in progress. Click to stop." \
        --command="kill $REC_PID" &
    local YAD_PID=$!
    PIDS_TO_KILL+=("$YAD_PID")
    
    # Wait for recording to finish (with interrupt handling)
    if ! wait $REC_PID; then
        local rec_exit=$?
        if [ $rec_exit -eq 143 ]; then  # SIGTERM from timeout
            notify-send "Warning" "Recording stopped after 2 minutes timeout"
        elif [ $rec_exit -ne 0 ] && [ $rec_exit -ne 143 ]; then
            notify-send "Error" "Recording failed"
            return 1
        fi
    fi
    
    # Remove from kill list since it's already done
    PIDS_TO_KILL=("${PIDS_TO_KILL[@]/$REC_PID}")
    
    # Kill the yad notification
    if kill -0 "$YAD_PID" 2>/dev/null; then
        kill "$YAD_PID" 2>/dev/null || true
        wait "$YAD_PID" 2>/dev/null || true
    fi
    PIDS_TO_KILL=("${PIDS_TO_KILL[@]/$YAD_PID}")
    
    # Check if audio file was created and has content
    if [ ! -s "$TEMP_AUDIO" ]; then
        notify-send "Error" "No audio was recorded"
        return 1
    fi
    
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
            401) notify-send "Error" "Invalid API key. Please check your .env file" ;;
            429) notify-send "Error" "Rate limit exceeded. Please try again later" ;;
            500|502|503) notify-send "Error" "Groq service temporarily unavailable" ;;
            *) notify-send "Error" "$error_msg" ;;
        esac
        
        return 1
    fi
    
    # Extract the text from the response with error checking
    local transcribed_text
    transcribed_text=$(jq -r '.text // empty' "$TEMP_RESPONSE" 2>/dev/null)
    
    if [ -z "$transcribed_text" ]; then
        # Try to get error message
        local error_detail=$(jq -r '.error.message // .error // "Unknown error"' "$TEMP_RESPONSE" 2>/dev/null)
        notify-send "Error" "Transcription failed: $error_detail"
        return 1
    fi
    
    # Save transcribed text
    echo "$transcribed_text" > "$TEMP_TEXT"
    
    # Copy to clipboard and paste
    if ! cat "$TEMP_TEXT" | xclip -selection c; then
        notify-send "Error" "Failed to copy to clipboard"
        return 1
    fi
    
    # Restore focus and paste with error handling
    if ! xdotool windowactivate --sync "$ORIGINAL_WINDOW_ID"; then
        notify-send "Warning" "Could not restore window focus"
        notify-send "Info" "Text copied to clipboard - use Ctrl+V to paste"
        return 0
    fi
    
    sleep 0.1  # Small delay to ensure window is focused
    
    if ! xdotool key --clearmodifiers ctrl+v; then
        notify-send "Warning" "Could not auto-paste"
        notify-send "Info" "Text copied to clipboard - use Ctrl+V to paste"
    fi
    
    # Cleanup is handled by trap, no need to manually remove files
    return 0
}

# Main execution with error handling
main() {
    # Temporarily disable error trap for this check
    set +e
    record_and_transcribe
    local result=$?
    set -e
    
    if [ $result -eq 0 ]; then
        # Success notification (optional, can be commented out)
        # notify-send "Success" "Transcription completed"
        exit 0
    else
        exit $result
    fi
}

# Run main function
main

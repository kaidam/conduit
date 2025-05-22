#!/bin/bash

# Enhanced Transcribe - Cross-platform Linux speech-to-text transcription
# Compatible with multiple audio systems and desktop environments

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Store the original window ID before anything else
ORIGINAL_WINDOW_ID=""
if command -v xdotool >/dev/null 2>&1; then
    ORIGINAL_WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
fi

# Source the API key from .env file
source_env_file() {
    local env_file=""
    
    # Try multiple locations for .env file
    for location in "$(dirname "$0")/.env" "$HOME/.local/bin/speech-tools/.env" "$HOME/.config/conduit/.env"; do
        if [ -f "$location" ]; then
            env_file="$location"
            break
        fi
    done
    
    if [ -n "$env_file" ]; then
        source "$env_file"
        log_info "Loaded configuration from $env_file"
    else
        show_notification "Error" ".env file not found in any expected location"
        log_error ".env file not found. Checked locations:"
        log_error "  - $(dirname "$0")/.env"
        log_error "  - $HOME/.local/bin/speech-tools/.env"
        log_error "  - $HOME/.config/conduit/.env"
        exit 1
    fi
}

# Cross-platform notification function
show_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    # Try different notification methods
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$message"
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --passivepopup "$message" 5
    elif command -v zenity >/dev/null 2>&1; then
        zenity --info --title="$title" --text="$message" --timeout=5
    elif command -v xmessage >/dev/null 2>&1; then
        echo "$title: $message" | xmessage -file - -timeout 5
    else
        # Fallback to terminal output
        log_info "NOTIFICATION: $title - $message"
    fi
}

# Detect audio system and recording method
detect_audio_system() {
    local audio_system=""
    local recording_method=""
    
    # Check for PipeWire first (newest)
    if command -v pw-record >/dev/null 2>&1 && pgrep -x pipewire >/dev/null 2>&1; then
        audio_system="pipewire"
        recording_method="pw-record"
    # Check for PulseAudio
    elif command -v parecord >/dev/null 2>&1 && (pgrep -x pulseaudio >/dev/null 2>&1 || pgrep -x pipewire-pulse >/dev/null 2>&1); then
        audio_system="pulseaudio"
        recording_method="parecord"
    # Check for ALSA with arecord
    elif command -v arecord >/dev/null 2>&1; then
        audio_system="alsa"
        recording_method="arecord"
    # Fallback to sox (if available)
    elif command -v rec >/dev/null 2>&1; then
        audio_system="sox"
        recording_method="rec"
    else
        audio_system="unknown"
        recording_method="unknown"
    fi
    
    log_info "Detected audio system: $audio_system (using $recording_method)"
    echo "$recording_method"
}

# Record audio using the best available method
record_audio() {
    local output_file="$1"
    local recording_method="$2"
    local duration="${3:-300}" # Default 5 minutes max
    
    case "$recording_method" in
        "pw-record")
            # PipeWire
            timeout "$duration" pw-record --format=s16 --rate=16000 --channels=1 "$output_file" &
            ;;
        "parecord")
            # PulseAudio
            timeout "$duration" parecord --format=s16le --rate=16000 --channels=1 "$output_file" &
            ;;
        "arecord")
            # ALSA
            timeout "$duration" arecord -f S16_LE -r 16000 -c 1 "$output_file" &
            ;;
        "rec")
            # SOX
            timeout "$duration" rec "$output_file" rate 16k &
            ;;
        *)
            log_error "No suitable recording method found"
            return 1
            ;;
    esac
    
    return $!
}

# Create system tray notification with recording status
create_recording_indicator() {
    local rec_pid="$1"
    
    # Try yad first (best option with system tray)
    if command -v yad >/dev/null 2>&1; then
        yad --notification \
            --image=audio-input-microphone \
            --text="Recording in progress. Click to stop." \
            --command="kill $rec_pid" \
            --no-middle &
        return $!
    
    # Try zenity with progress dialog
    elif command -v zenity >/dev/null 2>&1; then
        (
            echo "10"; sleep 1
            while kill -0 "$rec_pid" 2>/dev/null; do
                echo "# Recording in progress... (Close this dialog to stop)"
                sleep 1
            done
            echo "100"
        ) | zenity --progress --title="Speech Recording" --text="Recording..." --percentage=10 --auto-close &
        local zenity_pid=$!
        
        # Monitor zenity and kill recording if closed
        (
            wait $zenity_pid
            if kill -0 "$rec_pid" 2>/dev/null; then
                kill "$rec_pid"
            fi
        ) &
        
        return $zenity_pid
    
    # Fallback to kdialog
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --title "Recording" --passivepopup "Recording in progress. Press Ctrl+C in terminal to stop." 10 &
        return $!
    
    # Fallback notification only
    else
        show_notification "Recording Started" "Recording in progress. Check terminal for stop instructions."
        return 0
    fi
}

# Get the best available text input tool
get_text_input_method() {
    if command -v xdotool >/dev/null 2>&1; then
        echo "xdotool"
    elif command -v ydotool >/dev/null 2>&1; then
        echo "ydotool"
    else
        echo "none"
    fi
}

# Paste text using the best available method
paste_text() {
    local text="$1"
    local input_method="$(get_text_input_method)"
    
    # Copy to clipboard first
    if command -v xclip >/dev/null 2>&1; then
        echo "$text" | xclip -selection clipboard
    elif command -v wl-copy >/dev/null 2>&1; then
        echo "$text" | wl-copy
    else
        log_warning "No clipboard utility found"
    fi
    
    # Paste using input method
    case "$input_method" in
        "xdotool")
            if [ -n "$ORIGINAL_WINDOW_ID" ]; then
                xdotool windowactivate --sync "$ORIGINAL_WINDOW_ID"
                sleep 0.2
                xdotool key --clearmodifiers ctrl+v
            else
                log_warning "No original window ID captured"
                xdotool key --clearmodifiers ctrl+v
            fi
            ;;
        "ydotool")
            sleep 0.2
            ydotool key 29:1 47:1 47:0 29:0  # Ctrl+V
            ;;
        "none")
            show_notification "Text Ready" "Transcribed text is in clipboard. Paste with Ctrl+V"
            log_info "Transcribed text: $text"
            ;;
    esac
}

# Validate API response
validate_api_response() {
    local response_file="$1"
    
    if [ ! -s "$response_file" ]; then
        log_error "Empty response from API"
        return 1
    fi
    
    # Check for error in response
    if command -v jq >/dev/null 2>&1; then
        local error_msg=$(jq -r '.error.message // empty' "$response_file" 2>/dev/null)
        if [ -n "$error_msg" ]; then
            log_error "API Error: $error_msg"
            return 1
        fi
        
        local text=$(jq -r '.text // empty' "$response_file" 2>/dev/null)
        if [ -z "$text" ] || [ "$text" = "null" ]; then
            log_error "No text in API response"
            return 1
        fi
    else
        log_warning "jq not available, cannot validate API response format"
    fi
    
    return 0
}

# Main recording and transcription function
record_and_transcribe() {
    local temp_audio=$(mktemp --suffix=.wav)
    local temp_text=$(mktemp)
    local temp_response=$(mktemp)
    
    # Cleanup function
    cleanup() {
        local exit_code=$?
        log_info "Cleaning up temporary files..."
        rm -f "$temp_audio" "$temp_text" "$temp_response"
        
        # Kill any remaining processes
        if [ -n "$rec_pid" ] && kill -0 "$rec_pid" 2>/dev/null; then
            kill "$rec_pid" 2>/dev/null
        fi
        
        if [ -n "$indicator_pid" ] && kill -0 "$indicator_pid" 2>/dev/null; then
            kill "$indicator_pid" 2>/dev/null
        fi
        
        exit $exit_code
    }
    
    trap cleanup EXIT INT TERM
    
    # Check if API key exists
    if [ -z "$GROQ_API_KEY" ] || [ "$GROQ_API_KEY" = "your_api_key_here" ]; then
        show_notification "Error" "Groq API key not found or not configured. Please check your .env file"
        log_error "Groq API key not found or not configured"
        return 1
    fi
    
    # Detect recording method
    local recording_method=$(detect_audio_system)
    if [ "$recording_method" = "unknown" ]; then
        show_notification "Error" "No audio recording method found. Please install sox, pulseaudio-utils, pipewire, or alsa-utils"
        log_error "No suitable audio recording method found"
        return 1
    fi
    
    # Show notification about recording
    show_notification "Recording Started" "Click the system tray icon or close the progress dialog to stop"
    log_info "Starting audio recording..."
    
    # Start recording
    record_audio "$temp_audio" "$recording_method"
    local rec_pid=$!
    
    if [ $rec_pid -eq 0 ]; then
        log_error "Failed to start recording"
        return 1
    fi
    
    # Create recording indicator
    create_recording_indicator "$rec_pid"
    local indicator_pid=$!
    
    # Wait for recording to finish
    wait $rec_pid
    local record_exit_code=$?
    
    # Kill the indicator
    if [ -n "$indicator_pid" ] && kill -0 "$indicator_pid" 2>/dev/null; then
        kill "$indicator_pid" 2>/dev/null
        wait "$indicator_pid" 2>/dev/null
    fi
    
    # Check if recording was successful
    if [ $record_exit_code -ne 0 ] && [ $record_exit_code -ne 124 ]; then  # 124 is timeout exit code
        log_error "Recording failed with exit code $record_exit_code"
        show_notification "Error" "Audio recording failed"
        return 1
    fi
    
    # Check if audio file was created and has content
    if [ ! -s "$temp_audio" ]; then
        show_notification "Error" "No audio was recorded"
        log_error "No audio was recorded"
        return 1
    fi
    
    log_info "Audio recorded successfully ($(stat -c%s "$temp_audio") bytes)"
    show_notification "Processing" "Transcribing audio..."
    
    # Call Groq API for transcription
    log_info "Sending audio to Groq API for transcription..."
    
    if ! curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$temp_audio" \
        -F "model=whisper-large-v3" \
        -F "response_format=json" \
        -F "language=en" \
        -o "$temp_response"; then
        log_error "Failed to call Groq API"
        show_notification "Error" "Failed to connect to transcription service"
        return 1
    fi
    
    # Validate and extract the text from the response
    if ! validate_api_response "$temp_response"; then
        show_notification "Error" "Invalid response from transcription service"
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        jq -r '.text' "$temp_response" > "$temp_text"
    else
        # Fallback text extraction without jq (basic and fragile)
        grep -o '"text":"[^"]*"' "$temp_response" | sed 's/"text":"//;s/"$//' > "$temp_text"
    fi
    
    # Check if we got any text
    if [ ! -s "$temp_text" ]; then
        show_notification "Error" "No text was transcribed"
        log_error "No text was transcribed"
        return 1
    fi
    
    local transcribed_text=$(cat "$temp_text")
    log_success "Transcription completed: $transcribed_text"
    
    # Paste the text
    paste_text "$transcribed_text"
    show_notification "Success" "Text transcribed and pasted: ${transcribed_text:0:50}..."
}

# Main execution
main() {
    log_info "Starting speech transcription..."
    
    # Source environment variables
    source_env_file
    
    # Run the main function
    record_and_transcribe
    
    log_info "Speech transcription completed"
}

# Run main function
main "$@"

#!/bin/bash

# Store the original window ID before anything else
ORIGINAL_WINDOW_ID=$(xdotool getactivewindow)

# Get window info using xprop directly since it's more reliable
WINDOW_PROPS=$(xprop -id $ORIGINAL_WINDOW_ID 2>/dev/null)

# More specific check for text input windows
ORIGINAL_HAD_FOCUS=$(echo "$WINDOW_PROPS" | grep 'WM_CLASS' | grep -i 'cursor' && echo "yes" || echo "no")

# Source the API key
source ~/.config/groq/api_key

# Record audio and transcribe
record_and_transcribe() {
    local TEMP_AUDIO=$(mktemp --suffix=.wav)
    local TEMP_TEXT=$(mktemp)
    local TEMP_RESPONSE=$(mktemp)
    
    # Check if API key exists
    if [ -z "$GROQ_API_KEY" ]; then
        notify-send "Error" "Groq API key not found. Please check ~/.config/groq/api_key"
        return 1
    fi
    
    # Show notification about recording
    notify-send "Recording Started" "Click the microphone icon in system tray to stop"
    
    # Start recording in background
    rec "$TEMP_AUDIO" rate 16k &
    REC_PID=$!
    
    # Create system tray icon with yad
    yad --notification \
        --image=audio-input-microphone \
        --text="Recording in progress. Click to stop." \
        --command="kill $REC_PID" &
    YAD_PID=$!
    
    # Wait for recording to finish
    wait $REC_PID
    
    # Kill the yad notification
    kill $YAD_PID 2>/dev/null
    wait $YAD_PID 2>/dev/null
    
    # Check if audio file was created and has content
    if [ ! -s "$TEMP_AUDIO" ]; then
        notify-send "Error" "No audio was recorded"
        return 1
    fi
    
    # Call Groq API for transcription and save full response for debugging
    curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$TEMP_AUDIO" \
        -F "model=whisper-large-v3" \
        -F "response_format=json" \
        -F "language=en" \
        > "$TEMP_RESPONSE"
    
    # Extract the text from the response
    cat "$TEMP_RESPONSE" | jq -r '.text' > "$TEMP_TEXT"
    
    # Check if we got any text
    if [ ! -s "$TEMP_TEXT" ]; then
        notify-send "Error" "No text was transcribed"
        return 1
    fi
    
    # Copy to clipboard and paste
    cat "$TEMP_TEXT" | xclip -selection c
    xdotool windowactivate --sync "$ORIGINAL_WINDOW_ID"
    sleep 0.1  # Small delay to ensure window is focused
    xdotool key --clearmodifiers ctrl+v
    
    # Cleanup
    rm "$TEMP_AUDIO" "$TEMP_TEXT" "$TEMP_RESPONSE"
}

# Remove the terminal-specific code and just run the function
record_and_transcribe
exit 0

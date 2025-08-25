# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Conduit is a cross-platform speech-to-text transcription tool that uses the Groq API with Whisper for audio transcription. It supports Linux and macOS, allowing users to record audio from their microphone and automatically transcribe it to text.

## Key Architecture

- **Main Scripts**: Shell-based implementation with platform-specific handling
  - `transcribe-cross-platform.sh`: Main cross-platform transcription script that detects OS and uses appropriate recording methods
  - `transcribe.sh`: Linux-specific version with xdotool auto-paste support
  - `install-cross-platform.sh`: Cross-platform installer that sets up dependencies and configuration
  - `conduit.sh`: Original Linux-only installer

- **Configuration**: 
  - `.env` file stores the GROQ_API_KEY (must have 600 permissions for security)
  - `.conduit.yml` contains default settings for API, audio, and platform-specific tools

- **Platform Detection**: Scripts automatically detect Linux vs macOS and use appropriate tools:
  - Linux: sox for recording, xclip for clipboard, xdotool for auto-paste
  - macOS: sox or QuickTime for recording, pbcopy for clipboard, osascript for notifications

## Development Commands

```bash
# Install dependencies and setup
make install           # Cross-platform install
make install-linux     # Linux-only install

# Testing and validation
make test             # Run tests (when tests/run-tests.sh exists)
make lint             # Run shellcheck on all .sh files
make format           # Format shell scripts with shfmt
make check-deps       # Verify all dependencies are installed

# Maintenance
make clean            # Remove temporary audio/text files from /tmp
make uninstall        # Uninstall the tool
make update           # Update to latest version

# Docker operations
docker-compose build
docker-compose run --rm conduit ./transcribe-cross-platform.sh
```

## Shell Script Standards

- All scripts use bash with strict error handling: `set -euo pipefail`
- ShellCheck is configured via `.shellcheckrc` with specific rules disabled
- Scripts include cleanup traps for temporary files and process management
- Platform detection uses `$OSTYPE` variable
- Error handling includes line number reporting and proper exit codes

## API Integration

The scripts interact with Groq API using:
- Model: `whisper-large-v3`
- Format: WAV audio at 16kHz sample rate
- Authentication: Bearer token from GROQ_API_KEY environment variable
- Endpoint: `https://api.groq.com/openai/v1/audio/transcriptions`

## Security Considerations

- The `.env` file must have 600 permissions (owner read/write only)
- API keys must start with `gsk_` and be 56 characters total
- Never commit `.env` files (already in `.gitignore`)
- Scripts validate API key format before use

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`) runs:
- ShellCheck linting on all shell scripts
- Syntax validation for all scripts
- Platform-specific tests for Linux and macOS
- Security checks for hardcoded secrets
- Dependency verification
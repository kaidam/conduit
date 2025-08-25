# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cross-platform support for macOS
- Comprehensive error handling with cleanup traps
- API key validation and secure handling
- Cross-platform installer script
- Project structure files (package.json, Makefile, etc.)
- GitHub Actions CI/CD pipeline
- Contributing guidelines
- EditorConfig for consistent code style

### Changed
- Improved OS detection with early exit for unsupported systems
- Enhanced security for API key storage (600 permissions)
- Better error messages with HTTP status code handling
- Refactored code for better maintainability

### Security
- API key validation to prevent injection attacks
- Secure file permissions for .env file
- Input sanitization in curl commands
- Timeout protection on API calls

## [1.0.0] - 2024-01-01

### Added
- Initial release for Linux systems
- Basic speech-to-text transcription using Groq API
- Automatic clipboard integration
- Auto-paste functionality for Linux
- Keyboard shortcut configuration
- Installation script for Linux
- Basic documentation

### Features
- Record audio from microphone
- Transcribe using Whisper model via Groq API
- Copy transcribed text to clipboard
- Auto-paste to active window (Linux)
- System tray integration with yad

### Supported Platforms
- Linux Mint
- Ubuntu
- Debian
- Other apt-based distributions

[Unreleased]: https://github.com/yourusername/conduit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/conduit/releases/tag/v1.0.0
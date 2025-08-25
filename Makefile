# Makefile for Conduit - Speech-to-Text Transcription Tool

.PHONY: help install install-cross test lint clean check-deps format

# Default target
help:
	@echo "Conduit - Speech-to-Text Transcription Tool"
	@echo ""
	@echo "Available targets:"
	@echo "  make install       - Install for current platform"
	@echo "  make install-linux - Install for Linux only"
	@echo "  make test          - Run tests"
	@echo "  make lint          - Run shellcheck linter"
	@echo "  make format        - Format shell scripts"
	@echo "  make clean         - Clean temporary files"
	@echo "  make check-deps    - Check dependencies"
	@echo "  make uninstall     - Uninstall the tool"

# Install for current platform
install:
	@echo "Installing Conduit..."
	@chmod +x install-cross-platform.sh
	@./install-cross-platform.sh

# Install for Linux only
install-linux:
	@echo "Installing Conduit (Linux only)..."
	@chmod +x conduit.sh
	@./conduit.sh

# Run tests
test:
	@echo "Running tests..."
	@if [ -f tests/run-tests.sh ]; then \
		chmod +x tests/run-tests.sh && ./tests/run-tests.sh; \
	else \
		echo "No tests found. Create tests/run-tests.sh"; \
	fi

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck *.sh; \
	else \
		echo "shellcheck not found. Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)"; \
	fi

# Format shell scripts
format:
	@echo "Formatting shell scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 4 *.sh; \
	else \
		echo "shfmt not found. Install with: brew install shfmt (macOS) or apt-get install shfmt (Linux)"; \
	fi

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -f /tmp/audio*.wav /tmp/text* /tmp/response*
	@echo "Cleaned temporary files"

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@echo ""
	@echo "Required tools:"
	@command -v curl >/dev/null 2>&1 && echo "✓ curl" || echo "✗ curl (required)"
	@command -v jq >/dev/null 2>&1 && echo "✓ jq" || echo "✗ jq (required)"
	@echo ""
	@echo "Optional tools:"
	@command -v sox >/dev/null 2>&1 && echo "✓ sox" || echo "✗ sox (recommended for better audio)"
	@command -v shellcheck >/dev/null 2>&1 && echo "✓ shellcheck" || echo "✗ shellcheck (for linting)"
	@command -v shfmt >/dev/null 2>&1 && echo "✓ shfmt" || echo "✗ shfmt (for formatting)"
	@echo ""
	@if [ -f .env ]; then \
		echo "✓ .env file exists"; \
	else \
		echo "✗ .env file missing (run make install)"; \
	fi

# Uninstall
uninstall:
	@echo "Starting Conduit uninstaller..."
	@chmod +x uninstall.sh
	@./uninstall.sh

# Update to latest version
update:
	@echo "Checking for updates..."
	@chmod +x update.sh
	@./update.sh
# Contributing to Conduit

Thank you for your interest in contributing to Conduit! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions. We're all here to make the tool better.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in the [Issues](https://github.com/yourusername/conduit/issues) section
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce (if it's a bug)
   - Your environment (OS, shell version, etc.)
   - Any error messages

### Suggesting Features

1. Open an issue with the "enhancement" label
2. Describe the feature and why it would be useful
3. Include examples of how it would work

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests and linting: `make test && make lint`
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/conduit.git
cd conduit

# Install development dependencies
# macOS
brew install shellcheck shfmt

# Linux
sudo apt-get install shellcheck shfmt

# Run tests
make test

# Lint code
make lint

# Format code
make format
```

## Coding Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Add error handling and cleanup traps
- Use meaningful variable names
- Comment complex logic
- Follow ShellCheck recommendations

### Commit Messages

Format:
```
type: brief description

Longer explanation if needed.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Testing

- Test on both Linux and macOS if possible
- Include error cases in tests
- Verify cleanup happens properly
- Check different shell environments (bash, zsh)

## Platform-Specific Considerations

### Linux
- Test on Ubuntu, Debian, and other distros if possible
- Ensure compatibility with different package managers
- Test with and without optional dependencies

### macOS
- Test on recent macOS versions
- Verify Homebrew package availability
- Test with and without sox installed

## Documentation

- Update README.md for new features
- Add inline comments for complex code
- Update help text in scripts
- Include examples where helpful

## Questions?

Feel free to open an issue for any questions about contributing!
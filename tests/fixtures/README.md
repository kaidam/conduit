# Test Fixtures

This directory contains test data and fixtures for the Conduit test suite.

## Contents

- `test_config.yml` - Test configuration file with scenarios and settings
- `test_audio.wav` - Sample audio file for testing (generated at runtime)

## Audio File Generation

The test suite generates a minimal WAV file at runtime using the `generate_test_audio_file()` function in `test-helpers.sh`. This ensures tests can run without requiring actual audio files to be committed to the repository.

## Mock Responses

Mock API responses are stored in the `../mocks/` directory:
- `api_response_success.json` - Successful transcription response
- `api_response_error.json` - API error response
- `api_response_rate_limit.json` - Rate limit error response

## Usage

These fixtures are automatically used by the test suite when running:
```bash
make test
# or
./tests/run-tests.sh
```
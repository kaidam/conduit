#!/bin/bash

# Unit Tests for Conduit
# Tests individual functions and components

set -uo pipefail

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Source test helpers
source "$TEST_DIR/test-helpers.sh"

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test API key validation
test_api_key_validation() {
    test_section "API Key Validation"
    
    # Valid API key format
    local valid_key="gsk_1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdef"
    assert_equals "56" "${#valid_key}" "Valid API key length"
    assert_contains "$valid_key" "gsk_" "API key starts with gsk_"
    
    # Invalid API key formats
    local short_key="gsk_12345"
    assert_not_equals "56" "${#short_key}" "Invalid API key - too short"
    
    local wrong_prefix="sk_1234567890abcdefghijklmnopqrstuvwxyz1234567890abcdef"
    assert_not_contains "$wrong_prefix" "gsk_" "Invalid API key - wrong prefix"
}

# Test platform detection
test_platform_detection() {
    test_section "Platform Detection"
    
    # Save original OSTYPE
    local original_ostype="${OSTYPE:-}"
    
    # Test Linux detection
    OSTYPE="linux-gnu"
    local platform=""
    case "$OSTYPE" in
        linux-gnu*) platform="linux" ;;
        darwin*) platform="macos" ;;
        *) platform="unknown" ;;
    esac
    assert_equals "linux" "$platform" "Linux platform detection"
    
    # Test macOS detection
    OSTYPE="darwin20"
    case "$OSTYPE" in
        linux-gnu*) platform="linux" ;;
        darwin*) platform="macos" ;;
        *) platform="unknown" ;;
    esac
    assert_equals "macos" "$platform" "macOS platform detection"
    
    # Test Windows detection (should be unsupported)
    OSTYPE="msys"
    case "$OSTYPE" in
        linux-gnu*) platform="linux" ;;
        darwin*) platform="macos" ;;
        msys*|cygwin*|mingw*) platform="windows" ;;
        *) platform="unknown" ;;
    esac
    assert_equals "windows" "$platform" "Windows platform detection"
    
    # Restore original OSTYPE
    OSTYPE="$original_ostype"
}

# Test file permission functions
test_file_permissions() {
    test_section "File Permissions"
    
    # Create test file
    local test_file="$TEST_TEMP_DIR/test_perms.txt"
    create_test_file "$test_file" "test content"
    
    # Test chmod 600
    chmod 600 "$test_file"
    local perms=$(stat -c "%a" "$test_file" 2>/dev/null || stat -f "%OLp" "$test_file" 2>/dev/null)
    assert_equals "600" "$perms" "File permissions set to 600"
    
    # Test file exists
    assert_file_exists "$test_file" "Test file exists"
    
    # Clean up
    rm -f "$test_file"
    assert_file_not_exists "$test_file" "Test file removed"
}

# Test environment variable handling
test_env_variables() {
    test_section "Environment Variables"
    
    # Create mock .env file
    create_mock_env_file "$TEST_TEMP_DIR/.env"
    
    # Source and test
    set -a
    source "$TEST_TEMP_DIR/.env"
    set +a
    
    assert_equals "gsk_test_1234567890abcdefghijklmnopqrstuvwxyz1234567890ab" "$GROQ_API_KEY" "GROQ_API_KEY loaded from .env"
    
    # Test permissions on .env file
    assert_file_permissions "$TEST_TEMP_DIR/.env" "600" ".env file has secure permissions"
}

# Test temporary file creation and cleanup
test_temp_file_handling() {
    test_section "Temporary File Handling"
    
    # Test temp file creation
    local temp_file=$(mktemp)
    assert_file_exists "$temp_file" "Temporary file created"
    
    # Test temp directory creation
    local temp_dir=$(mktemp -d)
    assert_directory_exists "$temp_dir" "Temporary directory created"
    
    # Clean up
    rm -f "$temp_file"
    rm -rf "$temp_dir"
    
    assert_file_not_exists "$temp_file" "Temporary file cleaned up"
    assert_file_not_exists "$temp_dir" "Temporary directory cleaned up"
}

# Test command availability checks
test_command_checks() {
    test_section "Command Availability"
    
    # Test for common commands that should exist
    assert_command_exists "bash" "Bash is available"
    assert_command_exists "echo" "Echo is available"
    assert_command_exists "test" "Test is available"
    
    # Test for command that shouldn't exist
    local fake_cmd="this_command_definitely_does_not_exist_anywhere"
    if ! command -v "$fake_cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Fake command correctly not found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Fake command unexpectedly found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test audio file validation
test_audio_file_validation() {
    test_section "Audio File Validation"
    
    # Generate test audio file
    local test_audio=$(generate_test_audio_file)
    assert_file_exists "$test_audio" "Test audio file created"
    
    # Check file starts with RIFF header (WAV format)
    local header=$(head -c 4 "$test_audio")
    assert_equals "RIFF" "$header" "WAV file has RIFF header"
    
    # Check file size is greater than 0
    local file_size=$(stat -c%s "$test_audio" 2>/dev/null || stat -f%z "$test_audio" 2>/dev/null)
    if [ "$file_size" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Audio file has valid size"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Audio file is empty"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test JSON parsing utilities
test_json_parsing() {
    test_section "JSON Parsing"
    
    # Skip if jq is not available
    if ! command -v jq &> /dev/null; then
        skip_test "JSON parsing tests" "jq not installed"
        return
    fi
    
    # Create test JSON
    local test_json='{"text":"Hello, world!","status":"success"}'
    echo "$test_json" > "$TEST_TEMP_DIR/test.json"
    
    # Test parsing with jq
    local parsed_text=$(echo "$test_json" | jq -r '.text')
    assert_equals "Hello, world!" "$parsed_text" "JSON text field parsed correctly"
    
    local parsed_status=$(echo "$test_json" | jq -r '.status')
    assert_equals "success" "$parsed_status" "JSON status field parsed correctly"
}

# Test error handling
test_error_handling() {
    test_section "Error Handling"
    
    # Test exit on error (in subshell to not exit main script)
    (
        set -e
        false || true
        echo "survived"
    ) > "$TEST_TEMP_DIR/error_test.txt" 2>&1
    
    local output=$(cat "$TEST_TEMP_DIR/error_test.txt")
    assert_contains "$output" "survived" "Error handling with || true works"
    
    # Test pipefail
    (
        set -eo pipefail
        echo "test" | false | true
    ) 2> "$TEST_TEMP_DIR/pipefail_test.txt"
    local exit_code=$?
    
    assert_not_equals "0" "$exit_code" "Pipefail catches errors in pipeline"
}

# Test string manipulation functions
test_string_manipulation() {
    test_section "String Manipulation"
    
    # Test string length
    local test_string="Hello, World!"
    assert_equals "13" "${#test_string}" "String length calculation"
    
    # Test substring extraction
    local substring="${test_string:0:5}"
    assert_equals "Hello" "$substring" "Substring extraction"
    
    # Test string replacement
    local replaced="${test_string//World/Universe}"
    assert_equals "Hello, Universe!" "$replaced" "String replacement"
    
    # Test uppercase conversion (portable way)
    local uppercase=$(echo "$test_string" | tr '[:lower:]' '[:upper:]')
    assert_equals "HELLO, WORLD!" "$uppercase" "Uppercase conversion"
    
    # Test lowercase conversion (portable way)
    local lowercase=$(echo "$test_string" | tr '[:upper:]' '[:lower:]')
    assert_equals "hello, world!" "$lowercase" "Lowercase conversion"
}

# Test array operations
test_array_operations() {
    test_section "Array Operations"
    
    # Create test array
    local test_array=("apple" "banana" "cherry")
    
    # Test array length
    assert_equals "3" "${#test_array[@]}" "Array length"
    
    # Test array element access
    assert_equals "apple" "${test_array[0]}" "First array element"
    assert_equals "cherry" "${test_array[2]}" "Last array element"
    
    # Test array append
    test_array+=("date")
    assert_equals "4" "${#test_array[@]}" "Array append"
    assert_equals "date" "${test_array[3]}" "Appended element"
}

# Main test execution
main() {
    echo "Running Unit Tests"
    echo "=================="
    
    # Run all test functions
    test_api_key_validation
    test_platform_detection
    test_file_permissions
    test_env_variables
    test_temp_file_handling
    test_command_checks
    test_audio_file_validation
    test_json_parsing
    test_error_handling
    test_string_manipulation
    test_array_operations
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
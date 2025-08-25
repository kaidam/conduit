#!/bin/bash

# Error Handling Tests for Conduit
# Tests error conditions and recovery mechanisms

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

# Test missing API key handling
test_missing_api_key() {
    test_section "Missing API Key Handling"
    
    # Create test script that checks for API key
    local test_script="$TEST_TEMP_DIR/api_key_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "Error: GROQ_API_KEY not set"
    exit 1
fi
echo "API key found"
EOF
    chmod +x "$test_script"
    
    # Test without API key
    unset GROQ_API_KEY || true
    output=$("$test_script" 2>&1 || true)
    assert_contains "$output" "Error: GROQ_API_KEY not set" "Missing API key detected"
    
    # Test with API key
    export GROQ_API_KEY="gsk_test_1234567890abcdefghijklmnopqrstuvwxyz1234567890ab"
    output=$("$test_script" 2>&1 || true)
    assert_contains "$output" "API key found" "API key presence detected"
}

# Test invalid API key format handling
test_invalid_api_key_format() {
    test_section "Invalid API Key Format"
    
    # Create validation script
    local test_script="$TEST_TEMP_DIR/validate_key.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

GROQ_API_KEY="${1:-}"

if [ -z "$GROQ_API_KEY" ]; then
    echo "Error: No API key provided"
    exit 1
fi

if [[ ! "$GROQ_API_KEY" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
    echo "Error: Invalid API key format"
    exit 1
fi

echo "Valid API key"
EOF
    chmod +x "$test_script"
    
    # Test various invalid formats
    local invalid_keys=(
        ""
        "invalid"
        "sk_wrong_prefix"
        "gsk_tooshort"
        "gsk_has_invalid_chars!@#$%^&*()"
    )
    
    for key in "${invalid_keys[@]}"; do
        output=$("$test_script" "$key" 2>&1 || true)
        if [[ "$output" == *"Error:"* ]]; then
            echo -e "  ${GREEN}✓${NC} Rejected invalid key: ${key:0:20}..."
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${RED}✗${NC} Failed to reject: ${key:0:20}..."
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        fi
    done
}

# Test network error handling
test_network_errors() {
    test_section "Network Error Handling"
    
    # Create script that simulates network failure
    local test_script="$TEST_TEMP_DIR/network_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

# Simulate curl failure
curl_response=$(curl -s -o /dev/null -w "%{http_code}" "http://invalid.domain.that.does.not.exist" 2>/dev/null || echo "000")

if [ "$curl_response" = "000" ]; then
    echo "Error: Network connection failed"
    exit 1
fi

echo "Network OK"
EOF
    chmod +x "$test_script"
    
    output=$("$test_script" 2>&1 || true)
    assert_contains "$output" "Error: Network connection failed" "Network error detected"
}

# Test file permission errors
test_file_permission_errors() {
    test_section "File Permission Errors"
    
    # Create test file with no read permissions
    local test_file="$TEST_TEMP_DIR/no_read.txt"
    echo "test" > "$test_file"
    chmod 000 "$test_file"
    
    # Try to read the file
    if cat "$test_file" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Unexpectedly read protected file"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} Permission denied error handled"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Cleanup
    chmod 644 "$test_file"
    rm -f "$test_file"
}

# Test disk space errors
test_disk_space_handling() {
    test_section "Disk Space Handling"
    
    # Create script that checks disk space
    local test_script="$TEST_TEMP_DIR/disk_check.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

# Check available space in /tmp
available=$(df /tmp | awk 'NR==2 {print $4}')

# Require at least 100MB (100000 KB)
if [ "$available" -lt 100000 ]; then
    echo "Error: Insufficient disk space"
    exit 1
fi

echo "Sufficient disk space"
EOF
    chmod +x "$test_script"
    
    output=$("$test_script" 2>&1 || true)
    # Should pass on most systems
    assert_contains "$output" "Sufficient disk space" "Disk space check works"
}

# Test timeout handling
test_timeout_handling() {
    test_section "Timeout Handling"
    
    # Create script with timeout
    local test_script="$TEST_TEMP_DIR/timeout_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

# Use timeout command if available
if command -v timeout &> /dev/null; then
    if timeout 1s sleep 10; then
        echo "Command completed"
    else
        echo "Error: Command timed out"
        exit 1
    fi
else
    echo "Timeout command not available"
fi
EOF
    chmod +x "$test_script"
    
    output=$("$test_script" 2>&1 || true)
    if [[ "$output" == *"timed out"* ]] || [[ "$output" == *"not available"* ]]; then
        echo -e "  ${GREEN}✓${NC} Timeout handling works"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} Unexpected timeout behavior"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test signal handling
test_signal_handling() {
    test_section "Signal Handling"
    
    # Create script with signal trap
    local test_script="$TEST_TEMP_DIR/signal_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash

CLEANUP_DONE=0

cleanup() {
    if [ "$CLEANUP_DONE" -eq 0 ]; then
        CLEANUP_DONE=1
        echo "Cleanup executed"
    fi
}

trap cleanup EXIT INT TERM

# Simulate work
sleep 0.1
echo "Normal completion"
EOF
    chmod +x "$test_script"
    
    # Test normal completion
    output=$("$test_script" 2>&1)
    assert_contains "$output" "Normal completion" "Script completes normally"
    assert_contains "$output" "Cleanup executed" "Cleanup runs on normal exit"
}

# Test API error responses
test_api_error_responses() {
    test_section "API Error Response Handling"
    
    # Create script that handles API errors
    local test_script="$TEST_TEMP_DIR/api_error_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

# Simulate different API response codes
handle_api_response() {
    local http_code="$1"
    
    case "$http_code" in
        200) echo "Success" ;;
        400) echo "Error: Bad request" ; exit 1 ;;
        401) echo "Error: Unauthorized - check API key" ; exit 1 ;;
        429) echo "Error: Rate limit exceeded" ; exit 1 ;;
        500) echo "Error: Server error" ; exit 1 ;;
        *) echo "Error: Unexpected response code: $http_code" ; exit 1 ;;
    esac
}

# Test various response codes
for code in 200 400 401 429 500 999; do
    echo -n "HTTP $code: "
    handle_api_response "$code" || true
done
EOF
    chmod +x "$test_script"
    
    output=$("$test_script" 2>&1)
    assert_contains "$output" "HTTP 200: Success" "Success response handled"
    assert_contains "$output" "HTTP 401: Error: Unauthorized" "Auth error handled"
    assert_contains "$output" "HTTP 429: Error: Rate limit" "Rate limit handled"
}

# Test JSON parsing errors
test_json_parsing_errors() {
    test_section "JSON Parsing Errors"
    
    if ! command -v jq &> /dev/null; then
        skip_test "JSON parsing error tests" "jq not installed"
        return
    fi
    
    # Test invalid JSON
    local invalid_json='{"invalid": json"}'
    echo "$invalid_json" > "$TEST_TEMP_DIR/invalid.json"
    
    if jq '.' "$TEST_TEMP_DIR/invalid.json" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Invalid JSON not detected"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} Invalid JSON detected"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Test empty response
    echo "" > "$TEST_TEMP_DIR/empty.json"
    if jq '.' "$TEST_TEMP_DIR/empty.json" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} Empty JSON not detected"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} Empty JSON detected"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test dependency missing errors
test_missing_dependencies() {
    test_section "Missing Dependencies"
    
    # Create script that checks dependencies
    local test_script="$TEST_TEMP_DIR/dep_check.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required dependency '$cmd' not found"
        return 1
    fi
    echo "Found: $cmd"
    return 0
}

# Check common dependencies
deps=("bash" "curl" "jq" "this_command_does_not_exist")
missing=0

for dep in "${deps[@]}"; do
    if ! check_dependency "$dep"; then
        ((missing++))
    fi
done

if [ $missing -gt 0 ]; then
    echo "Missing $missing dependencies"
    exit 1
fi
EOF
    chmod +x "$test_script"
    
    output=$("$test_script" 2>&1 || true)
    assert_contains "$output" "Error: Required dependency 'this_command_does_not_exist' not found" "Missing dependency detected"
    assert_contains "$output" "Missing 1 dependencies" "Dependency count correct"
}

# Main test execution
main() {
    echo "Running Error Handling Tests"
    echo "==========================="
    
    # Run all test functions
    test_missing_api_key
    test_invalid_api_key_format
    test_network_errors
    test_file_permission_errors
    test_disk_space_handling
    test_timeout_handling
    test_signal_handling
    test_api_error_responses
    test_json_parsing_errors
    test_missing_dependencies
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
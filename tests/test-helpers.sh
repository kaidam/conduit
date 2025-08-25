#!/bin/bash

# Test Helper Functions
# Common utilities for all test suites

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Assertion}"
    
    ((TESTS_RUN++))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Expected: '$expected'"
        echo -e "    Actual:   '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local test_name="${3:-Assertion}"
    
    ((TESTS_RUN++))
    
    if [ "$not_expected" != "$actual" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Should not equal: '$not_expected'"
        echo -e "    Actual:          '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-Assertion}"
    
    ((TESTS_RUN++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    String: '$haystack'"
        echo -e "    Should contain: '$needle'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-Assertion}"
    
    ((TESTS_RUN++))
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    String: '$haystack'"
        echo -e "    Should not contain: '$needle'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="${2:-File exists: $file_path}"
    
    ((TESTS_RUN++))
    
    if [ -f "$file_path" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    File not found: '$file_path'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local test_name="${2:-File should not exist: $file_path}"
    
    ((TESTS_RUN++))
    
    if [ ! -f "$file_path" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    File should not exist: '$file_path'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_directory_exists() {
    local dir_path="$1"
    local test_name="${2:-Directory exists: $dir_path}"
    
    ((TESTS_RUN++))
    
    if [ -d "$dir_path" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Directory not found: '$dir_path'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_command_exists() {
    local command="$1"
    local test_name="${2:-Command exists: $command}"
    
    ((TESTS_RUN++))
    
    if command -v "$command" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Command not found: '$command'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="${3:-Exit code check}"
    
    ((TESTS_RUN++))
    
    if [ "$expected_code" -eq "$actual_code" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Expected exit code: $expected_code"
        echo -e "    Actual exit code:   $actual_code"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_permissions() {
    local file_path="$1"
    local expected_perms="$2"
    local test_name="${3:-File permissions check}"
    
    ((TESTS_RUN++))
    
    if [ ! -f "$file_path" ]; then
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    File not found: '$file_path'"
        ((TESTS_FAILED++))
        return 1
    fi
    
    local actual_perms=$(stat -c "%a" "$file_path" 2>/dev/null || stat -f "%OLp" "$file_path" 2>/dev/null)
    
    if [ "$expected_perms" = "$actual_perms" ]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $test_name"
        echo -e "    Expected permissions: $expected_perms"
        echo -e "    Actual permissions:   $actual_perms"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test environment setup helpers
create_test_file() {
    local file_path="$1"
    local content="${2:-Test content}"
    
    echo "$content" > "$file_path"
}

create_test_directory() {
    local dir_path="$1"
    
    mkdir -p "$dir_path"
}

create_mock_env_file() {
    local env_path="${1:-$TEST_TEMP_DIR/.env}"
    
    cat > "$env_path" << 'EOF'
GROQ_API_KEY=gsk_test_1234567890abcdefghijklmnopqrstuvwxyz1234567890ab
EOF
    chmod 600 "$env_path"
}

# Mock command helpers
mock_command() {
    local command_name="$1"
    local mock_script="$2"
    
    # Create mock command in test PATH
    local mock_path="$TEST_TEMP_DIR/mocks"
    mkdir -p "$mock_path"
    
    cat > "$mock_path/$command_name" << EOF
#!/bin/bash
$mock_script
EOF
    
    chmod +x "$mock_path/$command_name"
    
    # Prepend mock path to PATH
    export PATH="$mock_path:$PATH"
}

restore_path() {
    # Remove mock path from PATH
    if [ -n "${TEST_TEMP_DIR:-}" ]; then
        export PATH="${PATH#$TEST_TEMP_DIR/mocks:}"
    fi
}

# Platform detection helpers
set_platform() {
    local platform="$1"
    
    case "$platform" in
        linux)
            export OSTYPE="linux-gnu"
            ;;
        macos)
            export OSTYPE="darwin"
            ;;
        windows)
            export OSTYPE="msys"
            ;;
        *)
            echo "Unknown platform: $platform"
            return 1
            ;;
    esac
}

restore_platform() {
    unset OSTYPE
}

# Output capture helpers
capture_output() {
    local command="$1"
    local output_file="$TEST_TEMP_DIR/output.txt"
    local error_file="$TEST_TEMP_DIR/error.txt"
    
    # Run command and capture output
    $command > "$output_file" 2> "$error_file"
    local exit_code=$?
    
    # Return captured data
    echo "EXIT_CODE:$exit_code"
    echo "STDOUT:$(cat "$output_file")"
    echo "STDERR:$(cat "$error_file")"
    
    return $exit_code
}

# Test data generators
generate_test_audio_file() {
    local output_file="${1:-$TEST_TEMP_DIR/test_audio.wav}"
    
    # Generate a simple WAV header for a 1-second silent audio file
    # This is a minimal valid WAV file
    printf "RIFF" > "$output_file"
    printf "\x24\x00\x00\x00" >> "$output_file"  # File size - 8
    printf "WAVE" >> "$output_file"
    printf "fmt " >> "$output_file"
    printf "\x10\x00\x00\x00" >> "$output_file"  # fmt chunk size
    printf "\x01\x00" >> "$output_file"           # PCM format
    printf "\x01\x00" >> "$output_file"           # 1 channel
    printf "\x80\x3E\x00\x00" >> "$output_file"  # 16000 Hz sample rate
    printf "\x00\x7D\x00\x00" >> "$output_file"  # Byte rate
    printf "\x02\x00" >> "$output_file"           # Block align
    printf "\x10\x00" >> "$output_file"           # Bits per sample
    printf "data" >> "$output_file"
    printf "\x00\x00\x00\x00" >> "$output_file"  # Data size
    
    echo "$output_file"
}

# API mock helpers
setup_mock_api_server() {
    local port="${1:-8080}"
    local response_file="${2:-$TEST_DIR/mocks/api_response.json}"
    
    # Create a simple mock server using netcat (if available)
    if command -v nc &> /dev/null; then
        while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n$(cat "$response_file")" | nc -l -p "$port" -q 1
        done &
        
        local server_pid=$!
        PIDS_TO_KILL+=("$server_pid")
        
        echo "$server_pid"
    else
        echo "Mock server requires netcat (nc)" >&2
        return 1
    fi
}

# Test report helpers
test_section() {
    local section_name="$1"
    echo ""
    echo "Testing: $section_name"
    echo "------------------------"
}

skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    
    echo -e "  ${YELLOW}⊘${NC} $test_name (SKIPPED: $reason)"
    ((TESTS_SKIPPED++))
}
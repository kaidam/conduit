#!/bin/bash

# Conduit Test Runner
# Main test orchestrator that runs all test suites

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results array
declare -a FAILED_TESTS=()

# Get the directory where this script is located
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Source test helpers
source "$TEST_DIR/test-helpers.sh"

# Print test header
print_header() {
    echo "======================================"
    echo "       Conduit Test Suite"
    echo "======================================"
    echo ""
}

# Print test summary
print_summary() {
    echo ""
    echo "======================================"
    echo "         Test Summary"
    echo "======================================"
    echo -e "Tests Run:     $TESTS_RUN"
    echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
    echo -e "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
    fi
    
    echo "======================================"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run a test suite
run_test_suite() {
    local suite_name="$1"
    local suite_file="$2"
    
    echo ""
    echo -e "${BLUE}Running $suite_name...${NC}"
    echo "--------------------------------------"
    
    if [ ! -f "$suite_file" ]; then
        echo -e "${YELLOW}⚠ Skipping $suite_name (file not found)${NC}"
        ((TESTS_SKIPPED++))
        return 0
    fi
    
    # Make sure the test file is executable
    chmod +x "$suite_file"
    
    # Run the test suite and capture the result
    if "$suite_file"; then
        echo -e "${GREEN}✓ $suite_name passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $suite_name failed${NC}"
        FAILED_TESTS+=("$suite_name")
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in bash curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install missing dependencies and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create temporary test directory
    export TEST_TEMP_DIR=$(mktemp -d)
    export TEST_ENV_FILE="$TEST_TEMP_DIR/.env"
    
    # Create a test .env file with mock API key
    echo "GROQ_API_KEY=gsk_test_1234567890abcdefghijklmnopqrstuvwxyz1234567890ab" > "$TEST_ENV_FILE"
    chmod 600 "$TEST_ENV_FILE"
    
    # Export test mode flag
    export CONDUIT_TEST_MODE=1
    
    echo -e "${GREEN}✓ Test environment ready${NC}"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    
    if [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    unset CONDUIT_TEST_MODE
    unset TEST_TEMP_DIR
    unset TEST_ENV_FILE
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Trap to ensure cleanup on exit
trap cleanup_test_env EXIT

# Main test execution
main() {
    print_header
    
    # Check prerequisites
    check_prerequisites
    
    # Setup test environment
    setup_test_env
    
    # Run test suites
    run_test_suite "Syntax Validation" "$TEST_DIR/syntax-tests.sh"
    run_test_suite "Unit Tests" "$TEST_DIR/unit-tests.sh"
    run_test_suite "Integration Tests" "$TEST_DIR/integration-tests.sh"
    run_test_suite "Platform Detection Tests" "$TEST_DIR/platform-tests.sh"
    run_test_suite "Security Tests" "$TEST_DIR/security-tests.sh"
    run_test_suite "Error Handling Tests" "$TEST_DIR/error-tests.sh"
    
    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"
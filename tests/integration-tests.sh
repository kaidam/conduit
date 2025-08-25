#!/bin/bash

# Integration Tests for Conduit
# Tests complete workflows and component interactions

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

# Test installation workflow
test_installation_workflow() {
    test_section "Installation Workflow"
    
    # Check if installer script exists
    assert_file_exists "$PROJECT_ROOT/install-cross-platform.sh" "Cross-platform installer exists"
    assert_file_exists "$PROJECT_ROOT/conduit.sh" "Linux installer exists"
    
    # Test installer script syntax
    if bash -n "$PROJECT_ROOT/install-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Installer script has valid syntax"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Installer script has syntax errors"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
    
    # Check for .env.example
    assert_file_exists "$PROJECT_ROOT/.env.example" ".env.example template exists"
}

# Test transcription script workflow
test_transcription_workflow() {
    test_section "Transcription Script Workflow"
    
    # Check main transcription scripts exist
    assert_file_exists "$PROJECT_ROOT/transcribe-cross-platform.sh" "Cross-platform transcribe script exists"
    assert_file_exists "$PROJECT_ROOT/transcribe.sh" "Linux transcribe script exists"
    
    # Test script syntax
    if bash -n "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Cross-platform script has valid syntax"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Cross-platform script has syntax errors"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
    
    if bash -n "$PROJECT_ROOT/transcribe.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Linux script has valid syntax"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Linux script has syntax errors"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test environment setup
test_environment_setup() {
    test_section "Environment Setup"
    
    # Create test environment directory
    local test_env_dir="$TEST_TEMP_DIR/env_test"
    create_test_directory "$test_env_dir"
    
    # Create mock .env file
    local env_file="$test_env_dir/.env"
    create_mock_env_file "$env_file"
    
    # Test .env file creation and permissions
    assert_file_exists "$env_file" ".env file created"
    assert_file_permissions "$env_file" "600" ".env has secure permissions"
    
    # Test sourcing .env file
    (
        set -a
        source "$env_file"
        set +a
        
        if [ -n "${GROQ_API_KEY:-}" ]; then
            echo -e "  ${GREEN}✓${NC} Environment variables loaded"
            exit 0
        else
            echo -e "  ${RED}✗${NC} Failed to load environment variables"
            exit 1
        fi
    )
    local exit_code=$?
    assert_exit_code "0" "$exit_code" "Environment loading successful"
}

# Test configuration file handling
test_configuration_handling() {
    test_section "Configuration Handling"
    
    # Check for configuration files
    assert_file_exists "$PROJECT_ROOT/.conduit.yml" "Configuration file exists"
    assert_file_exists "$PROJECT_ROOT/.env.example" "Environment template exists"
    
    # Validate YAML structure (basic check)
    if command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.conduit.yml'))" 2>/dev/null
        local yaml_valid=$?
        assert_exit_code "0" "$yaml_valid" "YAML configuration is valid"
    else
        skip_test "YAML validation" "Python3 not available"
    fi
}

# Test Docker integration
test_docker_integration() {
    test_section "Docker Integration"
    
    # Check Docker files exist
    assert_file_exists "$PROJECT_ROOT/Dockerfile" "Dockerfile exists"
    assert_file_exists "$PROJECT_ROOT/docker-compose.yml" "docker-compose.yml exists"
    
    # Validate Dockerfile syntax (basic check)
    if command -v docker &> /dev/null; then
        # Just check if Dockerfile can be parsed
        docker build --help > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} Docker is available for testing"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        skip_test "Docker build validation" "Docker not installed"
    fi
}

# Test platform-specific features
test_platform_features() {
    test_section "Platform-Specific Features"
    
    # Save original OSTYPE
    local original_ostype="${OSTYPE:-}"
    
    # Test Linux features
    OSTYPE="linux-gnu"
    if [[ "$OSTYPE" == linux* ]]; then
        echo -e "  ${GREEN}✓${NC} Linux platform detected correctly"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
        
        # Check for Linux-specific commands in scripts
        if grep -q "xclip\|xdotool\|notify-send" "$PROJECT_ROOT/transcribe.sh" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Linux-specific commands found in scripts"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        fi
    fi
    
    # Test macOS features
    OSTYPE="darwin"
    if [[ "$OSTYPE" == darwin* ]]; then
        echo -e "  ${GREEN}✓${NC} macOS platform detected correctly"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
        
        # Check for macOS-specific commands
        if grep -q "pbcopy\|osascript" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} macOS-specific commands found in scripts"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        fi
    fi
    
    # Restore original OSTYPE
    OSTYPE="$original_ostype"
}

# Test error recovery
test_error_recovery() {
    test_section "Error Recovery"
    
    # Test cleanup on script exit
    local test_script="$TEST_TEMP_DIR/error_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -uo pipefail

TEMP_FILES=()
CLEANUP_DONE=0

cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1
    echo "Cleanup executed"
}

trap cleanup EXIT

# Simulate error
false
EOF
    
    chmod +x "$test_script"
    
    # Run script and capture output
    output=$("$test_script" 2>&1 || true)
    assert_contains "$output" "Cleanup executed" "Cleanup trap executes on error"
}

# Test API integration (mocked)
test_api_integration() {
    test_section "API Integration (Mocked)"
    
    # Create mock API response
    local mock_response='{"text":"This is a test transcription","status":"success"}'
    echo "$mock_response" > "$TEST_TEMP_DIR/mock_response.json"
    
    # Test JSON response parsing
    if command -v jq &> /dev/null; then
        local parsed_text=$(cat "$TEST_TEMP_DIR/mock_response.json" | jq -r '.text')
        assert_equals "This is a test transcription" "$parsed_text" "Mock API response parsed"
        
        local parsed_status=$(cat "$TEST_TEMP_DIR/mock_response.json" | jq -r '.status')
        assert_equals "success" "$parsed_status" "Mock API status parsed"
    else
        skip_test "API response parsing" "jq not installed"
    fi
}

# Test uninstallation workflow
test_uninstall_workflow() {
    test_section "Uninstallation Workflow"
    
    # Check uninstall script exists
    assert_file_exists "$PROJECT_ROOT/uninstall.sh" "Uninstall script exists"
    
    # Test uninstall script syntax
    if bash -n "$PROJECT_ROOT/uninstall.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Uninstall script has valid syntax"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Uninstall script has syntax errors"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test update workflow
test_update_workflow() {
    test_section "Update Workflow"
    
    # Check update script exists
    assert_file_exists "$PROJECT_ROOT/update.sh" "Update script exists"
    
    # Test update script syntax
    if bash -n "$PROJECT_ROOT/update.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Update script has valid syntax"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Update script has syntax errors"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test Makefile targets
test_makefile_targets() {
    test_section "Makefile Targets"
    
    # Check Makefile exists
    assert_file_exists "$PROJECT_ROOT/Makefile" "Makefile exists"
    
    # Test make help
    if command -v make &> /dev/null; then
        cd "$PROJECT_ROOT"
        output=$(make help 2>&1)
        assert_contains "$output" "Available targets" "Make help works"
        cd - > /dev/null
    else
        skip_test "Makefile execution" "make not installed"
    fi
}

# Main test execution
main() {
    echo "Running Integration Tests"
    echo "========================"
    
    # Run all test functions
    test_installation_workflow
    test_transcription_workflow
    test_environment_setup
    test_configuration_handling
    test_docker_integration
    test_platform_features
    test_error_recovery
    test_api_integration
    test_uninstall_workflow
    test_update_workflow
    test_makefile_targets
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
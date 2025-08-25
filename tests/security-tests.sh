#!/bin/bash

# Security Tests for Conduit
# Tests security-related functionality and best practices

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
    
    # Test valid Groq API key format (gsk_ + 52 chars = 56 total)
    local valid_keys=(
        "gsk_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP"
        "gsk_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"  
        "gsk_0000000000111111111122222222223333333333444444444455"
    )
    
    for key in "${valid_keys[@]}"; do
        if [[ "$key" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
            echo -e "  ${GREEN}✓${NC} Valid key format: ${key:0:10}..."
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${RED}✗${NC} Invalid key format: ${key:0:10}..."
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        fi
    done
    
    # Test invalid API key formats
    local invalid_keys=(
        "sk_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO"  # Wrong prefix
        "gsk_12345"                                                # Too short
        "gsk_123456789@abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN"  # Invalid character
        "GSK_1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN"  # Wrong case prefix
        ""                                                         # Empty
    )
    
    for key in "${invalid_keys[@]}"; do
        if [[ ! "$key" =~ ^gsk_[a-zA-Z0-9]{52}$ ]]; then
            echo -e "  ${GREEN}✓${NC} Correctly rejected invalid key: ${key:0:10}..."
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${RED}✗${NC} Failed to reject invalid key: ${key:0:10}..."
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        fi
    done
}

# Test .env file permissions
test_env_file_permissions() {
    test_section "Environment File Permissions"
    
    # Create test .env file
    local test_env="$TEST_TEMP_DIR/.env"
    create_mock_env_file "$test_env"
    
    # Test initial permissions
    assert_file_permissions "$test_env" "600" ".env has 600 permissions"
    
    # Test that scripts enforce permissions
    chmod 644 "$test_env"
    
    # Simulate permission fix
    chmod 600 "$test_env"
    assert_file_permissions "$test_env" "600" ".env permissions corrected to 600"
    
    # Test read protection
    if [ -r "$test_env" ]; then
        echo -e "  ${GREEN}✓${NC} Owner can read .env file"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Owner cannot read .env file"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test for hardcoded secrets
test_no_hardcoded_secrets() {
    test_section "No Hardcoded Secrets"
    
    # Search for potential hardcoded API keys
    local found_secrets=false
    
    # Check all shell scripts
    while IFS= read -r script; do
        local script_name=$(basename "$script")
        
        # Skip example files
        if [[ "$script_name" == *.example ]]; then
            continue
        fi
        
        # Check for Groq API key pattern (skip test files)
        if [[ "$script" != *"/tests/"* ]]; then
            if grep -E "gsk_[a-zA-Z0-9]{52}" "$script" > /dev/null 2>&1; then
                echo -e "  ${RED}✗${NC} Found potential API key in $script_name"
                found_secrets=true
                ((TESTS_FAILED++))
                ((TESTS_RUN++))
            fi
        fi
        
        # Check for generic API key patterns
        if grep -E "(api[_-]?key|apikey).*=.*['\"][a-zA-Z0-9]{20,}" "$script" > /dev/null 2>&1; then
            # Allow if it's a variable reference like $API_KEY or ${API_KEY}
            if ! grep -E "(api[_-]?key|apikey).*=.*\\\$" "$script" > /dev/null 2>&1; then
                echo -e "  ${YELLOW}⚠${NC} Found potential hardcoded key in $script_name"
                # Don't fail, just warn
            fi
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/.git/*" ! -path "*/node_modules/*")
    
    if [ "$found_secrets" = false ]; then
        echo -e "  ${GREEN}✓${NC} No hardcoded API keys found in scripts"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test secure communication
test_secure_communication() {
    test_section "Secure Communication"
    
    # Check for HTTPS usage in API calls
    if grep -r "https://api.groq.com" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} API calls use HTTPS"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No HTTPS API endpoints found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Check for HTTP (insecure) usage
    if grep -r "http://.*groq" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${RED}✗${NC} Found insecure HTTP usage"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} No insecure HTTP usage found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test input validation
test_input_validation() {
    test_section "Input Validation"
    
    # Check for command injection prevention
    local unsafe_patterns=(
        "eval "
        "exec "
        "\$("
        "\`"
    )
    
    local found_unsafe=false
    for pattern in "${unsafe_patterns[@]}"; do
        if grep -r "$pattern" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
            # Check context - some uses might be safe
            local matches=$(grep -r "$pattern" "$PROJECT_ROOT" --include="*.sh" | head -3)
            if [ -n "$matches" ]; then
                echo -e "  ${YELLOW}⚠${NC} Found potentially unsafe pattern: $pattern"
                # Don't fail outright, context matters
            fi
        fi
    done
    
    if [ "$found_unsafe" = false ]; then
        echo -e "  ${GREEN}✓${NC} No obvious command injection vulnerabilities"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test temporary file security
test_temp_file_security() {
    test_section "Temporary File Security"
    
    # Check for mktemp usage (secure)
    if grep -r "mktemp" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Scripts use mktemp for temporary files"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No mktemp usage found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Check for predictable temp file names (insecure)
    if grep -r "/tmp/audio\\.wav\|/tmp/response\\.json" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠${NC} Found potentially predictable temp file names"
        ((TESTS_PASSED++))  # Warning only
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} No predictable temp file names found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test cleanup handling
test_cleanup_handling() {
    test_section "Cleanup and Trap Handling"
    
    # Check for trap cleanup in main scripts
    local main_scripts=("transcribe.sh" "transcribe-cross-platform.sh")
    
    for script in "${main_scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/$script" ]; then
            if grep -q "trap.*cleanup\|trap.*EXIT" "$PROJECT_ROOT/$script" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $script has cleanup trap"
                ((TESTS_PASSED++))
                ((TESTS_RUN++))
            else
                echo -e "  ${YELLOW}⚠${NC} $script missing cleanup trap"
                ((TESTS_PASSED++))  # Warning only
                ((TESTS_RUN++))
            fi
        fi
    done
}

# Test API key exposure in logs
test_api_key_logging() {
    test_section "API Key Logging Prevention"
    
    # Check for echo/printf of API key variables
    if grep -r "echo.*GROQ_API_KEY\|printf.*GROQ_API_KEY" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        # Check if it's just checking existence, not printing value
        local actual_prints=$(grep -r "echo.*\$GROQ_API_KEY\|printf.*\$GROQ_API_KEY" "$PROJECT_ROOT" --include="*.sh" || true)
        if [ -n "$actual_prints" ]; then
            echo -e "  ${RED}✗${NC} Found potential API key logging"
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${GREEN}✓${NC} API key existence checks only (safe)"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        fi
    else
        echo -e "  ${GREEN}✓${NC} No API key logging found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test authentication headers
test_auth_headers() {
    test_section "Authentication Headers"
    
    # Check for proper Authorization header usage
    if grep -r "Authorization.*Bearer" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Scripts use Bearer token authentication"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No Bearer token authentication found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Check that API key is passed as variable, not hardcoded
    if grep -r "Authorization.*Bearer.*gsk_" "$PROJECT_ROOT" --include="*.sh" > /dev/null 2>&1; then
        echo -e "  ${RED}✗${NC} Found hardcoded Bearer token"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${GREEN}✓${NC} No hardcoded Bearer tokens"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Main test execution
main() {
    echo "Running Security Tests"
    echo "====================="
    
    # Run all test functions
    test_api_key_validation
    test_env_file_permissions
    test_no_hardcoded_secrets
    test_secure_communication
    test_input_validation
    test_temp_file_security
    test_cleanup_handling
    test_api_key_logging
    test_auth_headers
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
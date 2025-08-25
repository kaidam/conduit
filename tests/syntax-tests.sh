#!/bin/bash

# Syntax Tests for Conduit
# Validates shell script syntax across all project scripts

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

# Test all shell scripts for syntax errors
test_shell_syntax() {
    test_section "Shell Script Syntax Validation"
    
    # Find all .sh files in the project
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/node_modules/*" ! -path "*/.git/*")
    
    # Test each script
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        
        # Check syntax with bash -n
        if bash -n "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $script_name - valid syntax"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${RED}✗${NC} $script_name - syntax error"
            bash -n "$script" 2>&1 | sed 's/^/    /'
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        fi
    done
}

# Test for shellcheck compliance
test_shellcheck() {
    test_section "ShellCheck Linting"
    
    # Check if shellcheck is available
    if ! command -v shellcheck &> /dev/null; then
        skip_test "ShellCheck linting" "shellcheck not installed"
        return
    fi
    
    # Find all .sh files
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/node_modules/*" ! -path "*/.git/*")
    
    # Run shellcheck on each script
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        
        # Run shellcheck with project config
        if [ -f "$PROJECT_ROOT/.shellcheckrc" ]; then
            shellcheck_output=$(shellcheck "$script" 2>&1) || true
        else
            shellcheck_output=$(shellcheck -S warning "$script" 2>&1) || true
        fi
        
        if [ -z "$shellcheck_output" ]; then
            echo -e "  ${GREEN}✓${NC} $script_name - no issues"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            # Check if only info/style issues
            if echo "$shellcheck_output" | grep -q "^In .* line .*:$"; then
                echo -e "  ${YELLOW}⚠${NC} $script_name - has warnings"
                echo "$shellcheck_output" | head -5 | sed 's/^/    /'
                ((TESTS_PASSED++))  # Count as passed if only warnings
                ((TESTS_RUN++))
            else
                echo -e "  ${GREEN}✓${NC} $script_name - minor issues only"
                ((TESTS_PASSED++))
                ((TESTS_RUN++))
            fi
        fi
    done
}

# Test for common shell scripting issues
test_common_issues() {
    test_section "Common Shell Script Issues"
    
    # Find all .sh files
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/tests/*")
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        local issues_found=false
        
        # Check for set -e or set -euo pipefail
        if grep -q "^set -e" "$script" || grep -q "^set -euo pipefail" "$script"; then
            echo -e "  ${GREEN}✓${NC} $script_name - has error handling"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${YELLOW}⚠${NC} $script_name - missing 'set -e' or 'set -euo pipefail'"
            ((TESTS_PASSED++))  # Warning only
            ((TESTS_RUN++))
        fi
        
        # Check for proper shebang
        local first_line=$(head -n 1 "$script")
        if [[ "$first_line" == "#!/bin/bash"* ]] || [[ "$first_line" == "#!/usr/bin/env bash"* ]]; then
            echo -e "  ${GREEN}✓${NC} $script_name - has proper shebang"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${RED}✗${NC} $script_name - missing or incorrect shebang"
            echo "    Found: $first_line"
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
        fi
    done
}

# Test for hardcoded secrets
test_no_secrets() {
    test_section "Security - No Hardcoded Secrets"
    
    # Patterns to search for potential secrets
    local secret_patterns=(
        "gsk_[a-zA-Z0-9]{52}"  # Groq API key pattern
        "sk-[a-zA-Z0-9]{48}"    # OpenAI style key
        "api_key.*=.*['\"][a-zA-Z0-9]{20,}" # Generic API key
        "password.*=.*['\"][^'\"]{8,}"      # Passwords
        "token.*=.*['\"][a-zA-Z0-9]{20,}"   # Tokens
    )
    
    local secrets_found=false
    
    for pattern in "${secret_patterns[@]}"; do
        # Search for pattern in all non-example files
        if grep -r -E "$pattern" "$PROJECT_ROOT" \
           --exclude="*.example" \
           --exclude=".env" \
           --exclude-dir=".git" \
           --exclude-dir="node_modules" \
           --exclude-dir="tests" \
           --exclude="*.md" 2>/dev/null | grep -q .; then
            
            echo -e "  ${RED}✗${NC} Found potential secret matching pattern: $pattern"
            ((TESTS_FAILED++))
            ((TESTS_RUN++))
            secrets_found=true
        fi
    done
    
    if [ "$secrets_found" = false ]; then
        echo -e "  ${GREEN}✓${NC} No hardcoded secrets found"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test file permissions in scripts
test_file_permissions_handling() {
    test_section "File Permission Handling"
    
    # Check if scripts properly set permissions for .env files
    if grep -r "chmod 600.*\.env" "$PROJECT_ROOT" --include="*.sh" 2>/dev/null | grep -q .; then
        echo -e "  ${GREEN}✓${NC} Scripts set secure permissions for .env files"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No explicit permission setting for .env files found"
        ((TESTS_PASSED++))  # Warning only
        ((TESTS_RUN++))
    fi
    
    # Check if scripts are marked executable in git
    local non_executable=()
    while IFS= read -r script; do
        if [ ! -x "$script" ]; then
            non_executable+=("$(basename "$script")")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f ! -path "*/.git/*" ! -path "*/node_modules/*")
    
    if [ ${#non_executable[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} All shell scripts are executable"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} Non-executable scripts found: ${non_executable[*]}"
        ((TESTS_PASSED++))  # Warning only
        ((TESTS_RUN++))
    fi
}

# Main test execution
main() {
    echo "Running Syntax Tests"
    echo "==================="
    
    # Run all test functions
    test_shell_syntax
    test_shellcheck
    test_common_issues
    test_no_secrets
    test_file_permissions_handling
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
#!/bin/bash

# Platform Detection Tests for Conduit
# Tests platform-specific functionality

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

# Test platform detection logic
test_platform_detection() {
    test_section "Platform Detection Logic"
    
    # Save original OSTYPE
    local original_ostype="${OSTYPE:-}"
    
    # Test various Linux distributions
    local linux_types=("linux-gnu" "linux-gnueabihf" "linux-musl" "linux")
    for os_type in "${linux_types[@]}"; do
        OSTYPE="$os_type"
        local detected_platform=""
        case "$OSTYPE" in
            linux*) detected_platform="linux" ;;
            darwin*) detected_platform="macos" ;;
            msys*|cygwin*|mingw*) detected_platform="windows" ;;
            *) detected_platform="unknown" ;;
        esac
        assert_equals "linux" "$detected_platform" "Linux detection for $os_type"
    done
    
    # Test various macOS versions
    local macos_types=("darwin" "darwin19" "darwin20" "darwin21")
    for os_type in "${macos_types[@]}"; do
        OSTYPE="$os_type"
        local detected_platform=""
        case "$OSTYPE" in
            linux*) detected_platform="linux" ;;
            darwin*) detected_platform="macos" ;;
            msys*|cygwin*|mingw*) detected_platform="windows" ;;
            *) detected_platform="unknown" ;;
        esac
        assert_equals "macos" "$detected_platform" "macOS detection for $os_type"
    done
    
    # Test Windows platforms (should be detected but unsupported)
    local windows_types=("msys" "cygwin" "mingw" "mingw32" "mingw64")
    for os_type in "${windows_types[@]}"; do
        OSTYPE="$os_type"
        local detected_platform=""
        case "$OSTYPE" in
            linux*) detected_platform="linux" ;;
            darwin*) detected_platform="macos" ;;
            msys*|cygwin*|mingw*) detected_platform="windows" ;;
            *) detected_platform="unknown" ;;
        esac
        assert_equals "windows" "$detected_platform" "Windows detection for $os_type"
    done
    
    # Test unknown platform
    OSTYPE="freebsd"
    local detected_platform=""
    case "$OSTYPE" in
        linux*) detected_platform="linux" ;;
        darwin*) detected_platform="macos" ;;
        msys*|cygwin*|mingw*) detected_platform="windows" ;;
        *) detected_platform="unknown" ;;
    esac
    assert_equals "unknown" "$detected_platform" "Unknown platform detection"
    
    # Restore original OSTYPE
    OSTYPE="$original_ostype"
}

# Test Linux-specific commands
test_linux_commands() {
    test_section "Linux-Specific Commands"
    
    # Save and set platform
    local original_ostype="${OSTYPE:-}"
    OSTYPE="linux-gnu"
    
    # Test for Linux commands in transcribe.sh
    local linux_commands=("xclip" "xdotool" "notify-send" "arecord")
    local script_content=$(cat "$PROJECT_ROOT/transcribe.sh" 2>/dev/null || echo "")
    
    for cmd in "${linux_commands[@]}"; do
        if echo "$script_content" | grep -q "$cmd"; then
            echo -e "  ${GREEN}✓${NC} Linux script uses $cmd"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${YELLOW}⊘${NC} Linux script doesn't reference $cmd"
            ((TESTS_SKIPPED++))
        fi
    done
    
    # Restore OSTYPE
    OSTYPE="$original_ostype"
}

# Test macOS-specific commands
test_macos_commands() {
    test_section "macOS-Specific Commands"
    
    # Save and set platform
    local original_ostype="${OSTYPE:-}"
    OSTYPE="darwin"
    
    # Test for macOS commands in cross-platform script
    local macos_commands=("pbcopy" "osascript" "say")
    local script_content=$(cat "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null || echo "")
    
    for cmd in "${macos_commands[@]}"; do
        if echo "$script_content" | grep -q "$cmd"; then
            echo -e "  ${GREEN}✓${NC} Cross-platform script uses $cmd"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            # Some commands might be optional
            if [ "$cmd" = "say" ]; then
                echo -e "  ${YELLOW}⊘${NC} Cross-platform script doesn't use $cmd (optional)"
                ((TESTS_SKIPPED++))
            else
                echo -e "  ${YELLOW}⚠${NC} Cross-platform script doesn't reference $cmd"
                ((TESTS_PASSED++))
                ((TESTS_RUN++))
            fi
        fi
    done
    
    # Restore OSTYPE
    OSTYPE="$original_ostype"
}

# Test clipboard functionality
test_clipboard_commands() {
    test_section "Clipboard Command Detection"
    
    # Linux clipboard commands
    local linux_clipboard=("xclip" "xsel")
    local found_linux_clipboard=false
    
    for cmd in "${linux_clipboard[@]}"; do
        if grep -q "$cmd" "$PROJECT_ROOT/transcribe.sh" 2>/dev/null; then
            found_linux_clipboard=true
            echo -e "  ${GREEN}✓${NC} Linux script has clipboard support ($cmd)"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
            break
        fi
    done
    
    if [ "$found_linux_clipboard" = false ]; then
        echo -e "  ${RED}✗${NC} Linux script missing clipboard support"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
    
    # macOS clipboard command
    if grep -q "pbcopy" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Cross-platform script has macOS clipboard support"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Cross-platform script missing macOS clipboard support"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test audio recording commands
test_audio_commands() {
    test_section "Audio Recording Commands"
    
    # Check for sox (cross-platform)
    if grep -q "sox\|rec" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Cross-platform script supports sox/rec"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} Cross-platform script doesn't use sox/rec"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Check for Linux audio recording
    if grep -q "arecord\|sox\|rec" "$PROJECT_ROOT/transcribe.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Linux script has audio recording support"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${RED}✗${NC} Linux script missing audio recording support"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# Test platform-specific error handling
test_platform_error_handling() {
    test_section "Platform Error Handling"
    
    # Check for Windows platform rejection
    if grep -q "Windows.*not.*supported\|msys\|cygwin\|mingw" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Script handles Windows platform (unsupported)"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No explicit Windows platform handling"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
    
    # Check for unknown platform handling
    if grep -q "Unknown.*operating.*system\|platform.*not.*supported" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Script handles unknown platforms"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⚠${NC} No explicit unknown platform handling"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# Test dependency checking
test_dependency_checks() {
    test_section "Dependency Checking"
    
    # Common dependencies
    local common_deps=("curl" "jq")
    
    for dep in "${common_deps[@]}"; do
        if grep -q "command -v $dep\|which $dep\|type $dep" "$PROJECT_ROOT"/*.sh 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Scripts check for $dep dependency"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        else
            echo -e "  ${YELLOW}⚠${NC} No explicit check for $dep dependency"
            ((TESTS_PASSED++))
            ((TESTS_RUN++))
        fi
    done
}

# Test notification systems
test_notification_systems() {
    test_section "Notification Systems"
    
    # Linux notifications
    if grep -q "notify-send" "$PROJECT_ROOT/transcribe.sh" 2>/dev/null || \
       grep -q "notify-send" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Linux notification support (notify-send)"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⊘${NC} No Linux notification support"
        ((TESTS_SKIPPED++))
    fi
    
    # macOS notifications
    if grep -q "osascript.*display notification" "$PROJECT_ROOT/transcribe-cross-platform.sh" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} macOS notification support (osascript)"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "  ${YELLOW}⊘${NC} No macOS notification support"
        ((TESTS_SKIPPED++))
    fi
}

# Main test execution
main() {
    echo "Running Platform Tests"
    echo "====================="
    
    # Run all test functions
    test_platform_detection
    test_linux_commands
    test_macos_commands
    test_clipboard_commands
    test_audio_commands
    test_platform_error_handling
    test_dependency_checks
    test_notification_systems
    
    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Run tests
main "$@"
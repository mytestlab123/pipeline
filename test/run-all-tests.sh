#!/bin/bash

# run-all-tests.sh - Main test runner using /tmp directory framework
# Runs all tests with clean isolation and absolute paths

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Test suite configuration
TESTS_TO_RUN=(
    "smoke-test"
    "online-prepare"
    "generate-image-list"
    "pull-images"
    "offline-setup"
)

# Test results tracking
PASSED_TESTS=()
FAILED_TESTS=()
SKIPPED_TESTS=()

# Main test execution
main() {
    echo "========================================"
    echo "Nextflow Offline Execution Demo - Test Suite"
    echo "Using /tmp directory framework with absolute paths"
    echo "========================================"
    echo
    
    # Initialize framework
    init_framework
    
    # Setup test environment
    setup_test_environment
    
    # Validate test environment
    if ! validate_test_environment; then
        framework_error "Test environment validation failed"
        exit 1
    fi
    
    echo
    echo "Running test suite..."
    echo
    
    # Run each test
    for test_name in "${TESTS_TO_RUN[@]}"; do
        run_single_test "${test_name}"
    done
    
    echo
    echo "========================================"
    echo "Test Suite Summary"
    echo "========================================"
    
    # Print results
    if [[ ${#PASSED_TESTS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Passed Tests (${#PASSED_TESTS[@]}):${NC}"
        for test in "${PASSED_TESTS[@]}"; do
            echo -e "  ${GREEN}✓${NC} ${test}"
        done
    fi
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Failed Tests (${#FAILED_TESTS[@]}):${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} ${test}"
        done
    fi
    
    if [[ ${#SKIPPED_TESTS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Skipped Tests (${#SKIPPED_TESTS[@]}):${NC}"
        for test in "${SKIPPED_TESTS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} ${test}"
        done
    fi
    
    echo
    echo "Total Tests: ${#TESTS_TO_RUN[@]}"
    echo "Passed: ${#PASSED_TESTS[@]}"
    echo "Failed: ${#FAILED_TESTS[@]}"
    echo "Skipped: ${#SKIPPED_TESTS[@]}"
    
    # Exit with appropriate code
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo
        framework_error "Test suite failed with ${#FAILED_TESTS[@]} failures"
        exit 1
    else
        echo
        framework_success "All tests passed successfully!"
        exit 0
    fi
}

# Run a single test
run_single_test() {
    local test_name="$1"
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    echo "----------------------------------------"
    echo "Running: ${test_name}"
    echo "----------------------------------------"
    
    # Check if test script exists
    if [[ ! -f "${test_script}" ]]; then
        test_warning "Test script not found: ${test_script}"
        SKIPPED_TESTS+=("${test_name}")
        return
    fi
    
    # Make sure test script is executable
    chmod +x "${test_script}"
    
    # Run the test in the test directory
    cd "${TEST_BASE_DIR}"
    
    # Capture test output
    local test_output
    local test_exit_code
    
    if test_output=$(bash "${test_script}" 2>&1); then
        test_exit_code=0
    else
        test_exit_code=$?
    fi
    
    # Show test output
    echo "${test_output}"
    
    # Record results
    if [[ ${test_exit_code} -eq 0 ]]; then
        test_success "Test completed successfully: ${test_name}"
        PASSED_TESTS+=("${test_name}")
        generate_test_report "${test_name}" "PASSED"
    else
        test_error "Test failed: ${test_name}"
        FAILED_TESTS+=("${test_name}")
        generate_test_report "${test_name}" "FAILED"
    fi
    
    echo
}

# Handle cleanup on exit
cleanup_on_exit() {
    framework_log "Cleaning up test suite..."
    cleanup_test_environment
}

# Set up signal handlers
trap cleanup_on_exit EXIT
trap cleanup_on_exit INT
trap cleanup_on_exit TERM

# Run main function
main "$@"
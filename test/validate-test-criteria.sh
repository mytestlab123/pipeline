#!/bin/bash

# validate-test-criteria.sh - Validate all tests meet criteria requirements
# Ensures clean test criteria and validation for all tests

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Validation configuration
VALIDATION_REPORT="/tmp/${PROJECT_NAME}/test-validation-report.txt"
TESTS_TO_VALIDATE=(
    "smoke-test"
    "online-prepare"
    "generate-image-list"
    "pull-images"
    "offline-setup"
)

# Validation results tracking
VALIDATION_PASSED=()
VALIDATION_FAILED=()
VALIDATION_WARNINGS=()

# Initialize validation
init_validation() {
    framework_log "Initializing test criteria validation..."
    
    # Create validation report
    mkdir -p "$(dirname "${VALIDATION_REPORT}")"
    
    cat > "${VALIDATION_REPORT}" << EOF
# Test Criteria Validation Report
Generated: $(date)
Framework: /tmp directory with absolute paths

## Overview
This report validates that all tests meet the defined criteria requirements.

EOF
    
    framework_success "Validation initialized"
}

# Validate test script structure
validate_test_script() {
    local test_name="$1"
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    framework_log "Validating test script: ${test_name}"
    
    # Check if test script exists
    if [[ ! -f "${test_script}" ]]; then
        framework_error "Test script not found: ${test_script}"
        VALIDATION_FAILED+=("${test_name}: Script not found")
        return 1
    fi
    
    # Check if script is executable
    if [[ ! -x "${test_script}" ]]; then
        framework_error "Test script not executable: ${test_script}"
        VALIDATION_FAILED+=("${test_name}: Script not executable")
        return 1
    fi
    
    # Check for required script elements
    local required_elements=(
        "set -euo pipefail"
        "source.*framework.sh"
        "TEST_NAME="
        "TEST_ASSETS_DIR="
        "SCRIPT_PATH="
        "test-criteria-.*\.md"
        "main()"
    )
    
    for element in "${required_elements[@]}"; do
        if ! grep -q "${element}" "${test_script}"; then
            framework_warning "Missing required element in ${test_name}: ${element}"
            VALIDATION_WARNINGS+=("${test_name}: Missing ${element}")
        fi
    done
    
    framework_success "Test script structure validated: ${test_name}"
    return 0
}

# Validate test criteria documentation
validate_test_criteria_doc() {
    local test_name="$1"
    local criteria_file="/tmp/${PROJECT_NAME}/test-criteria-${test_name}.md"
    
    framework_log "Validating test criteria documentation: ${test_name}"
    
    # Run the test briefly to generate criteria file
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    if [[ -f "${test_script}" ]]; then
        # Try to run test just to generate criteria file
        timeout 30 bash "${test_script}" > /dev/null 2>&1 || true
    fi
    
    # Check if criteria file was generated
    if [[ ! -f "${criteria_file}" ]]; then
        framework_error "Test criteria file not found: ${criteria_file}"
        VALIDATION_FAILED+=("${test_name}: Criteria file not found")
        return 1
    fi
    
    # Check for required sections
    local required_sections=(
        "# Plan"
        "# Action"
        "# Testing"
        "# Success Criteria"
    )
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "^${section}" "${criteria_file}"; then
            framework_error "Missing required section in ${test_name}: ${section}"
            VALIDATION_FAILED+=("${test_name}: Missing section ${section}")
            return 1
        fi
    done
    
    # Check section content quality
    for section in "${required_sections[@]}"; do
        local section_content=$(grep -A 20 "^${section}" "${criteria_file}" | head -20)
        local content_lines=$(echo "${section_content}" | grep -v "^#" | grep -v "^$" | wc -l)
        
        if [[ ${content_lines} -lt 2 ]]; then
            framework_warning "Section ${section} in ${test_name} may be too brief"
            VALIDATION_WARNINGS+=("${test_name}: Brief section ${section}")
        fi
    done
    
    framework_success "Test criteria documentation validated: ${test_name}"
    return 0
}

# Validate test uses absolute paths
validate_absolute_paths() {
    local test_name="$1"
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    framework_log "Validating absolute path usage: ${test_name}"
    
    # Check for /tmp usage
    if ! grep -q "/tmp/" "${test_script}"; then
        framework_error "Test ${test_name} does not use /tmp directory"
        VALIDATION_FAILED+=("${test_name}: No /tmp usage")
        return 1
    fi
    
    # Check for TEST_ASSETS_DIR usage
    if ! grep -q "TEST_ASSETS_DIR=" "${test_script}"; then
        framework_error "Test ${test_name} does not define TEST_ASSETS_DIR"
        VALIDATION_FAILED+=("${test_name}: No TEST_ASSETS_DIR")
        return 1
    fi
    
    # Check for absolute path in TEST_ASSETS_DIR
    if ! grep -q 'TEST_ASSETS_DIR="/tmp/' "${test_script}"; then
        framework_error "Test ${test_name} TEST_ASSETS_DIR is not absolute /tmp path"
        VALIDATION_FAILED+=("${test_name}: Non-absolute TEST_ASSETS_DIR")
        return 1
    fi
    
    # Check for relative path patterns that should be avoided
    local problematic_patterns=(
        "cd \\.\\."
        "\\./[^t]"  # Allow ./test/ but not other relative paths
        "\\./"
    )
    
    for pattern in "${problematic_patterns[@]}"; do
        if grep -q "${pattern}" "${test_script}"; then
            framework_warning "Test ${test_name} may use relative paths: ${pattern}"
            VALIDATION_WARNINGS+=("${test_name}: Potential relative path usage")
        fi
    done
    
    framework_success "Absolute path usage validated: ${test_name}"
    return 0
}

# Validate test cleanup
validate_test_cleanup() {
    local test_name="$1"
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    framework_log "Validating test cleanup: ${test_name}"
    
    # Check for cleanup functions or practices
    local cleanup_indicators=(
        "rm -rf"
        "rm -f"
        "cleanup"
        "test_success.*cleanup"
    )
    
    local cleanup_found=false
    
    for indicator in "${cleanup_indicators[@]}"; do
        if grep -q "${indicator}" "${test_script}"; then
            cleanup_found=true
            break
        fi
    done
    
    if [[ ${cleanup_found} == "false" ]]; then
        framework_warning "Test ${test_name} may not have proper cleanup"
        VALIDATION_WARNINGS+=("${test_name}: No explicit cleanup found")
    fi
    
    framework_success "Test cleanup validated: ${test_name}"
    return 0
}

# Validate test error handling
validate_error_handling() {
    local test_name="$1"
    local test_script="${TEST_BASE_DIR}/test/test-${test_name}.sh"
    
    framework_log "Validating error handling: ${test_name}"
    
    # Check for error handling patterns
    local error_handling_patterns=(
        "test_error"
        "return 1"
        "exit 1"
        "timeout"
        "if.*then.*else"
    )
    
    local error_handling_found=false
    
    for pattern in "${error_handling_patterns[@]}"; do
        if grep -q "${pattern}" "${test_script}"; then
            error_handling_found=true
            break
        fi
    done
    
    if [[ ${error_handling_found} == "false" ]]; then
        framework_error "Test ${test_name} lacks proper error handling"
        VALIDATION_FAILED+=("${test_name}: No error handling")
        return 1
    fi
    
    framework_success "Error handling validated: ${test_name}"
    return 0
}

# Validate single test
validate_single_test() {
    local test_name="$1"
    
    framework_log "Starting validation for: ${test_name}"
    
    local validation_passed=true
    
    # Run all validations
    validate_test_script "${test_name}" || validation_passed=false
    validate_test_criteria_doc "${test_name}" || validation_passed=false
    validate_absolute_paths "${test_name}" || validation_passed=false
    validate_test_cleanup "${test_name}" || validation_passed=false
    validate_error_handling "${test_name}" || validation_passed=false
    
    if [[ ${validation_passed} == "true" ]]; then
        framework_success "Validation passed for: ${test_name}"
        VALIDATION_PASSED+=("${test_name}")
        
        # Add to validation report
        cat >> "${VALIDATION_REPORT}" << EOF
## ${test_name}
- ✓ Script structure validated
- ✓ Criteria documentation complete
- ✓ Absolute paths used correctly
- ✓ Cleanup procedures present
- ✓ Error handling implemented

EOF
    else
        framework_error "Validation failed for: ${test_name}"
        
        # Add to validation report
        cat >> "${VALIDATION_REPORT}" << EOF
## ${test_name}
- ✗ Validation failed (see details above)

EOF
    fi
    
    return $([[ ${validation_passed} == "true" ]] && echo 0 || echo 1)
}

# Generate final validation report
generate_final_report() {
    framework_log "Generating final validation report..."
    
    cat >> "${VALIDATION_REPORT}" << EOF

## Summary

### Validation Results
- Total tests validated: ${#TESTS_TO_VALIDATE[@]}
- Tests passed: ${#VALIDATION_PASSED[@]}
- Tests failed: ${#VALIDATION_FAILED[@]}
- Warnings generated: ${#VALIDATION_WARNINGS[@]}

### Passed Tests
EOF
    
    for test in "${VALIDATION_PASSED[@]}"; do
        echo "- ✓ ${test}" >> "${VALIDATION_REPORT}"
    done
    
    if [[ ${#VALIDATION_FAILED[@]} -gt 0 ]]; then
        cat >> "${VALIDATION_REPORT}" << EOF

### Failed Tests
EOF
        for failure in "${VALIDATION_FAILED[@]}"; do
            echo "- ✗ ${failure}" >> "${VALIDATION_REPORT}"
        done
    fi
    
    if [[ ${#VALIDATION_WARNINGS[@]} -gt 0 ]]; then
        cat >> "${VALIDATION_REPORT}" << EOF

### Warnings
EOF
        for warning in "${VALIDATION_WARNINGS[@]}"; do
            echo "- ⚠ ${warning}" >> "${VALIDATION_REPORT}"
        done
    fi
    
    cat >> "${VALIDATION_REPORT}" << EOF

### Recommendations
1. All tests should use absolute paths starting with /tmp/
2. All tests should include comprehensive error handling
3. All tests should have proper cleanup procedures
4. Test criteria documentation should be complete and detailed
5. Tests should be independent and repeatable

Generated: $(date)
EOF
    
    framework_success "Final validation report generated: ${VALIDATION_REPORT}"
}

# Main validation execution
main() {
    echo "========================================"
    echo "Test Criteria Validation"
    echo "Framework: /tmp directory with absolute paths"
    echo "========================================"
    echo
    
    # Initialize framework and validation
    init_framework
    init_validation
    
    # Setup test environment for validation
    setup_test_environment
    
    # Validate each test
    for test_name in "${TESTS_TO_VALIDATE[@]}"; do
        echo "----------------------------------------"
        echo "Validating: ${test_name}"
        echo "----------------------------------------"
        
        validate_single_test "${test_name}"
        echo
    done
    
    # Generate final report
    generate_final_report
    
    # Display summary
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo "Passed: ${#VALIDATION_PASSED[@]}/${#TESTS_TO_VALIDATE[@]}"
    echo "Failed: ${#VALIDATION_FAILED[@]}"
    echo "Warnings: ${#VALIDATION_WARNINGS[@]}"
    echo
    echo "Report: ${VALIDATION_REPORT}"
    
    # Exit with appropriate code
    if [[ ${#VALIDATION_FAILED[@]} -gt 0 ]]; then
        framework_error "Test criteria validation failed"
        exit 1
    else
        framework_success "All test criteria validation passed!"
        exit 0
    fi
}

# Execute main function
main "$@"
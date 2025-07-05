#!/bin/bash

# framework.sh - Test framework for Nextflow Offline Execution Demo MVP
# Uses /tmp directory with absolute paths for clean isolated testing

set -euo pipefail

# Test framework configuration
PROJECT_NAME="nextflow-offline-demo"
TEST_BASE_DIR="/tmp/${PROJECT_NAME}"
ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Framework logging
framework_log() {
    echo -e "${BLUE}[FRAMEWORK]${NC} $1"
}

framework_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

framework_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

framework_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test logging
test_log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_success() {
    echo -e "${GREEN}✓${NC} $1"
}

test_error() {
    echo -e "${RED}✗${NC} $1"
}

test_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Clean up test environment
cleanup_test_environment() {
    framework_log "Cleaning up test environment..."
    
    if [[ -d "${TEST_BASE_DIR}" ]]; then
        rm -rf "${TEST_BASE_DIR}"
        framework_log "Removed test directory: ${TEST_BASE_DIR}"
    fi
    
    # Clean up any temporary files in /tmp
    rm -f /tmp/online-prepare.log
    rm -f /tmp/generate-image-list.log
    rm -f /tmp/pull-images.log
    rm -f /tmp/offline-setup.log
    rm -f /tmp/run-offline-pipeline.log
    
    framework_log "Test environment cleanup completed"
}

# Setup test environment
setup_test_environment() {
    framework_log "Setting up test environment in ${TEST_BASE_DIR}..."
    
    # Clean up any existing test environment
    cleanup_test_environment
    
    # Create test directory structure
    mkdir -p "${TEST_BASE_DIR}"
    
    # Copy project files to test directory
    framework_log "Copying project files to test directory..."
    cp -r "${PROJECT_ROOT}"/* "${TEST_BASE_DIR}/"
    
    # Ensure scripts are executable
    chmod +x "${TEST_BASE_DIR}"/*.sh 2>/dev/null || true
    chmod +x "${TEST_BASE_DIR}/test"/*.sh 2>/dev/null || true
    
    framework_log "Test environment setup completed"
    framework_log "Test directory: ${TEST_BASE_DIR}"
}

# Validate test environment
validate_test_environment() {
    framework_log "Validating test environment..."
    
    # Check if test directory exists
    if [[ ! -d "${TEST_BASE_DIR}" ]]; then
        framework_error "Test directory not found: ${TEST_BASE_DIR}"
        return 1
    fi
    
    # Check if required scripts exist
    local required_scripts=(
        "online-prepare.sh"
        "generate-image-list.sh"
        "pull-images.sh"
        "offline-setup.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "${TEST_BASE_DIR}/${script}" ]]; then
            framework_error "Required script not found: ${script}"
            return 1
        fi
        
        if [[ ! -x "${TEST_BASE_DIR}/${script}" ]]; then
            framework_error "Script not executable: ${script}"
            return 1
        fi
    done
    
    framework_success "Test environment validation completed"
    return 0
}

# Run test in isolated environment
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    framework_log "Running test: ${test_name}"
    
    # Change to test directory
    cd "${TEST_BASE_DIR}"
    
    # Run the test
    if "${test_function}"; then
        framework_success "Test passed: ${test_name}"
        return 0
    else
        framework_error "Test failed: ${test_name}"
        return 1
    fi
}

# Get absolute path for script
get_script_path() {
    local script_name="$1"
    echo "${TEST_BASE_DIR}/${script_name}"
}

# Get absolute path for test directory
get_test_dir() {
    echo "${TEST_BASE_DIR}"
}

# Create test assets directory
create_test_assets() {
    local assets_dir="${TEST_BASE_DIR}/test-assets"
    mkdir -p "${assets_dir}"
    echo "${assets_dir}"
}

# Test criteria validation
validate_test_criteria() {
    local test_name="$1"
    local criteria_file="$2"
    
    framework_log "Validating test criteria for: ${test_name}"
    
    if [[ ! -f "${criteria_file}" ]]; then
        framework_error "Test criteria file not found: ${criteria_file}"
        return 1
    fi
    
    # Check if criteria file has required sections
    local required_sections=(
        "# Plan"
        "# Action"
        "# Testing"
        "# Success Criteria"
    )
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "^${section}" "${criteria_file}"; then
            framework_error "Missing required section in criteria: ${section}"
            return 1
        fi
    done
    
    framework_success "Test criteria validation completed for: ${test_name}"
    return 0
}

# Generate test report
generate_test_report() {
    local test_name="$1"
    local status="$2"
    local report_file="${TEST_BASE_DIR}/test-reports/${test_name}.report"
    
    mkdir -p "${TEST_BASE_DIR}/test-reports"
    
    cat > "${report_file}" << EOF
# Test Report: ${test_name}
Generated: $(date)
Status: ${status}
Test Directory: ${TEST_BASE_DIR}

## Environment
- Working Directory: ${TEST_BASE_DIR}
- Original Directory: ${ORIGINAL_DIR}
- Test Base Directory: ${TEST_BASE_DIR}

## Test Execution
- Start Time: $(date)
- Status: ${status}

## Files Created
$(find "${TEST_BASE_DIR}" -type f -newer "${TEST_BASE_DIR}" 2>/dev/null | head -20 || echo "No new files detected")

## Logs
$(find /tmp -name "*.log" -newer "${TEST_BASE_DIR}" 2>/dev/null | head -10 || echo "No log files found")
EOF
    
    framework_log "Test report generated: ${report_file}"
}

# Initialize framework
init_framework() {
    framework_log "Initializing test framework..."
    framework_log "Project: ${PROJECT_NAME}"
    framework_log "Test directory: ${TEST_BASE_DIR}"
    framework_log "Original directory: ${ORIGINAL_DIR}"
    framework_log "Project root: ${PROJECT_ROOT}"
    
    # Set up signal handlers for cleanup
    trap cleanup_test_environment EXIT
    trap cleanup_test_environment INT
    trap cleanup_test_environment TERM
    
    framework_success "Test framework initialized"
}

# Export framework functions for use in tests
export -f framework_log framework_success framework_error framework_warning
export -f test_log test_success test_error test_warning
export -f cleanup_test_environment setup_test_environment validate_test_environment
export -f run_test get_script_path get_test_dir create_test_assets
export -f validate_test_criteria generate_test_report

# Export framework variables
export PROJECT_NAME TEST_BASE_DIR ORIGINAL_DIR SCRIPT_DIR PROJECT_ROOT
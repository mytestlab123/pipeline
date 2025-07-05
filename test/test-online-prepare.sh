#!/bin/bash

# test-online-prepare.sh - Test online-prepare.sh using /tmp directory framework
# Tests online preparation script with absolute paths and clean isolation

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Test configuration
TEST_NAME="online-prepare"
TEST_ASSETS_DIR="/tmp/${PROJECT_NAME}/test-assets"
SCRIPT_PATH="/tmp/${PROJECT_NAME}/online-prepare.sh"

# Test criteria documentation
cat > "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md" << 'EOF'
# Plan
Test the online-prepare.sh script functionality for downloading nf-core/demo pipeline assets.

# Action
1. Verify script existence and permissions
2. Execute script to download nf-core/demo pipeline
3. Validate downloaded assets structure
4. Check essential files presence
5. Verify manifest generation
6. Test logging functionality

# Testing
- Script execution validation
- Asset directory structure verification
- Essential file presence checking
- Manifest content validation
- Log file creation testing

# Success Criteria
- Script executes without errors
- offline-assets directory created with correct structure
- Essential pipeline files downloaded (main.nf, nextflow.config, etc.)
- Manifest file generated with correct content
- Log file created with execution details
EOF

# Test implementation
run_online_prepare_test() {
    test_log "Starting online-prepare.sh test with absolute paths..."
    
    # Create test assets directory
    mkdir -p "${TEST_ASSETS_DIR}"
    cd "${TEST_ASSETS_DIR}"
    
    # Test 1: Script existence and permissions
    test_log "1. Testing script existence and permissions..."
    
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        test_error "Script not found: ${SCRIPT_PATH}"
        return 1
    fi
    
    if [[ ! -x "${SCRIPT_PATH}" ]]; then
        test_error "Script is not executable: ${SCRIPT_PATH}"
        return 1
    fi
    
    test_success "Script exists and is executable"
    
    # Test 2: Execute script
    test_log "2. Testing script execution..."
    
    if timeout 300 "${SCRIPT_PATH}"; then
        test_success "Script executed successfully"
    else
        test_error "Script execution failed or timed out"
        return 1
    fi
    
    # Test 3: Validate asset structure
    test_log "3. Testing downloaded asset structure..."
    
    local assets_dir="${TEST_ASSETS_DIR}/offline-assets"
    
    if [[ ! -d "${assets_dir}" ]]; then
        test_error "Assets directory not created: ${assets_dir}"
        return 1
    fi
    
    if [[ ! -d "${assets_dir}/pipeline" ]]; then
        test_error "Pipeline directory not created: ${assets_dir}/pipeline"
        return 1
    fi
    
    test_success "Asset directory structure validated"
    
    # Test 4: Check essential files
    test_log "4. Testing essential file presence..."
    
    local essential_files=(
        "${assets_dir}/pipeline/main.nf"
        "${assets_dir}/pipeline/nextflow.config"
        "${assets_dir}/pipeline/conf/base.config"
        "${assets_dir}/pipeline/modules.json"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            test_error "Essential file missing: ${file}"
            return 1
        fi
    done
    
    test_success "All essential files present"
    
    # Test 5: Check manifest generation
    test_log "5. Testing manifest generation..."
    
    local manifest_file="${assets_dir}/manifest.txt"
    
    if [[ ! -f "${manifest_file}" ]]; then
        test_error "Manifest file not generated: ${manifest_file}"
        return 1
    fi
    
    if ! grep -q "nf-core/demo Pipeline Asset Manifest" "${manifest_file}"; then
        test_error "Manifest header not found in ${manifest_file}"
        return 1
    fi
    
    if ! grep -q "main.nf" "${manifest_file}"; then
        test_error "main.nf not listed in manifest"
        return 1
    fi
    
    test_success "Manifest generated with correct content"
    
    # Test 6: Check log file
    test_log "6. Testing log file creation..."
    
    local log_file="${assets_dir}/online-prepare.log"
    
    if [[ ! -f "${log_file}" ]]; then
        test_error "Log file not created: ${log_file}"
        return 1
    fi
    
    if ! grep -q "Starting online preparation" "${log_file}"; then
        test_warning "Log file exists but may not contain expected content"
    fi
    
    test_success "Log file created successfully"
    
    # Test 7: Validate file sizes and content
    test_log "7. Testing file content validation..."
    
    # Check if main.nf has content
    if [[ ! -s "${assets_dir}/pipeline/main.nf" ]]; then
        test_error "main.nf is empty or does not exist"
        return 1
    fi
    
    # Check if nextflow.config has content
    if [[ ! -s "${assets_dir}/pipeline/nextflow.config" ]]; then
        test_error "nextflow.config is empty or does not exist"
        return 1
    fi
    
    test_success "File content validation passed"
    
    # Test 8: Test asset reusability
    test_log "8. Testing asset reusability..."
    
    local asset_count=$(find "${assets_dir}" -type f | wc -l)
    
    if [[ ${asset_count} -lt 10 ]]; then
        test_warning "Asset count seems low (${asset_count} files), but may be correct"
    else
        test_success "Asset count looks reasonable (${asset_count} files)"
    fi
    
    test_success "All online-prepare tests passed"
    return 0
}

# Main execution
main() {
    test_log "=== Online Prepare Test - Framework Version ==="
    test_log "Test directory: ${TEST_ASSETS_DIR}"
    test_log "Script path: ${SCRIPT_PATH}"
    test_log "Working directory: $(pwd)"
    
    # Validate test criteria
    if ! validate_test_criteria "${TEST_NAME}" "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md"; then
        test_error "Test criteria validation failed"
        return 1
    fi
    
    # Run the online prepare test
    if run_online_prepare_test; then
        test_success "Online prepare test completed successfully"
        echo ""
        echo "✓ online-prepare.sh functionality validated"
        echo "✓ All asset download operations working"
        echo "✓ Clean test environment with absolute paths"
        return 0
    else
        test_error "Online prepare test failed"
        return 1
    fi
}

# Execute main function
main "$@"
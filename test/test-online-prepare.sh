#!/bin/bash

# test-online-prepare.sh - Test online-prepare.sh functionality
# Part of the Nextflow Offline Execution Demo MVP test suite

set -euo pipefail

# Test configuration
TEST_DIR="./test-assets"
SCRIPT_PATH="../online-prepare.sh"

# Test logging
test_log() {
    echo "[TEST] $1"
}

# Setup test environment
setup_test() {
    test_log "Setting up test environment..."
    
    # Clean up any existing test assets
    if [[ -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
    
    # Create test directory
    mkdir -p "${TEST_DIR}"
    cd "${TEST_DIR}"
}

# Cleanup test environment
cleanup_test() {
    test_log "Cleaning up test environment..."
    cd ..
    if [[ -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
}

# Test script existence and permissions
test_script_exists() {
    test_log "Testing script existence and permissions..."
    
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        echo "ERROR: Script not found: ${SCRIPT_PATH}"
        exit 1
    fi
    
    if [[ ! -x "${SCRIPT_PATH}" ]]; then
        echo "ERROR: Script is not executable: ${SCRIPT_PATH}"
        exit 1
    fi
    
    test_log "✓ Script exists and is executable"
}

# Test script execution
test_script_execution() {
    test_log "Testing script execution..."
    
    # Run the script
    if "${SCRIPT_PATH}"; then
        test_log "✓ Script executed successfully"
    else
        echo "ERROR: Script execution failed"
        exit 1
    fi
}

# Test asset validation
test_asset_validation() {
    test_log "Testing downloaded assets..."
    
    # Check if assets directory was created
    if [[ ! -d "offline-assets" ]]; then
        echo "ERROR: Assets directory not created"
        exit 1
    fi
    
    # Check if pipeline directory exists
    if [[ ! -d "offline-assets/pipeline" ]]; then
        echo "ERROR: Pipeline directory not created"
        exit 1
    fi
    
    # Check for essential files
    essential_files=(
        "offline-assets/pipeline/main.nf"
        "offline-assets/pipeline/nextflow.config"
        "offline-assets/pipeline/conf/base.config"
        "offline-assets/pipeline/modules.json"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            echo "ERROR: Essential file missing: ${file}"
            exit 1
        fi
    done
    
    # Check if manifest was generated
    if [[ ! -f "offline-assets/manifest.txt" ]]; then
        echo "ERROR: Asset manifest not generated"
        exit 1
    fi
    
    # Check if log file was created
    if [[ ! -f "offline-assets/online-prepare.log" ]]; then
        echo "ERROR: Log file not created"
        exit 1
    fi
    
    test_log "✓ All required assets downloaded and validated"
}

# Test manifest content
test_manifest_content() {
    test_log "Testing manifest content..."
    
    manifest_file="offline-assets/manifest.txt"
    
    # Check if manifest contains expected content
    if ! grep -q "nf-core/demo Pipeline Asset Manifest" "${manifest_file}"; then
        echo "ERROR: Manifest header not found"
        exit 1
    fi
    
    if ! grep -q "main.nf" "${manifest_file}"; then
        echo "ERROR: main.nf not listed in manifest"
        exit 1
    fi
    
    test_log "✓ Manifest content validated"
}

# Main test execution
main() {
    test_log "Starting online-prepare.sh test suite..."
    
    setup_test
    
    test_script_exists
    test_script_execution
    test_asset_validation
    test_manifest_content
    
    cleanup_test
    
    test_log "All tests passed successfully!"
    echo ""
    echo "✓ online-prepare.sh test suite completed"
    echo "✓ All functionality validated"
}

# Execute main function
main "$@"
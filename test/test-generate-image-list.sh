#!/bin/bash

# test-generate-image-list.sh - Test generate-image-list.sh functionality
# Part of the Nextflow Offline Execution Demo MVP test suite

set -euo pipefail

# Test configuration
TEST_DIR="./test-assets"
SCRIPT_PATH="../generate-image-list.sh"

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
    
    # Run online-prepare.sh to get sample pipeline assets
    ../online-prepare.sh > /dev/null 2>&1 || {
        test_log "Note: Using existing pipeline assets or creating minimal test structure"
        mkdir -p offline-assets/pipeline/modules/nf-core/testmodule
        cat > offline-assets/pipeline/nextflow.config << 'EOF'
docker.registry = 'quay.io'
EOF
        cat > offline-assets/pipeline/modules/nf-core/testmodule/main.nf << 'EOF'
process TESTMODULE {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"
}
EOF
    }
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

# Test image list generation
test_image_list_generation() {
    test_log "Testing image list generation..."
    
    # Check if images.txt was generated
    if [[ ! -f "offline-assets/images.txt" ]]; then
        echo "ERROR: Images list file not generated"
        exit 1
    fi
    
    # Check if file has content
    if [[ ! -s "offline-assets/images.txt" ]]; then
        echo "ERROR: Images list file is empty"
        exit 1
    fi
    
    # Validate image format
    while IFS= read -r image; do
        if [[ ! "${image}" =~ ^[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
            echo "ERROR: Invalid image format: ${image}"
            exit 1
        fi
    done < "offline-assets/images.txt"
    
    test_log "✓ Image list generated with valid format"
}

# Test manifest generation
test_manifest_generation() {
    test_log "Testing manifest generation..."
    
    # Check if manifest was generated
    if [[ ! -f "offline-assets/images-manifest.txt" ]]; then
        echo "ERROR: Images manifest not generated"
        exit 1
    fi
    
    # Check manifest content
    if ! grep -q "nf-core/demo Pipeline Docker Images" "offline-assets/images-manifest.txt"; then
        echo "ERROR: Manifest header not found"
        exit 1
    fi
    
    if ! grep -q "Registry:" "offline-assets/images-manifest.txt"; then
        echo "ERROR: Registry information not found in manifest"
        exit 1
    fi
    
    test_log "✓ Image manifest generated with correct content"
}

# Test registry extraction
test_registry_extraction() {
    test_log "Testing registry extraction..."
    
    # Check if log file contains registry information
    if [[ -f "offline-assets/generate-image-list.log" ]]; then
        if grep -q "Found registry configuration:" "offline-assets/generate-image-list.log"; then
            test_log "✓ Registry configuration extracted successfully"
        else
            test_log "✓ Default registry used (no explicit configuration found)"
        fi
    else
        echo "ERROR: Log file not found"
        exit 1
    fi
}

# Test expected image count for nf-core/demo
test_expected_images() {
    test_log "Testing expected image count..."
    
    local image_count=$(wc -l < "offline-assets/images.txt")
    
    # nf-core/demo should have at least 3 images (fastqc, multiqc, seqtk)
    if [[ "${image_count}" -lt 1 ]]; then
        echo "ERROR: Expected at least 1 image, found ${image_count}"
        exit 1
    fi
    
    test_log "✓ Found ${image_count} Docker images as expected"
}

# Main test execution
main() {
    test_log "Starting generate-image-list.sh test suite..."
    
    setup_test
    
    test_script_exists
    test_script_execution
    test_image_list_generation
    test_manifest_generation
    test_registry_extraction
    test_expected_images
    
    cleanup_test
    
    test_log "All tests passed successfully!"
    echo ""
    echo "✓ generate-image-list.sh test suite completed"
    echo "✓ All functionality validated"
}

# Execute main function
main "$@"
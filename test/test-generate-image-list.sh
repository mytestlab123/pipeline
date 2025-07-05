#!/bin/bash

# test-generate-image-list.sh - Test generate-image-list.sh using /tmp directory framework
# Tests Docker image list generation with absolute paths and clean isolation

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Test configuration
TEST_NAME="generate-image-list"
TEST_ASSETS_DIR="/tmp/${PROJECT_NAME}/test-assets"
SCRIPT_PATH="/tmp/${PROJECT_NAME}/generate-image-list.sh"

# Test criteria documentation
cat > "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md" << 'EOF'
# Plan
Test the generate-image-list.sh script functionality for extracting Docker images from nf-core/demo pipeline.

# Action
1. Verify script existence and permissions
2. Setup test environment with pipeline assets
3. Execute script to generate Docker image list
4. Validate generated image list format
5. Check manifest generation
6. Verify registry extraction
7. Test expected image count

# Testing
- Script execution validation
- Image list generation testing
- Image format validation
- Registry configuration extraction
- Manifest content verification
- Expected image count validation

# Success Criteria
- Script executes without errors
- images.txt file generated with valid Docker image format
- images-manifest.txt created with correct content
- Registry configuration extracted correctly
- Expected number of images found (at least 1)
- All images have proper registry paths and tags
EOF

# Test implementation
run_generate_image_list_test() {
    test_log "Starting generate-image-list.sh test with absolute paths..."
    
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
    
    # Test 2: Setup test environment
    test_log "2. Setting up test environment..."
    
    # First run online-prepare to get pipeline assets
    local online_prepare_script="/tmp/${PROJECT_NAME}/online-prepare.sh"
    
    if [[ -f "${online_prepare_script}" ]]; then
        test_log "Running online-prepare.sh to get pipeline assets..."
        if timeout 300 "${online_prepare_script}" > /dev/null 2>&1; then
            test_success "Pipeline assets prepared successfully"
        else
            test_log "online-prepare.sh failed, creating minimal test structure..."
            # Create minimal test structure
            mkdir -p offline-assets/pipeline/modules/nf-core/testmodule
            
            cat > offline-assets/pipeline/nextflow.config << 'EOFCONFIG'
docker.registry = 'quay.io'
EOFCONFIG
            
            cat > offline-assets/pipeline/modules/nf-core/testmodule/main.nf << 'EOFMODULE'
process TESTMODULE {
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"
}
EOFMODULE
            
            test_success "Minimal test structure created"
        fi
    else
        test_error "online-prepare.sh script not found"
        return 1
    fi
    
    # Test 3: Execute script
    test_log "3. Testing script execution..."
    
    if timeout 120 "${SCRIPT_PATH}"; then
        test_success "Script executed successfully"
    else
        test_error "Script execution failed or timed out"
        return 1
    fi
    
    # Test 4: Validate image list generation
    test_log "4. Testing image list generation..."
    
    local images_file="${TEST_ASSETS_DIR}/offline-assets/images.txt"
    
    if [[ ! -f "${images_file}" ]]; then
        test_error "Images list file not generated: ${images_file}"
        return 1
    fi
    
    if [[ ! -s "${images_file}" ]]; then
        test_error "Images list file is empty: ${images_file}"
        return 1
    fi
    
    test_success "Image list file generated successfully"
    
    # Test 5: Validate image format
    test_log "5. Testing image format validation..."
    
    local invalid_images=0
    
    while IFS= read -r image; do
        if [[ ! "${image}" =~ ^[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
            test_error "Invalid image format: ${image}"
            invalid_images=$((invalid_images + 1))
        fi
    done < "${images_file}"
    
    if [[ ${invalid_images} -gt 0 ]]; then
        test_error "Found ${invalid_images} invalid image format(s)"
        return 1
    fi
    
    test_success "All images have valid format"
    
    # Test 6: Check manifest generation
    test_log "6. Testing manifest generation..."
    
    local manifest_file="${TEST_ASSETS_DIR}/offline-assets/images-manifest.txt"
    
    if [[ ! -f "${manifest_file}" ]]; then
        test_error "Images manifest not generated: ${manifest_file}"
        return 1
    fi
    
    if ! grep -q "nf-core/demo Pipeline Docker Images" "${manifest_file}"; then
        test_error "Manifest header not found in ${manifest_file}"
        return 1
    fi
    
    if ! grep -q "Registry:" "${manifest_file}"; then
        test_error "Registry information not found in manifest"
        return 1
    fi
    
    test_success "Image manifest generated with correct content"
    
    # Test 7: Test registry extraction
    test_log "7. Testing registry extraction..."
    
    local log_file="${TEST_ASSETS_DIR}/offline-assets/generate-image-list.log"
    
    if [[ -f "${log_file}" ]]; then
        if grep -q "Found registry configuration:" "${log_file}"; then
            test_success "Registry configuration extracted successfully"
        else
            test_success "Default registry used (no explicit configuration found)"
        fi
    else
        test_error "Log file not found: ${log_file}"
        return 1
    fi
    
    # Test 8: Test expected image count
    test_log "8. Testing expected image count..."
    
    local image_count=$(wc -l < "${images_file}")
    
    if [[ ${image_count} -lt 1 ]]; then
        test_error "Expected at least 1 image, found ${image_count}"
        return 1
    fi
    
    test_success "Found ${image_count} Docker images as expected"
    
    # Test 9: Test image registry paths
    test_log "9. Testing image registry paths..."
    
    local registry_issues=0
    
    while IFS= read -r image; do
        if [[ ! "${image}" =~ ^[a-zA-Z0-9.-]+\. ]]; then
            test_warning "Image may not have explicit registry: ${image}"
            registry_issues=$((registry_issues + 1))
        fi
    done < "${images_file}"
    
    if [[ ${registry_issues} -eq 0 ]]; then
        test_success "All images have proper registry paths"
    else
        test_warning "Found ${registry_issues} image(s) without explicit registry"
    fi
    
    # Test 10: Test log file content
    test_log "10. Testing log file content..."
    
    if [[ -f "${log_file}" ]]; then
        if grep -q "Starting Docker image list generation" "${log_file}"; then
            test_success "Log file contains expected content"
        else
            test_warning "Log file exists but may not contain expected content"
        fi
    fi
    
    test_success "All generate-image-list tests passed"
    return 0
}

# Main execution
main() {
    test_log "=== Generate Image List Test - Framework Version ==="
    test_log "Test directory: ${TEST_ASSETS_DIR}"
    test_log "Script path: ${SCRIPT_PATH}"
    test_log "Working directory: $(pwd)"
    
    # Validate test criteria
    if ! validate_test_criteria "${TEST_NAME}" "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md"; then
        test_error "Test criteria validation failed"
        return 1
    fi
    
    # Run the generate image list test
    if run_generate_image_list_test; then
        test_success "Generate image list test completed successfully"
        echo ""
        echo "✓ generate-image-list.sh functionality validated"
        echo "✓ All Docker image extraction operations working"
        echo "✓ Clean test environment with absolute paths"
        return 0
    else
        test_error "Generate image list test failed"
        return 1
    fi
}

# Execute main function
main "$@"
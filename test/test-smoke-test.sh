#!/bin/bash

# test-smoke-test.sh - Smoke test using /tmp directory framework
# Tests basic functionality and prerequisites with absolute paths

set -euo pipefail

# Load test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/framework.sh"

# Test configuration
TEST_NAME="smoke-test"
TEST_ASSETS_DIR="/tmp/${PROJECT_NAME}/test-assets"

# Test criteria documentation
cat > "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md" << 'EOF'
# Plan
Test basic environment functionality and prerequisites for Nextflow offline execution demo.

# Action
1. Check if required tools are available (nextflow, docker/podman)
2. Test nf-core/demo repository access
3. Verify Docker Hub connectivity
4. Test basic Nextflow functionality
5. Check file system permissions

# Testing
- Tool availability validation
- Network connectivity testing
- Nextflow execution testing
- File system permission testing

# Success Criteria
- All required tools detected and functional
- Internet connectivity confirmed for online components
- Nextflow can execute basic workflows
- File system permissions allow temporary directory creation
EOF

# Test implementation
run_smoke_test() {
    test_log "Starting smoke test with absolute paths..."
    
    # Create test assets directory
    mkdir -p "${TEST_ASSETS_DIR}"
    cd "${TEST_ASSETS_DIR}"
    
    # Test 1: Check required tools
    test_log "1. Checking required tools..."
    
    if ! command -v nextflow >/dev/null 2>&1; then
        test_error "nextflow not found"
        return 1
    fi
    
    if ! command -v docker >/dev/null 2>&1 && ! command -v podman >/dev/null 2>&1; then
        test_error "docker/podman not found"
        return 1
    fi
    
    test_success "Required tools available"
    
    # Test 2: Check nf-core/demo access
    test_log "2. Testing nf-core/demo access..."
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 10 https://api.github.com/repos/nf-core/demo > /dev/null 2>&1; then
            test_success "nf-core/demo repository accessible"
        else
            test_warning "Cannot access nf-core/demo repo (network issue)"
        fi
    else
        test_warning "curl not available, skipping nf-core/demo test"
    fi
    
    # Test 3: Check Docker Hub connectivity
    test_log "3. Testing Docker Hub connectivity..."
    
    if command -v docker >/dev/null 2>&1; then
        if timeout 30 docker pull hello-world:latest > /dev/null 2>&1; then
            test_success "Docker Hub connectivity verified"
        else
            test_warning "Cannot pull from Docker Hub (network/daemon issue)"
        fi
    elif command -v podman >/dev/null 2>&1; then
        if timeout 30 podman pull hello-world:latest > /dev/null 2>&1; then
            test_success "Docker Hub connectivity verified (podman)"
        else
            test_warning "Cannot pull from Docker Hub with podman"
        fi
    fi
    
    # Test 4: Check basic Nextflow functionality
    test_log "4. Testing basic Nextflow functionality..."
    
    local test_workflow="/tmp/${PROJECT_NAME}/test.nf"
    echo 'println "Hello from Nextflow!"' > "${test_workflow}"
    
    if timeout 60 nextflow run "${test_workflow}" > /dev/null 2>&1; then
        test_success "Nextflow basic functionality verified"
    else
        test_error "Nextflow basic test failed"
        return 1
    fi
    
    rm -f "${test_workflow}"
    
    # Test 5: Check file system permissions
    test_log "5. Testing file system permissions..."
    
    local test_dir="/tmp/${PROJECT_NAME}/permission-test"
    if mkdir -p "${test_dir}" && rmdir "${test_dir}"; then
        test_success "File system permissions verified"
    else
        test_error "Cannot create temporary directories"
        return 1
    fi
    
    # Test 6: Check /tmp directory usage
    test_log "6. Testing /tmp directory usage..."
    
    local tmp_test_file="/tmp/${PROJECT_NAME}/tmp-test.txt"
    if echo "test" > "${tmp_test_file}" && [[ -f "${tmp_test_file}" ]]; then
        test_success "/tmp directory access verified"
        rm -f "${tmp_test_file}"
    else
        test_error "Cannot write to /tmp directory"
        return 1
    fi
    
    test_success "All smoke tests passed"
    return 0
}

# Main execution
main() {
    test_log "=== Smoke Test - Framework Version ==="
    test_log "Test directory: ${TEST_ASSETS_DIR}"
    test_log "Working directory: $(pwd)"
    
    # Validate test criteria
    if ! validate_test_criteria "${TEST_NAME}" "/tmp/${PROJECT_NAME}/test-criteria-${TEST_NAME}.md"; then
        test_error "Test criteria validation failed"
        return 1
    fi
    
    # Run the smoke test
    if run_smoke_test; then
        test_success "Smoke test completed successfully"
        echo ""
        echo "✓ Environment is ready for MVP development"
        echo "✓ All required tools are available"
        echo "✓ Test framework is working correctly"
        return 0
    else
        test_error "Smoke test failed"
        return 1
    fi
}

# Execute main function
main "$@"
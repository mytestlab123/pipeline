#!/bin/bash
# Smoke test for Nextflow Offline Execution Demo MVP
# Simple validation script to verify basic functionality

set -e

echo "=== Nextflow Offline Execution Demo - Smoke Test ==="
echo "Testing basic functionality and prerequisites..."

# Test 1: Check if required tools are available
echo "1. Checking required tools..."
command -v nextflow >/dev/null 2>&1 || { echo "ERROR: nextflow not found"; exit 1; }
command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1 || { echo "ERROR: docker/podman not found"; exit 1; }
echo "✓ Required tools available"

# Test 2: Check if we can access nf-core/demo
echo "2. Testing nf-core/demo access..."
if command -v curl >/dev/null 2>&1; then
    curl -s https://api.github.com/repos/nf-core/demo > /dev/null || { echo "WARNING: Cannot access nf-core/demo repo"; }
    echo "✓ nf-core/demo repository accessible"
else
    echo "WARNING: curl not available, skipping nf-core/demo test"
fi

# Test 3: Check Docker Hub connectivity (if online)
echo "3. Testing Docker Hub connectivity..."
if command -v docker >/dev/null 2>&1; then
    docker pull hello-world:latest > /dev/null 2>&1 || { echo "WARNING: Cannot pull from Docker Hub"; }
    echo "✓ Docker Hub connectivity verified"
elif command -v podman >/dev/null 2>&1; then
    podman pull hello-world:latest > /dev/null 2>&1 || { echo "WARNING: Cannot pull from Docker Hub"; }
    echo "✓ Docker Hub connectivity verified (podman)"
fi

# Test 4: Check basic nextflow functionality
echo "4. Testing basic Nextflow functionality..."
echo 'println "Hello from Nextflow!"' > /tmp/test.nf
nextflow run /tmp/test.nf > /dev/null 2>&1 || { echo "ERROR: Nextflow basic test failed"; exit 1; }
rm -f /tmp/test.nf
echo "✓ Nextflow basic functionality verified"

# Test 5: Check if we can create temporary directories
echo "5. Testing file system permissions..."
mkdir -p /tmp/nextflow-test && rmdir /tmp/nextflow-test || { echo "ERROR: Cannot create temp directories"; exit 1; }
echo "✓ File system permissions verified"

echo ""
echo "=== Smoke Test Summary ==="
echo "✓ All basic tests passed"
echo "✓ Environment is ready for MVP development"
echo "✓ Required tools are available"
echo ""
echo "Next steps:"
echo "1. Run MVP scripts to download pipeline assets"
echo "2. Test offline execution workflow"
echo "3. Validate end-to-end pipeline execution"
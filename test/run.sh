#!/bin/bash

# run.sh - Updated test runner using /tmp directory framework
# Maintains backward compatibility while using new framework

set -euo pipefail

echo "========================================"
echo "Nextflow Offline Execution Demo - Test Suite"
echo "Updated to use /tmp directory framework"
echo "========================================"
echo

# Check if new framework test runner exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_RUNNER="${SCRIPT_DIR}/run-all-tests.sh"

if [[ -f "${NEW_RUNNER}" ]] && [[ -x "${NEW_RUNNER}" ]]; then
    echo "Using new framework test runner..."
    exec "${NEW_RUNNER}" "$@"
else
    echo "New framework not available, running legacy tests..."
    echo "WARNING: Legacy test mode - tests run in current directory"
    echo
    
    # Legacy test execution
    echo "Running all tests..."
    ./test/smoke-test.sh
    ./test/test-online-prepare.sh
    ./test/test-generate-image-list.sh
    ./test/test-pull-images.sh
    ./test/test-offline-setup.sh
    echo "All tests completed successfully!"
fi
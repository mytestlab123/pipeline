#!/bin/bash
set -euo pipefail

echo "Running all tests..."
./test/smoke-test.sh
./test/test-online-prepare.sh
echo "All tests completed successfully!"
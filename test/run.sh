#!/bin/bash
set -euo pipefail

echo "Running all tests..."
./test/smoke-test.sh
./test/test-online-prepare.sh
./test/test-generate-image-list.sh
./test/test-pull-images.sh
echo "All tests completed successfully!"
# Testing - Nextflow Offline Execution Demo

## Smoke Tests

### Basic Smoke Test
Run the basic smoke test to verify your environment is ready:

```bash
chmod +x test/smoke-test.sh
./test/smoke-test.sh
```

This test checks:
- ✓ Required tools (nextflow, docker/podman)
- ✓ nf-core/demo repository access
- ✓ Docker Hub connectivity
- ✓ Basic Nextflow functionality
- ✓ File system permissions

### Expected Output
```
=== Nextflow Offline Execution Demo - Smoke Test ===
Testing basic functionality and prerequisites...
1. Checking required tools...
✓ Required tools available
2. Testing nf-core/demo access...
✓ nf-core/demo repository accessible
3. Testing Docker Hub connectivity...
✓ Docker Hub connectivity verified
4. Testing basic Nextflow functionality...
✓ Nextflow basic functionality verified
5. Testing file system permissions...
✓ File system permissions verified

=== Smoke Test Summary ===
✓ All basic tests passed
✓ Environment is ready for MVP development
✓ Required tools are available
```

## Component Tests

### Online Prepare Script Test
Test the online-prepare.sh script functionality:

```bash
chmod +x test/test-online-prepare.sh
./test/test-online-prepare.sh
```

This test validates:
- ✓ Script execution and permissions
- ✓ Asset directory creation
- ✓ nf-core/demo pipeline download
- ✓ Essential file validation
- ✓ Manifest generation

### Run All Tests
Execute all available tests:

```bash
# Create test runner script
cat > test/run.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "Running all tests..."
./test/smoke-test.sh
./test/test-online-prepare.sh
echo "All tests completed successfully!"
EOF

chmod +x test/run.sh
./test/run.sh
```

## Integration Tests (Future)

### End-to-End Workflow Test
After MVP implementation, run the full workflow test:

```bash
# Online phase
./online-prepare.sh
./generate-image-list.sh
./pull-images.sh

# Offline phase
./offline-setup.sh
./run-offline-pipeline.sh
```

### Test Environment Requirements

#### Online Machine
- Internet connectivity
- Docker or Podman
- Nextflow installed
- AWS CLI configured (for S3 access)

#### Offline Machine
- No internet connectivity
- Docker or Podman
- Nextflow installed
- Access to shared storage (S3 or mounted volume)

## Troubleshooting

### Common Issues
1. **Nextflow not found**: Install Nextflow following official documentation
2. **Docker connectivity issues**: Check Docker daemon status
3. **Permission errors**: Ensure proper file permissions on scripts
4. **Network issues**: Verify internet connectivity for online phase

### Debug Mode
Run tests with debug output:
```bash
bash -x test/smoke-test.sh
```
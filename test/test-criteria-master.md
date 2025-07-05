# Test Criteria Master Document

## Overview

This document defines the comprehensive test criteria for the Nextflow Offline Execution Demo MVP test suite. All tests use the `/tmp/${PROJECT}` directory framework with absolute paths for clean isolation.

## Framework Requirements

### Plan
- Define clear test objectives and scope
- Identify specific functionality to be tested
- Establish test boundaries and limitations

### Action
- List specific steps to be executed
- Define test data setup requirements
- Specify validation points throughout execution

### Testing
- Describe test methodology and approach
- Define success/failure detection mechanisms
- Specify cleanup requirements

### Success Criteria
- Define measurable success conditions
- Establish clear pass/fail criteria
- Specify acceptable performance thresholds

## Test Suite Overview

### 1. Smoke Test (`test-smoke-test.sh`)

**Objective**: Validate basic environment functionality and prerequisites

**Plan**: Test basic environment functionality and prerequisites for Nextflow offline execution demo.

**Action**:
1. Check if required tools are available (nextflow, docker/podman)
2. Test nf-core/demo repository access
3. Verify Docker Hub connectivity
4. Test basic Nextflow functionality
5. Check file system permissions

**Testing**:
- Tool availability validation
- Network connectivity testing
- Nextflow execution testing
- File system permission testing

**Success Criteria**:
- All required tools detected and functional
- Internet connectivity confirmed for online components
- Nextflow can execute basic workflows
- File system permissions allow temporary directory creation

### 2. Online Prepare Test (`test-online-prepare.sh`)

**Objective**: Validate online preparation script functionality

**Plan**: Test the online-prepare.sh script functionality for downloading nf-core/demo pipeline assets.

**Action**:
1. Verify script existence and permissions
2. Execute script to download nf-core/demo pipeline
3. Validate downloaded assets structure
4. Check essential files presence
5. Verify manifest generation
6. Test logging functionality

**Testing**:
- Script execution validation
- Asset directory structure verification
- Essential file presence checking
- Manifest content validation
- Log file creation testing

**Success Criteria**:
- Script executes without errors
- offline-assets directory created with correct structure
- Essential pipeline files downloaded (main.nf, nextflow.config, etc.)
- Manifest file generated with correct content
- Log file created with execution details

### 3. Generate Image List Test (`test-generate-image-list.sh`)

**Objective**: Validate Docker image extraction functionality

**Plan**: Test the generate-image-list.sh script functionality for extracting Docker images from nf-core/demo pipeline.

**Action**:
1. Verify script existence and permissions
2. Setup test environment with pipeline assets
3. Execute script to generate Docker image list
4. Validate generated image list format
5. Check manifest generation
6. Verify registry extraction
7. Test expected image count

**Testing**:
- Script execution validation
- Image list generation testing
- Image format validation
- Registry configuration extraction
- Manifest content verification
- Expected image count validation

**Success Criteria**:
- Script executes without errors
- images.txt file generated with valid Docker image format
- images-manifest.txt created with correct content
- Registry configuration extracted correctly
- Expected number of images found (at least 1)
- All images have proper registry paths and tags

### 4. Pull Images Test (`test-pull-images.sh`)

**Objective**: Validate Docker image copying functionality

**Plan**: Test the pull-images.sh script functionality for copying Docker images using Skopeo.

**Action**:
1. Verify script existence and permissions
2. Test .env file loading and validation
3. Test image name transformation logic
4. Test input file validation
5. Test Docker daemon availability check
6. Test image existence check functionality
7. Test skip logic and counters
8. Test log file creation in /tmp
9. Test manifest generation structure

**Testing**:
- Script execution validation
- Environment file validation
- Image transformation testing
- Input validation testing
- Docker daemon checking
- Image existence checking
- Skip logic validation
- Log file creation testing
- Manifest generation testing

**Success Criteria**:
- Script executes without errors (up to actual copying)
- .env file properly loaded and validated
- Image names correctly transformed
- Input files validated correctly
- Docker daemon availability checked
- Image existence check logic works
- Skip logic and counters function properly
- Log file created in /tmp directory
- Manifest structure generated correctly

### 5. Offline Setup Test (`test-offline-setup.sh`)

**Objective**: Validate offline machine preparation functionality

**Plan**: Test the offline-setup.sh script functionality for loading pipeline assets and Docker images on offline machine.

**Action**:
1. Verify script existence and permissions
2. Test .env file loading and validation
3. Test asset validation functionality
4. Test image name transformation logic
5. Test offline configuration generation
6. Test log file creation in /tmp
7. Test mock Docker operations

**Testing**:
- Script execution validation
- Environment file validation
- Asset validation testing
- Image transformation testing
- Configuration generation testing
- Log file creation testing
- Mock Docker operation testing

**Success Criteria**:
- Script executes without errors (up to actual Docker operations)
- .env file properly loaded and validated
- Asset validation works correctly
- Image names correctly transformed
- Offline configuration generated successfully
- Log file created in /tmp directory
- Mock Docker operations handled properly

## Framework Validation Requirements

### Directory Structure
```
/tmp/${PROJECT_NAME}/
├── test-assets/                 # Test working directory
├── test-criteria-*.md          # Test criteria documentation
├── test-reports/               # Test execution reports
├── online-prepare.sh           # Copied project scripts
├── generate-image-list.sh
├── pull-images.sh
├── offline-setup.sh
└── run-offline-pipeline.sh
```

### Common Validation Points

1. **Script Existence**: All scripts must exist and be executable
2. **Error Handling**: All scripts must handle errors gracefully
3. **Logging**: All scripts must create appropriate log files in /tmp
4. **Cleanup**: All tests must clean up temporary files
5. **Isolation**: Tests must not interfere with each other
6. **Absolute Paths**: All file operations must use absolute paths

### Performance Requirements

- Test execution timeout: 300 seconds per test
- Memory usage: < 1GB during test execution
- Disk usage: < 5GB in /tmp directory
- Network timeout: 30 seconds for external requests

### Error Handling Requirements

- All scripts must validate inputs before execution
- Missing dependencies must be clearly reported
- Network failures must be handled gracefully
- Insufficient permissions must be detected
- Disk space issues must be reported

### Cleanup Requirements

- All temporary files must be removed after test completion
- /tmp log files may persist for debugging
- Test directories must be fully removed
- No test artifacts should remain in original project directory

## Quality Assurance

### Code Quality
- All scripts must use `set -euo pipefail`
- Error messages must be clear and actionable
- Success messages must be informative
- All functions must be properly documented

### Test Quality
- Each test must be independent and repeatable
- Test data must be predictable and controlled
- Mock data must be realistic and comprehensive
- Edge cases must be covered where applicable

### Documentation Quality
- All test criteria must be complete and measurable
- Test procedures must be clear and unambiguous
- Expected outcomes must be precisely defined
- Troubleshooting guidance must be provided

## Maintenance

### Regular Updates
- Test criteria should be reviewed with each script change
- Performance benchmarks should be updated quarterly
- Mock data should be refreshed with real pipeline updates
- Documentation should be kept current with implementation

### Version Control
- All test changes must be tracked in git
- Test criteria changes must be documented
- Backward compatibility must be maintained where possible
- Breaking changes must be clearly communicated

### 6. Demo Integration Test (`test-demo.sh`)

**Objective**: Validate end-to-end demo.sh script functionality and integration

**Plan**: Test demo.sh script orchestration of complete online → offline workflow with performance benchmarking and error handling.

**Action**:
1. Test script existence and permissions
2. Validate help mode functionality
3. Test environment validation mode
4. Check configuration file handling (.env)
5. Validate log file creation in /tmp
6. Test performance tracking functionality
7. Validate error handling for invalid inputs
8. Test cleanup functionality
9. Check integration with all 5 core scripts
10. Validate demo mode recognition and execution

**Testing**:
- Script execution and permissions validation
- Help and validate mode functionality testing
- Configuration and logging system testing
- Performance tracking and cleanup validation
- Integration testing with core MVP scripts
- Error handling and mode validation testing

**Success Criteria**:
- Demo script exists and is executable
- Help mode displays usage information correctly
- Validate mode checks environment prerequisites
- Configuration file handling works with .env files
- Log files are created in /tmp directory
- Performance tracking measures phase durations
- Error handling gracefully manages invalid inputs
- Cleanup functionality removes temporary files
- Integration with all 5 core scripts validated
- All demo modes (full, online-only, offline-only, validate, help) recognized
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nextflow Offline Execution Demo - MVP that enables running nf-core pipelines on AWS EC2 instances without internet access. The project implements a two-phase workflow: online preparation and offline execution.

## Core Architecture

### Two-Phase Workflow System
The project follows a strict separation between online and offline phases:

**Online Phase (Internet-connected machine):**
- Downloads nf-core/demo pipeline assets from GitLab
- Scans pipeline configuration to generate required Docker image lists
- Pulls Docker images and saves to shared storage (S3 or Docker Hub)

**Offline Phase (Private subnet, no internet):**
- Loads pre-downloaded assets from shared storage
- Loads Docker images from shared location
- Executes pipeline with `-offline` flag

### Key Components
- **Shell Scripts**: Primary automation layer (5 core scripts)
- **Docker/Podman**: Container runtime (constraint: prefer podman)
- **Nextflow**: Workflow management system
- **nf-core**: Pipeline framework targeting nf-core/demo initially

## Development Commands

### Testing
```bash
# Run environment smoke test
./test/smoke-test.sh

# Test with debug output
bash -x test/smoke-test.sh
```

### MVP Development Workflow
The project follows a structured MVP approach with 5 core deliverables:

1. **online-prepare.sh** - Downloads pipeline assets on online machine
2. **generate-image-list.sh** - Generates list of required Docker images
3. **pull-images.sh** - Pulls Docker images and saves to shared location
4. **offline-setup.sh** - Loads assets on offline machine
5. **run-offline-pipeline.sh** - Runs pipeline with offline flag

### Project Structure
```
├── plan.md              # Original project requirements
├── issues.md            # Issue tracking (updated as development progresses)
├── TODO.md              # Comprehensive task list and future enhancements
├── docs/README.md       # Architecture documentation with ASCII diagrams
└── test/
    ├── smoke-test.sh    # Environment validation (executable)
    └── README.md        # Testing instructions
```

## Technology Constraints

### Required Tools
- Linux/Shell Script environment
- podman (preferred over docker)
- Nextflow installation
- AWS CLI (for S3 access)

### Target Environment
- AWS Cloud9 (Amazon Linux 2) for development
- EC2 instances for online/offline phases
- S3 buckets for asset storage
- Docker Hub (mytestlab123 organization) for image hosting

## Key Implementation Details

### Target Pipeline
Initially focused on nf-core/demo (version 1.0.2) as the reference implementation:
- Repository: https://github.com/nf-core/demo/tree/1.0.2
- Documentation: https://nf-co.re/demo/1.0.2/
- Offline docs: https://nf-co.re/docs/usage/getting_started/offline

### Asset Storage Strategy
Two approaches supported:
1. **S3 Bucket**: Shared storage for both pipeline assets and Docker images
2. **Docker Hub**: Push/pull model using mytestlab123 organization account

### Known Limitations
- Internet dependency for initial online phase
- Large storage requirements for Docker images (multi-GB)
- Currently pipeline-specific (nf-core/demo focus)
- Manual process with no automated end-to-end pipeline

## Development Timeline
- **MVP Target**: 2 hours for demo
- **Developer Estimate**: 30 minutes using shell scripts and nf-core/demo
- **Current Status**: MVP scaffolding complete, ready for script implementation

## Issue Tracking
All issues tracked in `issues.md` file (not GitHub issues). MVP scope defined in GitHub issue #1 and draft PR #2.

## Future Enhancements
Post-MVP considerations include multiple pipeline support, AWS Systems Manager integration, automated image optimization, and AWS Batch integration. See TODO.md for comprehensive future work list.

### Next Step – July 4, 2025

**Goal**: Implement the first core MVP script (online-prepare.sh) to download nf-core/demo pipeline assets and validate online phase functionality.

**Deliverables**:
- Create executable `online-prepare.sh` script that downloads nf-core/demo pipeline from GitHub
- Implement asset validation and verification checks
- Add logging and error handling for download failures
- Create shared asset directory structure for S3/local storage
- Test script functionality with nf-core/demo v1.0.2

**Acceptance Criteria**:
- Script successfully downloads nf-core/demo pipeline assets
- Downloaded assets are organized in expected directory structure
- Script provides clear success/failure feedback with logging
- Script handles network connectivity issues gracefully
- Documentation updated with script usage instructions

**Risks / Assumptions**:
- Assumes stable internet connectivity for nf-core/demo repository access
- Assumes sufficient disk space for pipeline assets (typically <100MB)
- Risk of GitHub rate limiting during development/testing
- Assumes current nf-core/demo repository structure remains stable

### Done – July 4, 2025

**Completed**: Implemented online-prepare.sh script with full functionality and testing.

**Deliverables Completed**:
- ✓ Created executable `online-prepare.sh` script that downloads nf-core/demo pipeline v1.0.2
- ✓ Implemented comprehensive asset validation and verification checks
- ✓ Added robust logging and error handling for download failures
- ✓ Created organized asset directory structure (offline-assets/)
- ✓ Tested script functionality with full test suite validation
- ✓ Added test-online-prepare.sh component test
- ✓ Updated test/run.sh for comprehensive testing
- ✓ Enhanced test documentation in test/README.md

**Technical Details**:
- Script handles internet connectivity validation and graceful error handling
- Assets stored in `./offline-assets/` with organized subdirectories
- Manifest generation provides complete asset inventory
- Comprehensive logging to `offline-assets/online-prepare.log`
- Full test coverage validates all functionality end-to-end

### Next Step – July 4, 2025

**Goal**: Implement the second core MVP script (generate-image-list.sh) to analyze the downloaded nf-core/demo pipeline and extract required Docker container images.

**Deliverables**:
- Create executable `generate-image-list.sh` script that parses nf-core/demo pipeline configuration
- Implement Docker image extraction from nextflow.config, modules, and workflow files
- Generate comprehensive image list with tags and registry information
- Add validation to ensure all required images are identified
- Create component test to validate image list generation functionality
- Update test suite to include new script validation

**Acceptance Criteria**:
- Script successfully parses pipeline configuration files (nextflow.config, modules.json, workflow files)
- Extracts all Docker images referenced in the pipeline with full registry paths and tags
- Generates organized image list file (images.txt) with one image per line
- Handles different image reference formats (docker://, quay.io/, etc.)
- Provides clear logging and error handling for parsing failures
- Test suite validates image extraction accuracy and completeness

**Risks / Assumptions**:
- Assumes nf-core/demo pipeline follows standard image reference patterns
- Risk of missing images if referenced through complex variable substitution
- Assumes pipeline configuration structure remains consistent
- May need to handle different registry formats and authentication requirements

### Done – July 4, 2025

**Completed**: Implemented generate-image-list.sh script with full Docker image extraction functionality and testing.

**Deliverables Completed**:
- ✓ Created executable `generate-image-list.sh` script that parses nf-core/demo pipeline configuration
- ✓ Implemented Docker image extraction from nextflow.config, modules, and workflow files
- ✓ Generated comprehensive image list with tags and registry information (3 images identified)
- ✓ Added validation to ensure all required images are identified with proper format checking
- ✓ Created component test (`test-generate-image-list.sh`) to validate image list generation functionality
- ✓ Updated test suite to include new script validation in `test/run.sh`
- ✓ Enhanced test documentation in `test/README.md`

**Technical Details**:
- Script successfully extracts Docker images using `nextflow inspect -concretize` (with manual parsing fallback)
- Identifies registry configuration from `nextflow.config` (quay.io for nf-core/demo)
- Generates `images.txt` with full registry paths: `quay.io/biocontainers/[tool]:[version]`
- Creates comprehensive manifest (`images-manifest.txt`) with metadata and download commands
- Extracted 3 Docker images: fastqc, multiqc, and seqtk tools
- Full test coverage validates all extraction functionality end-to-end

### Next Step – July 4, 2025

**Goal**: Implement the third core MVP script (pull-images.sh) to copy the identified Docker container images to Docker Hub repository using Skopeo for offline access.

**Deliverables**:
- Create executable `pull-images.sh` script that reads from generated `images.txt` file
- Implement Skopeo-based image copying using Docker container for portability
- Add authentication handling using `.env` file with `$DOCKER_USER` and `$DOCKER_PAT`
- Copy all images from source registries (quay.io) to destination `docker.io/mytestlab123/`
- Create validation to ensure all images are successfully copied to Docker Hub
- Add component test to validate image copying functionality with mock credentials
- Update test suite and documentation for new script

**Acceptance Criteria**:
- Script successfully reads image list from `images.txt` and copies all 3 Docker images
- Uses Skopeo via Docker container: `docker run --rm quay.io/skopeo/stable copy`
- Implements robust error handling for network failures, authentication issues, and registry errors
- Transforms image names from `quay.io/biocontainers/[tool]:[tag]` to `docker.io/mytestlab123/[tool]:[tag]`
- Loads authentication credentials securely from `.env` file
- Provides clear progress indicators and comprehensive logging throughout the process
- Validates copied images are accessible in Docker Hub repository
- Test suite validates complete copy functionality with appropriate mocking

**Risks / Assumptions**:
- Assumes stable internet connectivity for copying multi-GB container images between registries
- Risk of Docker Hub rate limiting during bulk image operations
- Assumes `.env` file contains valid `DOCKER_USER` and `DOCKER_PAT` credentials
- May encounter source registry authentication requirements (currently public quay.io images)
- Assumes Docker daemon is running and accessible for Skopeo container execution

### Done – July 4, 2025

**Completed**: Implemented pull-images.sh script with full Skopeo-based Docker image copying functionality and testing.

**Deliverables Completed**:
- ✓ Created executable `pull-images.sh` script that reads from generated `images.txt` file
- ✓ Implemented Skopeo-based image copying using Docker container for portability
- ✓ Added authentication handling using `.env` file with `$DOCKER_USER` and `$DOCKER_PAT`
- ✓ Implemented image copying from source registries (quay.io) to destination `docker.io/mytestlab123/`
- ✓ Created validation to ensure all images are successfully copied to Docker Hub
- ✓ Added component test (`test-pull-images.sh`) to validate image copying functionality
- ✓ Updated test suite to include new script validation in `test/run.sh`
- ✓ Enhanced test documentation in `test/README.md`

**Technical Details**:
- Script uses Skopeo via Docker container: `docker run --rm quay.io/skopeo/stable copy`
- Implements robust error handling for network failures, authentication issues, and registry errors
- Transforms image names from `quay.io/biocontainers/[tool]:[tag]` to `docker.io/mytestlab123/[tool]:[tag]`
- Loads authentication credentials securely from `.env` file (excluded from git)
- Provides clear progress indicators and comprehensive logging to `/tmp/pull-images.log`
- Generates comprehensive manifest with offline usage instructions
- Full test coverage validates all functionality except actual Skopeo execution (requires credentials)

### Next Step – July 4, 2025

**Goal**: Implement the fourth core MVP script (offline-setup.sh) to load pre-downloaded pipeline assets and Docker images on an offline machine for pipeline execution.

**Deliverables**:
- Create executable `offline-setup.sh` script that loads pipeline assets from shared storage
- Implement Docker image loading from Docker Hub repository or local storage 
- Add validation to ensure all required assets and images are available offline
- Create offline environment preparation with proper directory structure
- Add component test to validate offline setup functionality
- Update test suite and documentation for new script

**Acceptance Criteria**:
- Script successfully loads pipeline assets from `./offline-assets/` directory structure
- Pulls required Docker images from `docker.io/mytestlab123/` repository using cached credentials
- Validates all 3 required images (fastqc, multiqc, seqtk) are available locally
- Creates appropriate Nextflow configuration for offline execution mode
- Provides clear logging and error handling for missing assets or connectivity issues
- Generates offline-ready environment status report with asset inventory
- Test suite validates complete offline setup functionality with mock assets

**Risks / Assumptions**:
- Assumes offline machine has Docker/Podman runtime available for image pulling
- Risk of incomplete asset transfer if shared storage is unavailable or corrupted
- Assumes offline machine can authenticate to Docker Hub for initial image pulls
- May need to handle different offline scenarios (air-gapped vs limited connectivity)
- Assumes sufficient local storage for pipeline assets and Docker images (multi-GB)
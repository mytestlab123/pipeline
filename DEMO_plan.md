# Nextflow Offline Demo Plan

**Date**: July 7, 2025 11:30 AM SGT  
**Status**: Implementation phase - demo.sh redesign based on working S3 + Docker Hub architecture  
**Solution**: Integrate proven online.sh and offline.sh approach into demo.sh

## Working Architecture Analysis

The **proven working approach** uses:
1. **S3 Integration**: `s3://lifebit-user-data-nextflow/pipe/` for asset storage
2. **Docker Hub Registry**: `docker.io/mytestlab123/` namespace for container mirroring
3. **True Offline Mode**: `NXF_OFFLINE=true` with container retagging
4. **Two-Machine Workflow**: Online EC2 → S3 → Offline EC2

## Recent Progress

### Working Scripts Status
- ✅ **online-prepare.sh** - Downloads nf-core/demo v1.0.2 (75 lines)
- ✅ **generate-image-list.sh** - Extracts 3 Docker images (94 lines)  
- ✅ **pull-images.sh** - FIXED - Now works correctly using copy.sh approach (223 lines)
- ✅ **offline-setup.sh** - Loads assets for offline execution (167 lines)
- ✅ **run-offline-pipeline.sh** - Executes pipeline with offline flag (67 lines)

### New Repository Setup Scripts (July 8, 2025)
- ✅ **setup_repository_online.sh** - Automated image copying with configurable registry/namespace
- ✅ **setup_repository_offline.sh** - Automated retagging and pulling for offline environment

### Key Improvements Applied Today
**Repository Setup Automation**:
- Created `setup_repository_online.sh` for automated skopeo-based image copying
- Created `setup_repository_offline.sh` for automated retagging and pulling
- Configurable destination registry via `DEST_REGISTRY` and `DEST_NAMESPACE` variables
- Simplified workflow: source file → copy images → destination file → retag/pull
- Maintains compatibility with existing pipeline references

## Working Demo Architecture: Two-Machine S3 + Docker Hub Workflow

**Core Concept**: Use proven S3 + Docker Hub approach with real two-machine workflow for true offline capability.

### Environment Setup
- **Online EC2**: `ip-10-0-17-169` (Amazon Linux 3, with internet)
- **Offline EC2**: `ip-10-0-97-230` (Ubuntu 22.04, no internet, docker.io via Nexus)
- **S3 Bucket**: `s3://lifebit-user-data-nextflow/pipe/`
- **Docker Registry**: `docker.io/mytestlab123/`

### Phase 1: Online Preparation (Internet Enabled)
```bash
# 1. Build Offline Dataset
./build_offline_dataset.sh data.csv /tmp/offline-fastq data_offline.csv

# 2. Download Pipeline (no containers)
nf-core pipelines download "$PIPE" --revision "$VER" --compress none --container-system none

# 3. Generate Container Manifest
nextflow inspect "$PIPE" -r "$VER" -profile test,docker -concretize true -format json | jq -r '.processes[].container' > images.txt

# 4. Mirror Containers to Docker Hub
./copy.sh images.txt --dest-registry docker.io --dest-namespace mytestlab123

# 5. Sync to S3
aws s3 sync "$ROOT" "s3://lifebit-user-data-nextflow/pipe/" --delete
```

### Phase 2: Offline Execution (NXF_OFFLINE=true)
```bash
# 1. Download from S3
aws s3 sync "s3://lifebit-user-data-nextflow/pipe/" "$ROOT" --delete

# 2. Set Offline Environment
export NXF_OFFLINE=true
export NXF_DEBUG=2

# 3. Retag Containers
bash ./retag_biocontainers.sh

# 4. Execute Pipeline
nextflow run offline/1_0_2/ -profile test,docker --input ./data_offline.csv --outdir /tmp/out-demo -w /tmp/work-demo
```

## Key Technical Requirements

### Environment Variables (Nextflow)
- `NXF_OFFLINE=true` - Prevents automatic downloading/updating remote repositories
- Must use local pipeline directory, not remote repository

### Docker Strategy
- **Current Issue**: pull-images.sh pushes to Docker Hub registry
- **Required**: Pull images to local Docker daemon for offline use
- **Verification**: `docker images` should show all required images locally

### Reference Documentation
- https://nf-co.re/docs/usage/getting_started/offline
- https://www.nextflow.io/docs/latest/install.html
- https://www.nextflow.io/docs/latest/config.html  
- https://www.nextflow.io/docs/latest/reference/env-vars.html

## Implementation Steps

### 1. Update demo.sh Architecture
**Current**: Uses local-only approach with individual scripts  
**Required**: Integrate proven S3 + Docker Hub workflow from working scripts

### 2. Add Pipeline Configurability
**Current**: Hard-coded nf-core/demo  
**Required**: Support PIPE, VER, PROJECT_NAME variables for extensibility

### 3. Helper Scripts Integration
**Current**: Separate script calls  
**Required**: Integrate build_offline_dataset.sh, copy.sh, retag_biocontainers.sh

### 4. Add S3 Sync Functionality
**Current**: Local directory operations  
**Required**: S3 sync for real two-machine workflow

## Success Criteria

The demo must prove: **"This pipeline can run completely offline using pre-downloaded assets"**

- ✅ Phase 1: All assets uploaded to S3 and containers mirrored to Docker Hub
- ✅ Phase 2: Pipeline runs with `NXF_OFFLINE=true` using only S3 + Docker Hub assets  
- ✅ No network calls during offline execution (except S3 download and Docker Hub pulls)
- ✅ All containers sourced from mytestlab123 namespace with proper retagging
- ✅ Complete pipeline execution without internet access on offline EC2

## Manual Test Commands

### Repository Setup Scripts (New)
```bash
# Online environment - copy images to Docker Hub
./setup_repository_online.sh images.txt destination.txt

# Offline environment - retag and pull images
./setup_repository_offline.sh images.txt destination.txt

# Custom registry/namespace
DEST_REGISTRY=docker.io DEST_NAMESPACE=myorg ./setup_repository_online.sh
```

### On Online EC2 (ip-10-0-17-169)
```bash
cd /home/ec2-user/git/mytestlab/pipeline
./demo.sh online-only
aws s3 ls s3://lifebit-user-data-nextflow/pipe/ --recursive
```

### On Offline EC2 (ip-10-0-97-230)
```bash
cd /home/ssm-user/pipe
./demo.sh offline-only
```

## Current Test Environment
- Working directory: `/home/ec2-user/git/mytestlab/pipeline`
- `.env` file configured with Docker Hub credentials
- Helper scripts: build_offline_dataset.sh, copy.sh, retag_biocontainers.sh
- S3 bucket: `s3://lifebit-user-data-nextflow/pipe/`
- Docker Hub namespace: `docker.io/mytestlab123/`
# Nextflow Offline Demo Plan

**Date**: July 5, 2025 11:47 PM SGT  
**Status**: Planning phase - demo.sh needs complete redesign  
**Issue**: Current demo.sh attempts network operations during "offline" phase

## Current Problem Analysis

The current `demo.sh` is **fundamentally flawed** because:
1. It's trying to pull Docker images during the "offline" phase 
2. It's not properly simulating offline mode with `NXF_OFFLINE=true`
3. It's not demonstrating that the pipeline can run without internet access
4. The "offline" phase is still attempting network operations

## Recent Progress

### Working Scripts Status
- ✅ **online-prepare.sh** - Downloads nf-core/demo v1.0.2 (75 lines)
- ✅ **generate-image-list.sh** - Extracts 3 Docker images (94 lines)  
- ✅ **pull-images.sh** - FIXED - Now works correctly using copy.sh approach (223 lines)
- ✅ **offline-setup.sh** - Loads assets for offline execution (167 lines)
- ✅ **run-offline-pipeline.sh** - Executes pipeline with offline flag (67 lines)

### Key Fix Applied Today
**pull-images.sh** was completely rewritten using the proven approach from user's working `copy.sh`:
- Fixed file reading loop (was hanging)
- Fixed tag parsing logic for images with/without tags
- Added proper error handling and colored output
- Now successfully processes images and handles skipping/copying

## Required Demo Architecture: Single Machine Offline Simulation

**Core Concept**: Simulate online→offline workflow on one EC2 instance using `NXF_OFFLINE=true` to demonstrate true offline capability.

### Phase 1: Online Preparation (Internet Enabled)
```bash
# 1. Download Pipeline Assets
./online-prepare.sh
# → downloads nf-core/demo to ./offline-assets/pipeline/

# 2. Extract Image Requirements  
./generate-image-list.sh
# → creates ./offline-assets/images.txt (3 images)

# 3. Cache Docker Images Locally
./pull-images.sh
# → pulls ALL images to local Docker daemon
# → Verify: docker images shows all required images cached locally

# 4. Validation
# → Verify pipeline directory exists locally
# → Verify all Docker images are in local Docker cache
# → No more network dependencies needed
```

### Phase 2: Offline Simulation (NXF_OFFLINE=true)
```bash
# 1. Environment Setup
export NXF_OFFLINE=true 
# → Use local pipeline directory: ./offline-assets/pipeline/
# → Use local Docker images (already cached)

# 2. Offline Pipeline Execution
nextflow run ./offline-assets/pipeline/ -profile docker --offline
# → Should complete successfully using only local assets
# → No network calls should be made

# 3. Demonstration Success
# → Pipeline completes without internet access
# → All containers pulled from local Docker cache
# → Proves offline execution capability
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

## Immediate Action Items for Tomorrow

### 1. Fix pull-images.sh Strategy
**Current**: Pushes images to Docker Hub registry  
**Required**: Pull images to local Docker daemon for offline use

### 2. Fix offline-setup.sh  
**Current**: Tries to pull from Docker Hub during offline phase  
**Required**: Should verify local assets only, no network operations

### 3. Create Proper run-offline-pipeline.sh
**Current**: Basic script  
**Required**: 
- Set `NXF_OFFLINE=true`
- Use local pipeline directory `./offline-assets/pipeline/`
- Use local Docker images only
- Demonstrate no network calls

### 4. Redesign demo.sh
**Current**: Attempts network operations during offline phase  
**Required**: True online→offline simulation that proves offline capability

## Success Criteria

The demo must prove: **"This pipeline can run completely offline using pre-downloaded assets"**

- ✅ Phase 1: All assets downloaded and cached locally
- ✅ Phase 2: Pipeline runs with `NXF_OFFLINE=true` using only local assets  
- ✅ No network calls during offline execution
- ✅ All containers sourced from local Docker cache
- ✅ Complete pipeline execution without internet access

## Files to Review Tomorrow

1. `/home/ec2-user/git/mytestlab/pipeline/demo.sh` - Needs complete redesign
2. `/home/ec2-user/git/mytestlab/pipeline/pull-images.sh` - Strategy change needed
3. `/home/ec2-user/git/mytestlab/pipeline/offline-setup.sh` - Remove network operations
4. `/home/ec2-user/git/mytestlab/pipeline/run-offline-pipeline.sh` - Add NXF_OFFLINE support

## Current Test Environment
- Working directory: `/home/ec2-user/git/mytestlab/pipeline`
- `.env` file configured with Docker Hub credentials
- All 5 core MVP scripts implemented and tested
- Ready for offline demo implementation
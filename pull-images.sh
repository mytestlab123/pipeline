#!/bin/bash
# pull-images.sh - Copy Docker images to Docker Hub using Skopeo (MVP demo)
set -euo pipefail

# Simple config
IMAGES_FILE="./offline-assets/images.txt"
LOG_FILE="/tmp/pull-images.log"
ENV_FILE=".env"
DEST_REGISTRY="docker.io/mytestlab123"

# Simple logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

# Simple error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Transform image name (quay.io/biocontainers/fastqc:tag -> docker.io/mytestlab123/fastqc:tag)
transform_image_name() {
    local source_image="$1"
    local name_tag=$(echo "${source_image}" | sed 's|.*/||')
    echo "${DEST_REGISTRY}/${name_tag}"
}

# Check if image exists
check_image_exists() {
    local dest_image="$1"
    log "Checking if image already exists: ${dest_image}"
    
    if docker run --rm quay.io/skopeo/stable inspect "docker://${dest_image}" &>/dev/null; then
        log "✓ Image already exists: ${dest_image}"
        return 0
    else
        log "○ Image not found, copy needed: ${dest_image}"
        return 1
    fi
}

# Copy single image using Skopeo
copy_image_with_skopeo() {
    local source_image="$1"
    local dest_image="$2"
    
    log "Copying: ${source_image} -> ${dest_image}"
    
    if docker run --rm quay.io/skopeo/stable copy \
        --dest-creds "${DOCKER_USER}:${DOCKER_PAT}" \
        "docker://${source_image}" \
        "docker://${dest_image}" 2>>"${LOG_FILE}"; then
        log "✓ Successfully copied: ${dest_image}"
        return 0
    else
        log "✗ Failed to copy: ${source_image}"
        return 1
    fi
}

# Main function
main() {
    log "Starting Docker image copy process using Skopeo"
    
    # Check requirements
    log "Checking required tools..."
    command -v docker &>/dev/null || error_exit "docker not found"
    docker info &>/dev/null || error_exit "Docker daemon not running"
    log "Required tools available"
    
    # Load credentials
    log "Loading authentication credentials from .env file..."
    [[ ! -f "${ENV_FILE}" ]] && error_exit ".env file not found. Create with DOCKER_USER and DOCKER_PAT"
    
    set -a
    source "${ENV_FILE}"
    set +a
    
    [[ -z "${DOCKER_USER:-}" ]] && error_exit "DOCKER_USER not set in .env"
    [[ -z "${DOCKER_PAT:-}" ]] && error_exit "DOCKER_PAT not set in .env"
    log "Credentials loaded successfully for user: ${DOCKER_USER}"
    
    # Validate input
    log "Validating input files..."
    [[ ! -f "${IMAGES_FILE}" ]] && error_exit "Images file not found: ${IMAGES_FILE}. Run generate-image-list.sh first."
    local image_count=$(wc -l < "${IMAGES_FILE}")
    [[ "${image_count}" -eq 0 ]] && error_exit "Images file is empty: ${IMAGES_FILE}"
    log "Found ${image_count} images to copy"
    
    # Copy all images
    log "Starting image copying process..."
    local success_count=0 skipped_count=0 failure_count=0
    
    while IFS= read -r source_image || [[ -n "$source_image" ]]; do
        [[ -z "${source_image}" ]] && continue
        
        local dest_image=$(transform_image_name "${source_image}")
        echo $source_image
        
        # Check if exists, skip if so
        if check_image_exists "${dest_image}"; then
            log "⏩ Skipping copy - image already exists: ${dest_image}"
            ((success_count++))
            ((skipped_count++))
        else
            # Copy image
            if copy_image_with_skopeo "${source_image}" "${dest_image}"; then
                ((success_count++))
                ((copied_count++))
            else
                ((failure_count++))
            fi
        fi
    done < "${IMAGES_FILE}"
    
    # Summary
    log "Image copying completed!"
    log "Total processed: ${image_count}"
    log "Successful: ${success_count} (${copied_count:-0} copied + ${skipped_count} skipped)"
    log "Failed: ${failure_count}"
    
    [[ "${failure_count}" -gt 0 ]] && error_exit "Some images failed to copy"
    
    # Simple manifest
    log "Generating copy manifest..."
    cat > "./offline-assets/pull-images-manifest.txt" << EOF
# Docker Image Copy Manifest
# Generated on: $(date)
# Destination: ${DEST_REGISTRY}
# Total images copied: ${image_count}

## Copied Images
$(while IFS= read -r img; do [[ -n "$img" ]] && echo "$(transform_image_name "$img")"; done < "${IMAGES_FILE}")

## Offline Usage Instructions
1. On offline machine, pull images:
$(while IFS= read -r img; do [[ -n "$img" ]] && echo "   docker pull $(transform_image_name "$img")"; done < "${IMAGES_FILE}")
EOF
    log "Copy manifest generated: ./offline-assets/pull-images-manifest.txt"
    
    log "Docker image copy process completed successfully!"
    log "All images copied to: ${DEST_REGISTRY}"
    log "Log file: ${LOG_FILE}"
    
    echo ""
    echo "✓ Docker image copy completed successfully!"
    echo "✓ Images copied to: ${DEST_REGISTRY}"
    echo "✓ Total images: ${image_count}"
    echo "✓ Log file: ${LOG_FILE}"
}

main "$@"
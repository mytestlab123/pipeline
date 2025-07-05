#!/bin/bash
# generate-image-list.sh - Extract Docker images from nf-core/demo (MVP demo)
set -euo pipefail

# Simple config
PIPELINE_DIR="./offline-assets/pipeline"
IMAGES_FILE="./offline-assets/images.txt"
DEFAULT_REGISTRY="quay.io"

# Simple logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "./offline-assets/generate-image-list.log"
}

# Simple error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Main function
main() {
    log "Starting Docker image extraction for nf-core/demo pipeline"
    
    # Quick validation
    log "Validating pipeline assets..."
    [[ ! -d "${PIPELINE_DIR}" ]] && error_exit "Pipeline directory not found. Run online-prepare.sh first."
    [[ ! -f "${PIPELINE_DIR}/nextflow.config" ]] && error_exit "Pipeline config not found"
    log "Pipeline assets validated successfully"
    
    # Extract registry from config
    log "Extracting default registry from pipeline configuration..."
    if grep -q "docker.registry" "${PIPELINE_DIR}/nextflow.config"; then
        DEFAULT_REGISTRY=$(grep "docker.registry" "${PIPELINE_DIR}/nextflow.config" | sed "s/.*=\s*['\"]//;s/['\"].*//")
        log "Found registry configuration: ${DEFAULT_REGISTRY}"
    else
        log "No registry configuration found, using default: ${DEFAULT_REGISTRY}"
    fi
    
    # Extract Docker images from modules
    log "Extracting Docker images from module files..."
    > "${IMAGES_FILE}"  # Clear file
    
    for module_file in $(find "${PIPELINE_DIR}/modules" -name "*.nf" 2>/dev/null); do
        log "Processing module: ${module_file}"
        
        # Simple extraction of biocontainer images
        if grep -q "biocontainers" "${module_file}"; then
            docker_image=$(grep -oE "biocontainers/[^'\"]*" "${module_file}" | head -1)
            if [[ -n "${docker_image}" ]]; then
                full_image="${DEFAULT_REGISTRY}/${docker_image}"
                echo "${full_image}" >> "${IMAGES_FILE}"
                log "Found Docker image: ${full_image}"
            fi
        fi
    done
    
    # Sort and deduplicate
    sort -u "${IMAGES_FILE}" -o "${IMAGES_FILE}"
    local image_count=$(wc -l < "${IMAGES_FILE}")
    log "Extracted Docker images (${image_count} unique)"
    
    [[ "${image_count}" -eq 0 ]] && error_exit "No Docker images found"
    
    # Simple manifest
    log "Generating image manifest..."
    cat > "./offline-assets/images-manifest.txt" << EOF
# nf-core/demo Pipeline Docker Images
# Generated on: $(date)
# Registry: ${DEFAULT_REGISTRY}
# Total images: ${image_count}

## Docker Images Required for Offline Execution
$(cat "${IMAGES_FILE}")
EOF
    log "Image manifest generated: ./offline-assets/images-manifest.txt"
    
    log "Docker image extraction completed successfully!"
    log "Images list: ${IMAGES_FILE}"
    log "Total images: ${image_count}"
    log "Next steps:"
    log "  1. Run pull-images.sh to download container images"
    log "  2. Transfer images to offline environment"
    log "  3. Run offline-setup.sh to prepare offline execution"
    
    echo ""
    echo "✓ Docker image extraction completed successfully!"
    echo "✓ Images list generated: ${IMAGES_FILE}"
    echo "✓ Total images: ${image_count}"
    echo "✓ Log file: ./offline-assets/generate-image-list.log"
}

main "$@"
#!/bin/bash

# generate-image-list.sh - Extract Docker images from nf-core/demo pipeline assets
# Part of the Nextflow Offline Execution Demo MVP

set -euo pipefail

# Configuration
PIPELINE_DIR="./offline-assets/pipeline"
IMAGES_FILE="./offline-assets/images.txt"
LOG_FILE="./offline-assets/generate-image-list.log"
DEFAULT_REGISTRY="quay.io"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    # Only write to log file if directory exists
    if [[ -d "$(dirname "${LOG_FILE}")" ]]; then
        echo "$message" >> "${LOG_FILE}"
    fi
}

# Error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Validate pipeline assets exist
validate_pipeline_assets() {
    log "Validating pipeline assets..."
    
    if [[ ! -d "${PIPELINE_DIR}" ]]; then
        error_exit "Pipeline directory not found: ${PIPELINE_DIR}. Run online-prepare.sh first."
    fi
    
    if [[ ! -f "${PIPELINE_DIR}/nextflow.config" ]]; then
        error_exit "Pipeline configuration not found: ${PIPELINE_DIR}/nextflow.config"
    fi
    
    if [[ ! -d "${PIPELINE_DIR}/modules" ]]; then
        error_exit "Pipeline modules directory not found: ${PIPELINE_DIR}/modules"
    fi
    
    log "Pipeline assets validated successfully"
}

# Extract default registry from nextflow.config
extract_default_registry() {
    log "Extracting default registry from pipeline configuration..."
    
    local config_file="${PIPELINE_DIR}/nextflow.config"
    local registry=""
    
    # Look for docker.registry, podman.registry, or apptainer.registry
    if grep -q "docker.registry" "${config_file}"; then
        registry=$(grep "docker.registry" "${config_file}" | sed "s/.*=\s*['\"]//;s/['\"].*//")
    elif grep -q "podman.registry" "${config_file}"; then
        registry=$(grep "podman.registry" "${config_file}" | sed "s/.*=\s*['\"]//;s/['\"].*//")
    elif grep -q "apptainer.registry" "${config_file}"; then
        registry=$(grep "apptainer.registry" "${config_file}" | sed "s/.*=\s*['\"]//;s/['\"].*//")
    fi
    
    if [[ -n "${registry}" ]]; then
        DEFAULT_REGISTRY="${registry}"
        log "Found registry configuration: ${DEFAULT_REGISTRY}"
    else
        log "No registry configuration found, using default: ${DEFAULT_REGISTRY}"
    fi
}

# Extract Docker images from module files
extract_docker_images() {
    log "Extracting Docker images from module files..."
    
    local temp_images_file=$(mktemp)
    
    # Find all .nf files in modules directory and process them
    for module_file in $(find "${PIPELINE_DIR}/modules" -name "*.nf" -type f); do
        log "Processing module: ${module_file}"
        
        # Extract container lines with Docker image references
        if grep -q "container.*biocontainers\|'biocontainers" "${module_file}"; then
            # Extract the Docker image name from the conditional statement
            local docker_image=$(grep -oE "biocontainers/[^'\"]*" "${module_file}" | head -1)
            
            if [[ -n "${docker_image}" ]]; then
                # Add registry prefix if not already present
                if [[ "${docker_image}" != *"/"*"/"* ]]; then
                    docker_image="${DEFAULT_REGISTRY}/${docker_image}"
                fi
                
                echo "${docker_image}" >> "${temp_images_file}"
                log "Found Docker image: ${docker_image}"
            fi
        fi
    done
    
    # Sort and deduplicate images
    if [[ -s "${temp_images_file}" ]]; then
        sort -u "${temp_images_file}" > "${IMAGES_FILE}"
        local image_count=$(wc -l < "${IMAGES_FILE}")
        log "Extracted Docker images (${image_count} unique)"
    else
        error_exit "No Docker images found in pipeline modules"
    fi
    
    rm -f "${temp_images_file}"
}

# Validate extracted images
validate_extracted_images() {
    log "Validating extracted images..."
    
    if [[ ! -f "${IMAGES_FILE}" ]]; then
        error_exit "Images file not generated: ${IMAGES_FILE}"
    fi
    
    local image_count=$(wc -l < "${IMAGES_FILE}")
    
    if [[ "${image_count}" -eq 0 ]]; then
        error_exit "No images found in generated images file"
    fi
    
    # Validate image format
    while IFS= read -r image; do
        if [[ ! "${image}" =~ ^[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
            error_exit "Invalid image format: ${image}"
        fi
    done < "${IMAGES_FILE}"
    
    log "Validated ${image_count} Docker images"
}

# Generate image manifest
generate_image_manifest() {
    log "Generating image manifest..."
    
    local manifest_file="${PIPELINE_DIR}/../images-manifest.txt"
    
    {
        echo "# nf-core/demo Pipeline Docker Images"
        echo "# Generated on: $(date)"
        echo "# Registry: ${DEFAULT_REGISTRY}"
        echo "# Total images: $(wc -l < "${IMAGES_FILE}")"
        echo ""
        echo "## Docker Images Required for Offline Execution"
        cat "${IMAGES_FILE}"
    } > "${manifest_file}"
    
    log "Image manifest generated: ${manifest_file}"
}

# Main execution
main() {
    log "Starting Docker image extraction for nf-core/demo pipeline"
    
    validate_pipeline_assets
    extract_default_registry
    extract_docker_images
    validate_extracted_images
    generate_image_manifest
    
    log "Docker image extraction completed successfully!"
    log "Images list: ${IMAGES_FILE}"
    log "Total images: $(wc -l < "${IMAGES_FILE}")"
    log "Next steps:"
    log "  1. Run pull-images.sh to download container images"
    log "  2. Transfer images to offline environment"
    log "  3. Run offline-setup.sh to prepare offline execution"
    
    echo ""
    echo "✓ Docker image extraction completed successfully!"
    echo "✓ Images list generated: ${IMAGES_FILE}"
    echo "✓ Total images: $(wc -l < "${IMAGES_FILE}")"
    echo "✓ Log file: ${LOG_FILE}"
}

# Execute main function
main "$@"
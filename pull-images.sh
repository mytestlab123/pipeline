#!/bin/bash

# pull-images.sh - Copy Docker images to Docker Hub using Skopeo
# Part of the Nextflow Offline Execution Demo MVP

set -euo pipefail
#set -x

# Configuration
IMAGES_FILE="./offline-assets/images.txt"
LOG_FILE="/tmp/pull-images.log"
ENV_FILE="${HOME}/.env"
DEST_REGISTRY="docker.io/mytestlab123"
SKOPEO_IMAGE="quay.io/skopeo/stable"

# Logging function
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    # Always write to log file in /tmp
    echo "$message" >> "${LOG_FILE}"
}

# Error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Load environment variables from .env file
load_env_credentials() {
    log "Loading authentication credentials from .env file..."
    
    if [[ ! -f "${ENV_FILE}" ]]; then
        error_exit ".env file not found. Please create ${ENV_FILE} with DOCKER_USER and DOCKER_PAT"
    fi
    
    # Source .env file
    set -a  # automatically export all variables
    source "${ENV_FILE}"
    set +a  # disable automatic export
    
    if [[ -z "${DOCKER_USER:-}" ]]; then
        error_exit "DOCKER_USER not set in .env file"
    fi
    
    if [[ -z "${DOCKER_PAT:-}" ]]; then
        error_exit "DOCKER_PAT not set in .env file"
    fi
    
    log "Credentials loaded successfully for user: ${DOCKER_USER}"
}

# Check required tools
check_requirements() {
    log "Checking required tools..."
    
    if ! command -v docker &> /dev/null; then
        error_exit "docker is not installed or not in PATH"
    fi
    
    # Test docker daemon access
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running or not accessible"
    fi
    
    log "Required tools available"
}

# Validate input files
validate_input_files() {
    log "Validating input files..."
    
    if [[ ! -f "${IMAGES_FILE}" ]]; then
        error_exit "Images file not found: ${IMAGES_FILE}. Run generate-image-list.sh first."
    fi
    
    local image_count=$(wc -l < "${IMAGES_FILE}" 2>/dev/null || echo "0")
    
    if [[ "${image_count}" -eq 0 ]]; then
        error_exit "Images file is empty: ${IMAGES_FILE}"
    fi
    
    log "Found ${image_count} images to copy"
}

# Transform image name from source to destination format
transform_image_name() {
    local source_image="$1"
    
    # Extract image name and tag from source
    # Example: quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0 -> fastqc:0.12.1--hdfd78af_0
    local image_name_tag=$(echo "${source_image}" | sed 's|.*/||')
    
    # Create destination image name
    local dest_image="${DEST_REGISTRY}/${image_name_tag}"
    
    echo "${dest_image}"
}

# Copy single image using Skopeo
copy_image_with_skopeo() {
    local source_image="$1"
    local dest_image="$2"
    echo "copy_image_with_skopeo: started"
    
    log "Copying: ${source_image} -> ${dest_image}"
    
    # Use Skopeo via Docker container for portability
    local skopeo_cmd=(
        docker run --rm
        -v "${HOME}/.docker:/root/.docker:ro"
        "${SKOPEO_IMAGE}"
        copy
        --dest-creds "${DOCKER_USER}:${DOCKER_PAT}"
        "docker://${source_image}"
        "docker://${dest_image}"
    )
    
    # Execute Skopeo copy command
    if "${skopeo_cmd[@]}" 2>> "${LOG_FILE}"; then
        log "✓ Successfully copied: ${dest_image}"
        return 0
    else
        log "✗ Failed to copy: ${source_image}"
        return 1
    fi
}

# Validate copied image exists in destination registry
validate_copied_image() {
    local dest_image="$1"
    echo "validate_copied_image: started"
    
    log "Validating copied image: ${dest_image}"
    
    # Use Skopeo to inspect the copied image
    local inspect_cmd=(
        docker run --rm
        "${SKOPEO_IMAGE}"
        inspect
        "docker://${dest_image}"
    )
    
    if "${inspect_cmd[@]}" &> /dev/null; then
        log "✓ Validation successful: ${dest_image}"
        return 0
    else
        log "✗ Validation failed: ${dest_image}"
        return 1
    fi
}

# Copy all images from the images file
copy_all_images() {
    log "Starting image copying process..."
    
    local total_images=$(wc -l < "${IMAGES_FILE}")
    local current=0
    local success_count=0
    local failure_count=0
    local failed_images=()
    echo "copy_all: started"
    
    while IFS= read -r source_image; do
    echo $source_image
        # Skip empty lines
        [[ -z "${source_image}" ]] && continue
        
        #((current++))
        log "Processing image ${current}/${total_images}: ${source_image}"
        
        # Transform image name for destination
        local dest_image=$(transform_image_name "${source_image}")
        
        # Copy image using Skopeo
        if copy_image_with_skopeo "${source_image}" "${dest_image}"; then
            # Validate the copied image
            if validate_copied_image "${dest_image}"; then
                ((success_count++))
            else
                ((failure_count++))
                failed_images+=("${source_image} (validation failed)")
            fi
        else
            ((failure_count++))
            failed_images+=("${source_image} (copy failed)")
        fi
        
        # Progress indicator
        log "Progress: ${current}/${total_images} processed (${success_count} success, ${failure_count} failed)"
        
    done < "${IMAGES_FILE}"
    
    # Summary
    log "Image copying completed!"
    log "Total processed: ${total_images}"
    log "Successful: ${success_count}"
    log "Failed: ${failure_count}"
    
    if [[ "${failure_count}" -gt 0 ]]; then
        log "Failed images:"
        for failed_image in "${failed_images[@]}"; do
            log "  - ${failed_image}"
        done
        error_exit "Some images failed to copy. Check logs for details."
    fi
}

# Generate copy manifest with results
generate_copy_manifest() {
    log "Generating copy manifest..."
    
    local manifest_file="./offline-assets/pull-images-manifest.txt"
    local total_images=$(wc -l < "${IMAGES_FILE}")
    
    {
        echo "# Docker Image Copy Manifest"
        echo "# Generated on: $(date)"
        echo "# Source: Various registries (mainly quay.io)"
        echo "# Destination: ${DEST_REGISTRY}"
        echo "# Total images copied: ${total_images}"
        echo ""
        echo "## Copied Images"
        while IFS= read -r source_image; do
            [[ -z "${source_image}" ]] && continue
            local dest_image=$(transform_image_name "${source_image}")
            echo "Source: ${source_image}"
            echo "Destination: ${dest_image}"
            echo "Pull command: docker pull ${dest_image}"
            echo ""
        done < "${IMAGES_FILE}"
        echo ""
        echo "## Offline Usage Instructions"
        echo "1. On offline machine, pull images from Docker Hub:"
        while IFS= read -r source_image; do
            [[ -z "${source_image}" ]] && continue
            local dest_image=$(transform_image_name "${source_image}")
            echo "   docker pull ${dest_image}"
        done < "${IMAGES_FILE}"
        echo ""
        echo "2. Tag images for local use (if needed):"
        while IFS= read -r source_image; do
            [[ -z "${source_image}" ]] && continue
            local dest_image=$(transform_image_name "${source_image}")
            echo "   docker tag ${dest_image} ${source_image}"
        done < "${IMAGES_FILE}"
    } > "${manifest_file}"
    
    log "Copy manifest generated: ${manifest_file}"
}

# Main execution
main() {
    log "Starting Docker image copy process using Skopeo"
    
    check_requirements
    load_env_credentials
    validate_input_files
    copy_all_images
    generate_copy_manifest
    
    log "Docker image copy process completed successfully!"
    log "All images copied to: ${DEST_REGISTRY}"
    log "Log file: ${LOG_FILE}"
    log "Next steps:"
    log "  1. Run offline-setup.sh on offline machine"
    log "  2. Pull images from Docker Hub on offline machine"
    log "  3. Run offline pipeline execution"
    
    echo ""
    echo "✓ Docker image copy completed successfully!"
    echo "✓ Images copied to: ${DEST_REGISTRY}"
    echo "✓ Total images: $(wc -l < "${IMAGES_FILE}")"
    echo "✓ Log file: ${LOG_FILE}"
}

# Execute main function
main "$@"

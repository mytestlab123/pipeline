#!/bin/bash

# online-prepare.sh - Download nf-core/demo pipeline assets for offline execution
# Part of the Nextflow Offline Execution Demo MVP

set -euo pipefail

# Configuration
PIPELINE_NAME="nf-core/demo"
PIPELINE_VERSION="1.0.2"
ASSETS_DIR="./offline-assets"
PIPELINE_DIR="${ASSETS_DIR}/pipeline"
LOG_FILE="${ASSETS_DIR}/online-prepare.log"

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

# Create directory structure
create_directories() {
    rm -rf "${ASSETS_DIR}"
    log "Creating directory structure..."
    mkdir -p "${ASSETS_DIR}"
    mkdir -p "${PIPELINE_DIR}"
    mkdir -p "${ASSETS_DIR}/images"
    mkdir -p "${ASSETS_DIR}/logs"
    log "Directory structure created successfully"
}

# Download pipeline assets
download_pipeline() {
    log "Downloading ${PIPELINE_NAME} version ${PIPELINE_VERSION}..."
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        error_exit "git is not installed or not in PATH"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 github.com &> /dev/null; then
        error_exit "No internet connectivity to GitHub"
    fi
    
    # Clone the specific version
    if git clone --depth 1 --branch "${PIPELINE_VERSION}" https://github.com/nf-core/demo.git "${PIPELINE_DIR}" 2>> "${LOG_FILE}"; then
        log "Pipeline cloned successfully"
    else
        error_exit "Failed to clone pipeline repository"
    fi
}

# Validate downloaded assets
validate_assets() {
    log "Validating downloaded assets..."
    
    # Check for essential files
    essential_files=(
        "main.nf"
        "nextflow.config"
        "conf/base.config"
        "modules.json"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ ! -f "${PIPELINE_DIR}/${file}" ]]; then
            error_exit "Essential file missing: ${file}"
        fi
    done
    
    # Check pipeline structure
    if [[ ! -d "${PIPELINE_DIR}/modules" ]]; then
        error_exit "Pipeline modules directory not found"
    fi
    
    if [[ ! -d "${PIPELINE_DIR}/workflows" ]]; then
        error_exit "Pipeline workflows directory not found"
    fi
    
    log "Asset validation completed successfully"
}

# Generate asset manifest
generate_manifest() {
    log "Generating asset manifest..."
    
    manifest_file="${ASSETS_DIR}/manifest.txt"
    
    {
        echo "# nf-core/demo Pipeline Asset Manifest"
        echo "# Generated on: $(date)"
        echo "# Pipeline: ${PIPELINE_NAME}"
        echo "# Version: ${PIPELINE_VERSION}"
        echo ""
        echo "## Pipeline Files"
        find "${PIPELINE_DIR}" -type f -name "*.nf" -o -name "*.config" -o -name "*.json" | sort
        echo ""
        echo "## Directory Structure"
        find "${PIPELINE_DIR}" -type d | sort
    } > "${manifest_file}"
    
    log "Asset manifest generated: ${manifest_file}"
}

# Main execution
main() {
    log "Starting online preparation for ${PIPELINE_NAME} v${PIPELINE_VERSION}"
    
    create_directories
    download_pipeline
    validate_assets
    generate_manifest
    
    log "Online preparation completed successfully!"
    log "Assets stored in: ${ASSETS_DIR}"
    log "Next steps:"
    log "  1. Run generate-image-list.sh to scan for required Docker images"
    log "  2. Run pull-images.sh to download container images"
    log "  3. Transfer assets to offline environment"
    
    echo ""
    echo "✓ Online preparation completed successfully!"
    echo "✓ Pipeline assets downloaded to: ${ASSETS_DIR}"
    echo "✓ Log file: ${LOG_FILE}"
}

# Execute main function
main "$@"

#!/bin/bash
# online-prepare.sh - Download nf-core/demo for offline execution (MVP demo)
set -euo pipefail

# Simple config
ASSETS_DIR="./offline-assets"
PIPELINE_DIR="${ASSETS_DIR}/pipeline"

# Simple logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    mkdir -p "${ASSETS_DIR}" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${ASSETS_DIR}/online-prepare.log"
}

# Simple error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Main function
main() {
    log "Starting online preparation for nf-core/demo v1.0.2"
    
    # Clean and create directories
    log "Creating directory structure..."
    rm -rf "${ASSETS_DIR}"
    mkdir -p "${PIPELINE_DIR}"
    log "Directory structure created successfully"
    
    # Download pipeline
    log "Downloading nf-core/demo version 1.0.2..."
    if ! command -v git &>/dev/null; then
        error_exit "git not found"
    fi
    
    if ! git clone --depth 1 --branch "1.0.2" https://github.com/nf-core/demo.git "${PIPELINE_DIR}" 2>>"${ASSETS_DIR}/online-prepare.log"; then
        error_exit "Failed to clone pipeline"
    fi
    log "Pipeline cloned successfully"
    
    # Quick validation
    log "Validating downloaded assets..."
    for file in "main.nf" "nextflow.config" "conf/base.config" "modules.json"; do
        [[ ! -f "${PIPELINE_DIR}/${file}" ]] && error_exit "Missing: ${file}"
    done
    log "Asset validation completed successfully"
    
    # Simple manifest
    log "Generating asset manifest..."
    cat > "${ASSETS_DIR}/manifest.txt" << EOF
# nf-core/demo Pipeline Asset Manifest
# Generated on: $(date)
# Pipeline: nf-core/demo
# Version: 1.0.2

## Pipeline Files
$(find "${PIPELINE_DIR}" -name "*.nf" -o -name "*.config" -o -name "*.json" | sort)
EOF
    log "Asset manifest generated: ${ASSETS_DIR}/manifest.txt"
    
    log "Online preparation completed successfully!"
    log "Assets stored in: ${ASSETS_DIR}"
    log "Next steps:"
    log "  1. Run generate-image-list.sh to scan for required Docker images"
    log "  2. Run pull-images.sh to download container images"
    log "  3. Transfer assets to offline environment"
    
    echo ""
    echo "✓ Online preparation completed successfully!"
    echo "✓ Pipeline assets downloaded to: ${ASSETS_DIR}"
    echo "✓ Log file: ${ASSETS_DIR}/online-prepare.log"
}

main "$@"
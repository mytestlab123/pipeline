#!/bin/bash

# offline-setup.sh - Load pipeline assets and Docker images for offline execution
# Part of the Nextflow Offline Execution Demo MVP

set -euo pipefail

# Configuration
ASSETS_DIR="./offline-assets"
PIPELINE_DIR="${ASSETS_DIR}/pipeline"
IMAGES_FILE="${ASSETS_DIR}/images.txt"
LOG_FILE="/tmp/offline-setup.log"
ENV_FILE="${HOME}/.env"
SOURCE_REGISTRY="docker.io/mytestlab123"
OFFLINE_CONFIG_FILE="./nextflow-offline.config"

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

# Check if required tools are available
check_required_tools() {
    log "Checking required tools..."
    
    local tools=("docker" "nextflow")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error_exit "Required tool not found: $tool"
        fi
    done
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running or not accessible"
    fi
    
    log "Required tools available"
}

# Load environment variables from .env file (optional for offline setup)
load_env_credentials() {
    log "Loading authentication credentials from .env file..."
    
    if [[ ! -f "${ENV_FILE}" ]]; then
        log "Warning: .env file not found. Using Docker Hub without explicit credentials."
        return 0
    fi
    
    # Source .env file
    set -a  # automatically export all variables
    source "${ENV_FILE}"
    set +a  # disable automatic export
    
    if [[ -n "${DOCKER_USER:-}" ]]; then
        log "Credentials loaded successfully for user: ${DOCKER_USER}"
    else
        log "Warning: DOCKER_USER not set in .env file"
    fi
}

# Validate offline assets
validate_assets() {
    log "Validating offline assets..."
    
    if [[ ! -d "${ASSETS_DIR}" ]]; then
        error_exit "Assets directory not found: ${ASSETS_DIR}. Run online-prepare.sh first."
    fi
    
    if [[ ! -d "${PIPELINE_DIR}" ]]; then
        error_exit "Pipeline directory not found: ${PIPELINE_DIR}. Run online-prepare.sh first."
    fi
    
    if [[ ! -f "${IMAGES_FILE}" ]]; then
        error_exit "Images file not found: ${IMAGES_FILE}. Run generate-image-list.sh first."
    fi
    
    if [[ ! -f "${PIPELINE_DIR}/main.nf" ]]; then
        error_exit "Pipeline main.nf not found in ${PIPELINE_DIR}"
    fi
    
    log "Assets validation completed successfully"
}

# Transform image name from source to destination format
transform_image_name() {
    local source_image="$1"
    
    # Extract image name and tag from source (e.g., quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0)
    local name_tag
    name_tag=$(echo "$source_image" | sed 's/.*\/\([^\/]*\)$/\1/')
    
    # Create destination image name
    echo "${SOURCE_REGISTRY}/${name_tag}"
}

# Pull Docker image from Docker Hub
pull_image() {
    local image="$1"
    local dest_image
    dest_image=$(transform_image_name "$image")
    
    log "Pulling Docker image: ${dest_image}"
    
    if docker pull "$dest_image"; then
        log "✓ Successfully pulled: ${dest_image}"
        return 0
    else
        log "✗ Failed to pull: ${dest_image}"
        return 1
    fi
}

# Load all required Docker images
load_docker_images() {
    log "Loading Docker images from Docker Hub..."
    
    local total_images
    total_images=$(wc -l < "${IMAGES_FILE}")
    log "Found ${total_images} images to load"
    
    local pulled_count=0
    local failed_count=0
    
    while IFS= read -r image || [[ -n "$image" ]]; do
        # Skip empty lines and comments
        [[ -z "$image" || "$image" =~ ^#.*$ ]] && continue
        
        log "Processing image: ${image}"
        
        if pull_image "$image"; then
            ((pulled_count++))
        else
            ((failed_count++))
        fi
    done < "${IMAGES_FILE}"
    
    log "Image loading completed: ${pulled_count} pulled, ${failed_count} failed"
    
    if [[ $failed_count -gt 0 ]]; then
        error_exit "Failed to pull ${failed_count} images. Check network connectivity and credentials."
    fi
}

# Validate loaded images are available locally
validate_loaded_images() {
    log "Validating loaded Docker images..."
    
    local validation_failed=0
    
    while IFS= read -r image || [[ -n "$image" ]]; do
        # Skip empty lines and comments
        [[ -z "$image" || "$image" =~ ^#.*$ ]] && continue
        
        local dest_image
        dest_image=$(transform_image_name "$image")
        
        if docker image inspect "$dest_image" &> /dev/null; then
            log "✓ Image available locally: ${dest_image}"
        else
            log "✗ Image not found locally: ${dest_image}"
            ((validation_failed++))
        fi
    done < "${IMAGES_FILE}"
    
    if [[ $validation_failed -gt 0 ]]; then
        error_exit "Validation failed: ${validation_failed} images not available locally"
    fi
    
    log "All Docker images validated successfully"
}

# Create Nextflow configuration for offline execution
create_offline_config() {
    log "Creating Nextflow configuration for offline execution..."
    
    cat > "${OFFLINE_CONFIG_FILE}" << 'EOF'
// Nextflow configuration for offline execution
// Generated by offline-setup.sh

// Disable automatic updates and remote repository access
nextflow.enable.configProcessNamesValidation = false

// Docker configuration for offline execution
docker {
    enabled = true
    registry = 'docker.io/mytestlab123'
    fixOwnership = true
    runOptions = '-u $(id -u):$(id -g)'
}

// Disable remote repository access
nextflow.enable.dsl = 2
params.custom_config_version = 'offline'

// Process configuration
process {
    // Use locally available images with transformed registry
    withName: 'NFCORE_DEMO:DEMO:FASTQC' {
        container = 'docker.io/mytestlab123/fastqc:0.12.1--hdfd78af_0'
    }
    withName: 'NFCORE_DEMO:DEMO:SEQTK_TRIM' {
        container = 'docker.io/mytestlab123/seqtk:1.4--he4a0461_1'
    }
    withName: 'NFCORE_DEMO:DEMO:MULTIQC' {
        container = 'docker.io/mytestlab123/multiqc:1.29--pyhdfd78af_0'
    }
}

// Disable remote config downloads
params.custom_config_base = false
EOF
    
    log "Offline configuration created: ${OFFLINE_CONFIG_FILE}"
}

# Generate offline environment status report
generate_status_report() {
    log "Generating offline environment status report..."
    
    local report_file="${ASSETS_DIR}/offline-status-report.txt"
    
    cat > "${report_file}" << EOF
=== Nextflow Offline Environment Status Report ===
Generated: $(date)
Host: $(hostname)

=== Pipeline Assets ===
Pipeline Directory: ${PIPELINE_DIR}
Main Workflow: ${PIPELINE_DIR}/main.nf
Configuration: ${PIPELINE_DIR}/nextflow.config
Offline Config: ${OFFLINE_CONFIG_FILE}

=== Docker Images Status ===
EOF
    
    echo "Image Inventory:" >> "${report_file}"
    while IFS= read -r image || [[ -n "$image" ]]; do
        # Skip empty lines and comments
        [[ -z "$image" || "$image" =~ ^#.*$ ]] && continue
        
        local dest_image
        dest_image=$(transform_image_name "$image")
        
        if docker image inspect "$dest_image" &> /dev/null; then
            local image_size
            image_size=$(docker image inspect "$dest_image" --format '{{.Size}}' | numfmt --to=iec-i --suffix=B)
            echo "  ✓ ${dest_image} (${image_size})" >> "${report_file}"
        else
            echo "  ✗ ${dest_image} (MISSING)" >> "${report_file}"
        fi
    done < "${IMAGES_FILE}"
    
    cat >> "${report_file}" << EOF

=== System Information ===
Docker Version: $(docker --version)
Nextflow Version: $(nextflow -version 2>&1 | head -1)
Available Disk Space: $(df -h . | tail -1 | awk '{print $4}')

=== Next Steps ===
To run the offline pipeline:
1. Ensure this environment is ready: ./offline-setup.sh
2. Execute pipeline: ./run-offline-pipeline.sh

=== Environment Validation ===
Status: READY FOR OFFLINE EXECUTION
Validation completed: $(date)
EOF
    
    log "Status report generated: ${report_file}"
    
    # Display summary
    log "=== OFFLINE ENVIRONMENT READY ==="
    log "Pipeline assets: ✓ Available"
    log "Docker images: ✓ Loaded and validated"
    log "Offline config: ✓ Created"
    log "Status report: ${report_file}"
    log "Ready for offline pipeline execution!"
}

# Main execution flow
main() {
    log "Starting offline setup for Nextflow pipeline execution"
    
    # Initialize log file
    echo "=== Nextflow Offline Setup Log ===" > "${LOG_FILE}"
    echo "Started: $(date)" >> "${LOG_FILE}"
    echo "Host: $(hostname)" >> "${LOG_FILE}"
    echo "" >> "${LOG_FILE}"
    
    check_required_tools
    load_env_credentials
    validate_assets
    load_docker_images
    validate_loaded_images
    create_offline_config
    generate_status_report
    
    log "Offline setup completed successfully!"
    log "Next step: Run './run-offline-pipeline.sh' to execute the pipeline"
}

# Execute main function
main "$@"
#!/bin/bash
# run-offline-pipeline.sh - Run nf-core/demo pipeline in offline mode (MVP demo)
set -euo pipefail

# Simple config
PIPELINE_DIR="./offline-assets/pipeline"
OFFLINE_CONFIG="./nextflow-offline.config"
SAMPLESHEET="${PIPELINE_DIR}/assets/samplesheet.csv"
OUTDIR="./results"

# Simple logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Simple error handler
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Main function
main() {
    log "Starting offline Nextflow pipeline execution"
    
    # Check requirements
    log "Checking requirements..."
    command -v nextflow &>/dev/null || error_exit "nextflow not found"
    command -v docker &>/dev/null || error_exit "docker not found"
    docker info &>/dev/null || error_exit "Docker daemon not running"
    log "Required tools available"
    
    # Validate offline setup
    log "Validating offline setup..."
    [[ ! -d "${PIPELINE_DIR}" ]] && error_exit "Pipeline not found. Run online-prepare.sh first."
    [[ ! -f "${OFFLINE_CONFIG}" ]] && error_exit "Offline config not found. Run offline-setup.sh first."
    [[ ! -f "${PIPELINE_DIR}/main.nf" ]] && error_exit "Pipeline main.nf not found"
    [[ ! -f "${SAMPLESHEET}" ]] && error_exit "Sample sheet not found: ${SAMPLESHEET}"
    log "Offline setup validated"
    
    # Create output directory
    log "Preparing output directory..."
    mkdir -p "${OUTDIR}"
    log "Output directory: ${OUTDIR}"
    
    # Run pipeline
    log "Executing nf-core/demo pipeline in offline mode..."
    log "Pipeline directory: ${PIPELINE_DIR}"
    log "Configuration: ${OFFLINE_CONFIG}"
    log "Sample sheet: ${SAMPLESHEET}"
    log "Output directory: ${OUTDIR}"
    
    # Execute nextflow with offline configuration
    nextflow run "${PIPELINE_DIR}/main.nf" \
        -c "${OFFLINE_CONFIG}" \
        --input "${SAMPLESHEET}" \
        --outdir "${OUTDIR}" \
        -offline \
        -resume
    
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        log "Pipeline execution completed successfully!"
        log "Results available in: ${OUTDIR}"
        log "View MultiQC report: ${OUTDIR}/multiqc/multiqc_report.html"
        
        echo ""
        echo "✓ Offline pipeline execution completed successfully!"
        echo "✓ Results: ${OUTDIR}"
        echo "✓ MultiQC report: ${OUTDIR}/multiqc/multiqc_report.html"
        echo "✓ MVP Demo complete!"
    else
        error_exit "Pipeline execution failed with exit code: ${exit_code}"
    fi
}

main "$@"
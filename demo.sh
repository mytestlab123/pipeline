#!/bin/bash
# demo.sh - End-to-end demonstration of Nextflow offline execution workflow
# Orchestrates complete online → offline workflow using S3 + Docker Hub
set -euo pipefail

# Configuration
PIPE=${PIPE:-nf-core/demo}
VER=${VER:-1.0.2}
PROJECT_NAME=${PROJECT_NAME:-demo}
ROOT="$HOME/pipe"
PROJ="$ROOT/$PROJECT_NAME"
OUT="$PROJ/offline"
S3_PREFIX="lifebit-user-data-nextflow/pipe"
NS="mytestlab123"

DEMO_LOG="/tmp/demo-execution.log"
DEMO_START_TIME=$(date +%s)
DEMO_MODE="${1:-full}"  # full, online-only, offline-only, or validate

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "STEP")  echo -e "${BLUE}[STEP]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$DEMO_LOG"
}

# Performance tracking
start_phase() {
    local phase_name="$1"
    echo "$(date +%s)" > "/tmp/demo-phase-${phase_name}.start"
    log "STEP" "Starting phase: $phase_name"
}

end_phase() {
    local phase_name="$1"
    local start_time=$(cat "/tmp/demo-phase-${phase_name}.start" 2>/dev/null || echo "0")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "$duration" > "/tmp/demo-phase-${phase_name}.duration"
    log "SUCCESS" "Phase '$phase_name' completed in ${duration}s"
}

# Environment validation
validate_environment() {
    log "STEP" "Validating environment prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    for tool in git docker nextflow aws; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "ERROR" "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info &>/dev/null; then
        log "ERROR" "Docker daemon is not running"
        return 1
    fi
    
    # Check .env file for Docker credentials
    if [[ "$DEMO_MODE" == "online-only" || "$DEMO_MODE" == "full" ]]; then
        if [[ ! -f "$HOME/.env" ]]; then
            log "ERROR" "Missing $HOME/.env file for Docker credentials"
            return 1
        fi
    fi
    
    log "SUCCESS" "Environment validation completed"
    return 0
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up demo environment..."
    
    # Clean up temporary files
    rm -f /tmp/demo-phase-*.start /tmp/demo-phase-*.duration
    
    # Remove demo assets if requested
    if [[ "${DEMO_CLEANUP:-false}" == "true" ]]; then
        rm -rf ./offline-assets
        rm -f ./nextflow-offline.config
        log "INFO" "Demo assets cleaned up"
    fi
}

# Online phase execution
run_online_phase() {
    start_phase "online"
    
    log "STEP" "=== ONLINE PHASE ==="
    log "INFO" "Executing online preparation workflow for $PIPE@$VER..."
    
    # Setup environment
    source "$HOME/.env"
    export NXF_HOME="$HOME/.nextflow"
    
    # Create project directory
    mkdir -p "$OUT"
    cd "$PROJ"
    log "INFO" "Working in $PROJ for $PIPE@$VER"
    
    # Step 1: Build offline FASTQ dataset
    log "INFO" "Step 1: Building offline FASTQ dataset..."
    if [[ -f "data.csv" ]]; then
        if ! ./build_offline_dataset.sh data.csv /tmp/offline-fastq data_offline.csv; then
            log "ERROR" "Failed to build offline dataset"
            return 1
        fi
        cp -r /tmp/offline-fastq .
    else
        log "WARN" "No data.csv found - skipping offline dataset creation"
    fi
    
    # Step 2: Download workflow code (no containers)
    log "INFO" "Step 2: Downloading pipeline code..."
    if ! nf-core pipelines download "$PIPE" \
        --revision "$VER" --compress none --container-system none \
        --outdir "$OUT" --force; then
        log "ERROR" "Failed to download pipeline"
        return 1
    fi
    
    # Step 3: Generate container manifest
    log "INFO" "Step 3: Generating container manifest..."
    if ! nextflow inspect "$PIPE" -r "$VER" \
        -profile test,docker -concretize true -format json --outdir /tmp/inspect-dir \
        | jq -r '.processes[].container' > images.txt; then
        log "ERROR" "Failed to generate container manifest"
        return 1
    fi
    
    # Step 4: Mirror containers to Docker Hub
    log "INFO" "Step 4: Mirroring containers to Docker Hub..."
    if ! ./copy.sh images.txt \
        --dest-registry docker.io --dest-namespace "$NS" \
        --dest-creds "$DOCKER_USER:$DOCKER_PAT"; then
        log "ERROR" "Failed to mirror containers"
        return 1
    fi
    
    # Step 5: Clean and sync to S3
    log "INFO" "Step 5: Syncing to S3..."
    find "$ROOT" -type d \( -name '.nextflow' -o -name 'work' \) -exec rm -rf {} + || true
    if ! aws s3 sync "$ROOT" "s3://$S3_PREFIX/" --delete; then
        log "ERROR" "Failed to sync to S3"
        return 1
    fi
    
    end_phase "online"
    log "SUCCESS" "Online phase completed successfully"
}

# Offline phase execution
run_offline_phase() {
    start_phase "offline"
    
    log "STEP" "=== OFFLINE PHASE ==="
    log "INFO" "Executing offline preparation and execution workflow for $PIPE@$VER..."
    
    # Setup environment
    source "$HOME/.env"
    export NXF_HOME="$HOME/.nextflow"
    export NXF_OFFLINE=true
    export NXF_DEBUG=2
    
    # Step 1: Pull artifacts from S3
    log "INFO" "Step 1: Downloading artifacts from S3..."
    if ! aws s3 sync "s3://$S3_PREFIX/" "$ROOT" --delete; then
        log "ERROR" "Failed to download from S3"
        return 1
    fi
    
    # Move to project directory
    mkdir -p "$PROJ" && cd "$PROJ"
    cp -r offline-fastq /tmp/ || log "WARN" "No offline-fastq found"
    
    # Step 2: Retag mirrored images
    log "INFO" "Step 2: Retagging mirrored images..."
    if ! bash ./retag_biocontainers.sh; then
        log "ERROR" "Failed to retag containers"
        return 1
    fi
    
    # Step 3: Optional config adjustments
    log "INFO" "Step 3: Adjusting configuration..."
    if [[ -f "test.config" ]]; then
        cp -v test.config offline/1_0_2/conf/test.config || true
    fi
    
    # Step 4: Launch offline pipeline
    log "INFO" "Step 4: Launching offline pipeline..."
    if ! nextflow -log /tmp/run.log run offline/1_0_2/ \
        -profile test,docker \
        --input ./data_offline.csv \
        --outdir /tmp/out-demo \
        -w /tmp/work-demo; then
        log "ERROR" "Failed to run offline pipeline"
        return 1
    fi
    
    end_phase "offline"
    log "SUCCESS" "Offline phase completed successfully"
}

# Performance report
generate_performance_report() {
    log "INFO" "Generating performance report..."
    
    local total_duration=$(($(date +%s) - DEMO_START_TIME))
    
    cat > "/tmp/demo-performance-report.txt" << EOF
=== Nextflow Offline Execution Demo - Performance Report ===
Generated: $(date)
Total Demo Duration: ${total_duration}s

=== Phase Performance ===
EOF
    
    # Add individual phase durations
    for phase in online offline; do
        if [[ -f "/tmp/demo-phase-${phase}.duration" ]]; then
            local duration=$(cat "/tmp/demo-phase-${phase}.duration")
            echo "${phase} phase: ${duration}s" >> "/tmp/demo-performance-report.txt"
        fi
    done
    
    cat >> "/tmp/demo-performance-report.txt" << EOF

=== Asset Summary ===
Pipeline assets: $(find ./offline-assets -type f 2>/dev/null | wc -l) files
Docker images: $(cat ./offline-assets/images.txt 2>/dev/null | wc -l) images
Log files: Available in /tmp/

=== Next Steps ===
- Review generated assets in ./offline-assets/
- Check pipeline results in ./results/ (if executed)
- Review logs in /tmp/ directory
- Clean up with: DEMO_CLEANUP=true ./demo.sh
EOF
    
    log "SUCCESS" "Performance report generated: /tmp/demo-performance-report.txt"
}

# Display help
show_help() {
    cat << EOF
Usage: $0 [MODE]

Nextflow Offline Execution Demo - S3 + Docker Hub Workflow

MODES:
    full         Complete online → offline workflow (default)
    online-only  Execute only online phase (prepare and sync to S3)
    offline-only Execute only offline phase (download from S3 and run)
    validate     Validate environment and prerequisites only
    help         Show this help message

ENVIRONMENT VARIABLES:
    PIPE=nf-core/demo       Pipeline to use (default: nf-core/demo)
    VER=1.0.2              Pipeline version (default: 1.0.2)
    PROJECT_NAME=demo       Project name (default: demo)
    DEMO_CLEANUP=true       Clean up demo assets after execution
    DOCKER_USER             Docker Hub username (in .env file)
    DOCKER_PAT              Docker Hub personal access token (in .env file)

EXAMPLES:
    ./demo.sh                                    # Full end-to-end demo
    ./demo.sh validate                           # Check environment only
    ./demo.sh online-only                        # Prepare assets and sync to S3
    ./demo.sh offline-only                       # Download from S3 and run offline
    PIPE=nf-core/sarek VER=3.3.2 ./demo.sh     # Use different pipeline

REQUIREMENTS:
    - Git, Docker, Nextflow, AWS CLI installed
    - Internet connectivity for online phase
    - Docker Hub credentials (.env file)
    - AWS credentials for S3 access
    - S3 bucket: s3://lifebit-user-data-nextflow/pipe/

For more information, see DEMO_plan.md
EOF
}

# Main execution
main() {
    # Initialize logging
    echo "=== Nextflow Offline Execution Demo Log ===" > "$DEMO_LOG"
    echo "Started: $(date)" >> "$DEMO_LOG"
    echo "Mode: $DEMO_MODE" >> "$DEMO_LOG"
    echo "" >> "$DEMO_LOG"
    
    # Setup cleanup trap
    trap cleanup EXIT
    
    log "INFO" "Starting Nextflow Offline Execution Demo"
    log "INFO" "Mode: $DEMO_MODE"
    log "INFO" "Log file: $DEMO_LOG"
    
    case "$DEMO_MODE" in
        "validate")
            validate_environment
            ;;
        "online-only")
            validate_environment || exit 1
            run_online_phase
            ;;
        "offline-only")
            validate_environment || exit 1
            run_offline_phase
            ;;
        "full")
            validate_environment || exit 1
            run_online_phase
            run_offline_phase
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            log "ERROR" "Invalid mode: $DEMO_MODE"
            show_help
            exit 1
            ;;
    esac
    
    # Generate performance report
    generate_performance_report
    
    log "SUCCESS" "Demo execution completed successfully!"
    log "INFO" "Performance report: /tmp/demo-performance-report.txt"
    log "INFO" "Full log: $DEMO_LOG"
    
    # Display summary
    echo ""
    echo "🎉 Nextflow Offline Execution Demo Completed!"
    echo "📊 Performance report: /tmp/demo-performance-report.txt"
    echo "📋 Full log: $DEMO_LOG"
    echo "📁 Assets: $PROJ/"
    echo "📦 S3 bucket: s3://$S3_PREFIX/"
    echo ""
    echo "Next steps:"
    echo "  - Review the generated assets and logs"
    echo "  - Check S3 bucket contents: aws s3 ls s3://$S3_PREFIX/ --recursive"
    echo "  - Test offline execution on your offline EC2 instance"
    echo "  - Extend to other pipelines: PIPE=nf-core/sarek VER=3.3.2 ./demo.sh"
}

# Execute main function
main "$@"
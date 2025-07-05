#!/bin/bash
# demo.sh - End-to-end demonstration of Nextflow offline execution workflow
# Orchestrates complete online → offline workflow with performance benchmarking
set -euo pipefail

# Configuration
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
    for tool in git docker nextflow; do
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
    
    # Check network connectivity
    if ! curl -s --max-time 5 https://github.com &>/dev/null; then
        log "WARN" "No internet connectivity - offline-only mode available"
        return 0
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
    log "INFO" "Executing online preparation workflow..."
    
    # Step 1: Download pipeline assets
    log "INFO" "Step 1: Downloading nf-core/demo pipeline assets..."
    if ! ./online-prepare.sh; then
        log "ERROR" "Failed to download pipeline assets"
        return 1
    fi
    
    # Step 2: Generate Docker image list
    log "INFO" "Step 2: Generating Docker image list..."
    if ! ./generate-image-list.sh; then
        log "ERROR" "Failed to generate image list"
        return 1
    fi
    
    # Step 3: Pull and copy Docker images (if credentials available)
    log "INFO" "Step 3: Pulling Docker images..."
    if [[ -f ".env" ]]; then
        if ! ./pull-images.sh; then
            log "WARN" "Failed to pull Docker images - continuing with existing images"
        fi
    else
        log "WARN" "No .env file found - skipping image pulling"
        log "INFO" "Create .env file with DOCKER_USER and DOCKER_PAT to enable image pulling"
    fi
    
    end_phase "online"
    log "SUCCESS" "Online phase completed successfully"
}

# Offline phase execution
run_offline_phase() {
    start_phase "offline"
    
    log "STEP" "=== OFFLINE PHASE ==="
    log "INFO" "Executing offline preparation and execution workflow..."
    
    # Step 4: Setup offline environment
    log "INFO" "Step 4: Setting up offline environment..."
    if ! ./offline-setup.sh; then
        log "ERROR" "Failed to setup offline environment"
        return 1
    fi
    
    # Step 5: Run offline pipeline
    log "INFO" "Step 5: Running offline pipeline..."
    if ! ./run-offline-pipeline.sh; then
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

Nextflow Offline Execution Demo - End-to-End Workflow Orchestration

MODES:
    full         Complete online → offline workflow (default)
    online-only  Execute only online phase (download and prepare)
    offline-only Execute only offline phase (setup and run)
    validate     Validate environment and prerequisites only
    help         Show this help message

ENVIRONMENT VARIABLES:
    DEMO_CLEANUP=true    Clean up demo assets after execution
    DOCKER_USER          Docker Hub username (in .env file)
    DOCKER_PAT           Docker Hub personal access token (in .env file)

EXAMPLES:
    ./demo.sh                    # Full end-to-end demo
    ./demo.sh validate           # Check environment only
    ./demo.sh online-only        # Prepare assets only
    DEMO_CLEANUP=true ./demo.sh  # Run demo and cleanup afterward

REQUIREMENTS:
    - Git, Docker, Nextflow installed
    - Internet connectivity for online phase
    - Docker Hub credentials for image pulling (.env file)
    - Sufficient disk space (>2GB recommended)

For more information, see docs/README.md
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
    echo "📁 Assets: ./offline-assets/"
    echo ""
    echo "Next steps:"
    echo "  - Review the generated assets and logs"
    echo "  - Test the offline pipeline with your own data"
    echo "  - Deploy to your AWS EC2 offline environment"
}

# Execute main function
main "$@"
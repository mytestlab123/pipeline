#!/bin/bash
# setup_repository_online.sh - Copy Docker images using Skopeo for offline repository
set -euo pipefail

# Configuration
SOURCE_FILE="${1:-images.txt}"
OUTPUT_FILE="${2:-destination.txt}"
ENV_FILE="${HOME}/.env"
DEST_REGISTRY="${DEST_REGISTRY:-docker.io}"
DEST_NAMESPACE="${DEST_NAMESPACE:-mytestlab123}"
SKOPEO_IMAGE="quay.io/skopeo/stable"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load credentials
if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: .env file not found at ${ENV_FILE}"
    exit 1
fi

source "${ENV_FILE}"

if [[ -z "${DOCKER_USER:-}" ]] || [[ -z "${DOCKER_PAT:-}" ]]; then
    echo "ERROR: DOCKER_USER or DOCKER_PAT not set in ${ENV_FILE}"
    exit 1
fi

DEST_CREDS="${DOCKER_USER}:${DOCKER_PAT}"

print_status "$YELLOW" "Starting repository setup..."
print_status "$YELLOW" "Source file: ${SOURCE_FILE}"
print_status "$YELLOW" "Output file: ${OUTPUT_FILE}"
print_status "$YELLOW" "Registry: ${DEST_REGISTRY}/${DEST_NAMESPACE}/"

# Check prerequisites
if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "ERROR: Source file not found: ${SOURCE_FILE}"
    exit 1
fi

# Initialize output file
echo "# Destination images for offline repository" > "${OUTPUT_FILE}"
echo "# Generated: $(date)" >> "${OUTPUT_FILE}"
echo "" >> "${OUTPUT_FILE}"

get_image_name() {
    local full_image="$1"
    full_image="${full_image#docker://}"
    
    if [[ "$full_image" == *:* ]] && [[ "$full_image" != *://* ]]; then
        full_image="${full_image%:*}"
    fi
    
    basename "${full_image}"
}

copy_image() {
    local source_image="$1"
    
    if [[ ! "$source_image" =~ ^docker:// ]]; then
        source_image="docker://${source_image}"
    fi
    
    local image_name
    image_name=$(get_image_name "$source_image")
    
    local tag="latest"
    if [[ "$source_image" == *:* ]]; then
        local temp_image="${source_image#docker://}"
        if [[ "$temp_image" == *:* ]]; then
            tag="${temp_image##*:}"
        fi
    fi
    
    local dest_image="docker://${DEST_REGISTRY}/${DEST_NAMESPACE}/${image_name}:${tag}"
    local dest_name="${DEST_NAMESPACE}/${image_name}:${tag}"
    
    print_status "$YELLOW" "Copying: ${source_image} -> ${dest_image}"
    
    if docker run --rm "${SKOPEO_IMAGE}" copy \
        --dest-creds "${DEST_CREDS}" \
        "${source_image}" "${dest_image}"; then
        print_status "$GREEN" "✓ Successfully copied: ${image_name}:${tag}"
        echo "${dest_name}" >> "${OUTPUT_FILE}"
        return 0
    else
        print_status "$RED" "✗ Failed to copy: ${image_name}:${tag}"
        return 1
    fi
}

# Process each image
success_count=0
failure_count=0

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    line=$(echo "$line" | xargs)
    [[ -z "$line" ]] && continue
    
    if copy_image "$line"; then
        success_count=$((success_count + 1))
    else
        failure_count=$((failure_count + 1))
    fi
done < "$SOURCE_FILE"

print_status "$YELLOW" "=== SUMMARY ==="
print_status "$GREEN" "Successfully copied: $success_count images"

if [[ "$failure_count" -gt 0 ]]; then
    print_status "$RED" "Failed to copy: $failure_count images"
    exit 1
else
    print_status "$GREEN" "✅ All images copied successfully!"
    print_status "$GREEN" "✅ Destination list: ${OUTPUT_FILE}"
fi
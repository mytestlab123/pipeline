#!/bin/bash
# pull-images.sh - Copy Docker images using Skopeo (working version)
set -euo pipefail

# Configuration
IMAGES_FILE="images.txt"
LOG_FILE="/tmp/pull-images.log"
ENV_FILE="${HOME}/.env"
DEST_REGISTRY="docker.io"
DEST_NAMESPACE="mytestlab123"
SKOPEO_IMAGE="quay.io/skopeo/stable"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Initialize log
echo "=== Pull Images Log - $(date) ===" > "${LOG_FILE}"

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

# Construct destination credentials
DEST_CREDS="${DOCKER_USER}:${DOCKER_PAT}"

echo "Starting image copy process..."
echo "User: ${DOCKER_USER}"
echo "Registry: ${DEST_REGISTRY}/${DEST_NAMESPACE}/"
echo "Credentials: ${DOCKER_USER}:****** (username shown only)"
echo

# Function to extract image name from full image path
get_image_name() {
    local full_image="$1"
    # Remove docker:// prefix if present
    full_image="${full_image#docker://}"
    
    # If there's a tag, remove it first
    if [[ "$full_image" == *:* ]] && [[ "$full_image" != *://* ]]; then
        full_image="${full_image%:*}"
    fi
    
    # Extract just the image name (after last /)
    basename "${full_image}"
}

# Function to check if image exists at destination
check_image_exists() {
    local dest_image="$1"
    local dest_creds="$2"

    # Try to inspect the destination image
    if docker run --rm "${SKOPEO_IMAGE}" inspect \
        --creds "${dest_creds}" \
        "${dest_image}" >/dev/null 2>>"${LOG_FILE}"; then
        return 0  # Image exists
    else
        return 1  # Image doesn't exist
    fi
}

# Function to copy a single image
copy_image() {
    local source_image="$1"
    local dest_registry="$2"
    local dest_namespace="$3"
    local dest_creds="$4"

    # Add docker:// prefix if not present
    if [[ ! "$source_image" =~ ^docker:// ]]; then
        source_image="docker://${source_image}"
    fi

    # Extract image name and tag
    local image_name
    image_name=$(get_image_name "$source_image")

    # Extract tag (default to latest if not specified)
    local tag="latest"
    # Check if there's a tag (has : but not part of protocol like docker://)
    if [[ "$source_image" == *:* ]]; then
        # Remove docker:// prefix first
        local temp_image="${source_image#docker://}"
        # Now check if there's still a colon (indicating a tag)
        if [[ "$temp_image" == *:* ]]; then
            tag="${temp_image##*:}"
        fi
    fi

    # Construct destination image
    local dest_image="docker://${dest_registry}/${dest_namespace}/${image_name}:${tag}"

    # Check if image already exists at destination
    print_status "$YELLOW" "Checking if ${dest_registry}/${dest_namespace}/${image_name}:${tag} exists..."

    if check_image_exists "${dest_image}" "${dest_creds}"; then
        print_status "$GREEN" "⚠ Image already exists: ${image_name}:${tag} (skipping)"
        return 2  # Return 2 for skipped images
    fi

    print_status "$YELLOW" "Copying: ${source_image} -> ${dest_image}"

    if docker run --rm "${SKOPEO_IMAGE}" copy \
        --dest-creds "${dest_creds}" \
        "${source_image}" "${dest_image}" 2>>"${LOG_FILE}"; then
        print_status "$GREEN" "✓ Successfully copied: ${image_name}:${tag}"
        return 0
    else
        print_status "$RED" "✗ Failed to copy: ${image_name}:${tag}"
        return 1
    fi
}

# Check prerequisites
if [[ ! -f "${IMAGES_FILE}" ]]; then
    echo "ERROR: Images file not found: ${IMAGES_FILE}"
    exit 1
fi

# Count total images
total_images=$(grep -c '^[^#]' "$IMAGES_FILE" || echo 0)

if [[ "$total_images" -eq 0 ]]; then
    print_status "$RED" "No valid images found in file!"
    exit 1
fi

print_status "$YELLOW" "Found $total_images images to copy"
echo

# Process each image
success_count=0
failure_count=0
skipped_count=0
current=0

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)
    [[ -z "$line" ]] && continue

    current=$((current + 1))
    print_status "$YELLOW" "[$current/$total_images] Processing: $line"

    if copy_image "$line" "$DEST_REGISTRY" "$DEST_NAMESPACE" "$DEST_CREDS"; then
        copy_result=$?
        if [[ $copy_result -eq 2 ]]; then
            skipped_count=$((skipped_count + 1))
        else
            success_count=$((success_count + 1))
        fi
    else
        failure_count=$((failure_count + 1))
    fi

    echo
done < "$IMAGES_FILE"

# Summary
print_status "$YELLOW" "=== SUMMARY ==="
print_status "$GREEN" "Successfully copied: $success_count images"
if [[ "$skipped_count" -gt 0 ]]; then
    print_status "$YELLOW" "Already existed (skipped): $skipped_count images"
fi

if [[ "$failure_count" -gt 0 ]]; then
    print_status "$RED" "Failed to copy: $failure_count images"
    
    # Generate manifest with failure info
    {
        echo "# Docker Images copy results - ${DEST_REGISTRY}/${DEST_NAMESPACE}"
        echo "# Generated: $(date)"
        echo "# Total: ${total_images}, Copied: ${success_count}, Skipped: ${skipped_count}, Failed: ${failure_count}"
        echo ""
        echo "## Successfully copied images:"
        echo "# (Check log for details: ${LOG_FILE})"
    } > "./offline-assets/pull-images-manifest.txt"
    
    echo ""
    echo "📋 Manifest: ./offline-assets/pull-images-manifest.txt"
    echo "📋 Log: ${LOG_FILE}"
    echo "⚠ Completed with ${failure_count} failures"
    exit 1
else
    # Generate success manifest
    {
        echo "# Docker Images copied to ${DEST_REGISTRY}/${DEST_NAMESPACE}"
        echo "# Generated: $(date)"
        echo "# Total: ${total_images}, Copied: ${success_count}, Skipped: ${skipped_count}, Failed: ${failure_count}"
        echo ""
        echo "## Images available at destination:"
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            line=$(echo "$line" | xargs)
            [[ -z "$line" ]] && continue
            
            # Extract image name and tag
            image_name=$(get_image_name "$line")
            tag="latest"
            # Check if there's a tag (not part of protocol)
            if [[ "$line" == *:* ]]; then
                # Remove any docker:// prefix first
                local temp_line="${line#docker://}"
                # Now check if there's still a colon (indicating a tag)
                if [[ "$temp_line" == *:* ]]; then
                    tag="${temp_line##*:}"
                fi
            fi
            echo "${DEST_REGISTRY}/${DEST_NAMESPACE}/${image_name}:${tag}"
        done < "$IMAGES_FILE"
    } > "./offline-assets/pull-images-manifest.txt"
    
    echo ""
    echo "📋 Manifest: ./offline-assets/pull-images-manifest.txt"
    echo "📋 Log: ${LOG_FILE}"
    print_status "$GREEN" "✅ All images processed successfully!"
    print_status "$GREEN" "✅ Copied: ${success_count}, Skipped: ${skipped_count}"
fi

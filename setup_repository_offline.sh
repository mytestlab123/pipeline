#!/bin/bash
# setup_repository_offline.sh - Setup offline repository with retagging and pulling
set -euo pipefail

# Configuration
SOURCE_FILE="${1:-images.txt}"
DEST_FILE="${2:-destination.txt}"

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

print_status "$YELLOW" "Starting offline repository setup..."
print_status "$YELLOW" "Source file: ${SOURCE_FILE}"
print_status "$YELLOW" "Destination file: ${DEST_FILE}"

# Check prerequisites
if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "ERROR: Source file not found: ${SOURCE_FILE}"
    exit 1
fi

if [[ ! -f "${DEST_FILE}" ]]; then
    echo "ERROR: Destination file not found: ${DEST_FILE}"
    exit 1
fi

# Function to extract image name and tag from full path
get_image_parts() {
    local full_image="$1"
    full_image="${full_image#docker://}"
    
    local image_name
    local tag="latest"
    
    if [[ "$full_image" == *:* ]] && [[ "$full_image" != *://* ]]; then
        tag="${full_image##*:}"
        image_name="${full_image%:*}"
    else
        image_name="${full_image}"
    fi
    
    image_name=$(basename "${image_name}")
    echo "${image_name}:${tag}"
}

# Step 1: Pull all images from destination file
print_status "$YELLOW" "=== STEP 1: Pulling images from repository ==="
pull_success=0
pull_failure=0

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    line=$(echo "$line" | xargs)
    [[ -z "$line" ]] && continue
    
    print_status "$YELLOW" "Pulling: ${line}"
    
    if docker pull "${line}"; then
        print_status "$GREEN" "✓ Successfully pulled: ${line}"
        pull_success=$((pull_success + 1))
    else
        print_status "$RED" "✗ Failed to pull: ${line}"
        pull_failure=$((pull_failure + 1))
    fi
done < "$DEST_FILE"

# Step 2: Retag images to match original references
print_status "$YELLOW" "=== STEP 2: Retagging images for pipeline compatibility ==="
retag_success=0
retag_failure=0

# Create mapping between source and destination images
declare -A image_mapping

while IFS= read -r dest_line; do
    [[ -z "$dest_line" || "$dest_line" =~ ^[[:space:]]*# ]] && continue
    dest_line=$(echo "$dest_line" | xargs)
    [[ -z "$dest_line" ]] && continue
    
    # Extract image name and tag from destination
    dest_parts=$(get_image_parts "$dest_line")
    image_mapping["$dest_parts"]="$dest_line"
done < "$DEST_FILE"

while IFS= read -r source_line; do
    [[ -z "$source_line" || "$source_line" =~ ^[[:space:]]*# ]] && continue
    source_line=$(echo "$source_line" | xargs)
    [[ -z "$source_line" ]] && continue
    
    # Extract image name and tag from source
    source_parts=$(get_image_parts "$source_line")
    
    # Find corresponding destination image
    if [[ -n "${image_mapping[$source_parts]:-}" ]]; then
        dest_image="${image_mapping[$source_parts]}"
        source_clean="${source_line#docker://}"
        
        print_status "$YELLOW" "Retagging: ${dest_image} -> ${source_clean}"
        
        if docker tag "${dest_image}" "${source_clean}"; then
            print_status "$GREEN" "✓ Successfully retagged: ${source_clean}"
            retag_success=$((retag_success + 1))
        else
            print_status "$RED" "✗ Failed to retag: ${source_clean}"
            retag_failure=$((retag_failure + 1))
        fi
    else
        print_status "$RED" "✗ No matching destination image found for: ${source_line}"
        retag_failure=$((retag_failure + 1))
    fi
done < "$SOURCE_FILE"

# Summary
print_status "$YELLOW" "=== SUMMARY ==="
print_status "$GREEN" "Images pulled: $pull_success"
print_status "$GREEN" "Images retagged: $retag_success"

if [[ "$pull_failure" -gt 0 ]] || [[ "$retag_failure" -gt 0 ]]; then
    print_status "$RED" "Pull failures: $pull_failure"
    print_status "$RED" "Retag failures: $retag_failure"
    exit 1
else
    print_status "$GREEN" "✅ Offline repository setup completed successfully!"
    print_status "$GREEN" "✅ All images are now available with original references"
fi
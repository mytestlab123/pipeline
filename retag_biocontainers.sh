#!/usr/bin/env bash
# retag_biocontainers.sh
#
# Map private-mirror tags → original quay.io/biocontainers/* tags
# Works with Docker or Podman (CLI syntax is identical).

set -Eeuo pipefail

# 1) Define the mapping:  private repo  →  original nf-core tag
declare -A MAP=(
  [mytestlab123/fastqc:0.12.1--hdfd78af_0]="quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"
  [mytestlab123/multiqc:1.29--pyhdfd78af_0]="quay.io/biocontainers/multiqc:1.29--pyhdfd78af_0"
  [mytestlab123/seqtk:1.4--he4a0461_1]="quay.io/biocontainers/seqtk:1.4--he4a0461_1"
)

# 2) Loop and retag
for SRC in "${!MAP[@]}"; do
  DST="${MAP[$SRC]}"
  echo "▶︎ Retagging  $SRC  →  $DST"
  docker image inspect "$SRC" >/dev/null 2>&1 || {
      echo "  ⚠️  Source image not found locally; skipping"
      continue
  }
  docker tag "$SRC" "$DST"
done

echo "✅  Retagging complete.  Run 'docker images | grep biocontainers' to verify."


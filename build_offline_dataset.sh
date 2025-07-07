#!/usr/bin/env bash
# Convert an nf-core sample sheet with HTTP URLs to an offline variant.
#
# Usage: ./build_offline_dataset.sh data.csv offline-fastq data_offline.csv
#        (all arguments optional; see defaults below)

set -Eeuo pipefail

INPUT=${1:-data.csv}          # original sheet
OUTDIR=${2:-offline-fastq}    # where FASTQs are cached
OUTPUT=${3:-data_offline.csv} # rewritten sheet

mkdir -p "$OUTDIR"

# copy header verbatim
read -r header < "$INPUT"
echo "$header" > "$OUTPUT"

# read each subsequent line in a csv-safe loop
tail -n +2 "$INPUT" | while IFS=, read -r sample url1 url2; do
  [[ -z ${sample} ]] && continue   # skip blank lines

  fetch() {
    local url=$1
    if [[ -n $url ]]; then
      local file=$(basename "$url" | tr -d '\r')  # strip CR if any :contentReference[oaicite:4]{index=4}
      local dest="$(realpath "$OUTDIR/$file")"
#      local dest="$OUTDIR/$file"
      if [[ ! -f $dest ]]; then
        echo " ↓  $file" >&2                     # progress to stderr only :contentReference[oaicite:5]{index=5}
        curl -L --silent --show-error --retry 5 -o "$dest" "$url"
      fi
      printf '%s' "$dest"
    fi
  }

  local1=$(fetch "$url1")
  local2=$(fetch "$url2")

  # emit a single well-formed CSV record
  echo "$sample,$local1,$local2" >>"$OUTPUT"
done

echo "✅  Offline sheet written to $(realpath "$OUTPUT")" >&2


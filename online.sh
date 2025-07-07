#!/usr/bin/env bash
# ------------------------------------------------------------
#  Build an offline bundle for any nf-core pipeline.
#
#  Usage examples
#     ./online.sh demo5                       # default demo pipeline
#     PIPE=nf-core/sarek VER=3.3.2 ./online.sh sarek-new
# ------------------------------------------------------------
set -Eeuo pipefail

# --------- user-tunable vars or env overrides ----------------
PIPE=${PIPE:-nf-core/demo}
VER=${VER:-1.0.2}
PROJECT_NAME=${1:-demo}               # first CLI arg, default “demo”
ROOT="$HOME/pipe"
PROJ="$ROOT/$PROJECT_NAME"
OUT="$PROJ/offline"
S3_PREFIX="lifebit-user-data-nextflow/pipe"
NS="mytestlab123"                     # Docker Hub namespace

source "$HOME/.env"                   # provides $DOCKER_USER and $DOCKER_PAT
export NXF_HOME="$HOME/.nextflow"
# -------------------------------------------------------------

mkdir -p "$OUT" 
cd "$PROJ"
echo "▶︎ Working in $PROJ for $PIPE@$VER"

# 1. Build offline FASTQ dataset
./build_offline_dataset.sh data.csv /tmp/offline-fastq data_offline.csv
cp -r /tmp/offline-fastq .

# 2. Download workflow code (no containers)
nf-core pipelines download "$PIPE" \
  --revision "$VER" --compress none --container-system none \
  --outdir "$OUT" --force

# 3. Generate container manifest
nextflow inspect "$PIPE" -r "$VER" \
  -profile test,docker -concretize true -format json --outdir /tmp/inspect-dir \
  | jq -r '.processes[].container' > images.txt

# 4. Mirror every container to Docker Hub $NS/*
./copy.sh images.txt \
  --dest-registry docker.io --dest-namespace "$NS" \
  --dest-creds "$DOCKER_USER:$DOCKER_PAT"

# 5. Clean Nextflow caches then sync to S3
find "$ROOT" -type d \( -name '.nextflow' -o -name 'work' \) -exec rm -rf {} +
aws s3 sync "$ROOT" "s3://$S3_PREFIX/" --delete

echo "✅  Online packaging finished for $PROJECT_NAME"


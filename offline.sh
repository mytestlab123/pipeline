#!/usr/bin/env bash
# ------------------------------------------------------------
#  Execute an nf-core pipeline completely offline.
#
#  Usage examples
#     ./offline.sh demo5
#     PIPE=nf-core/sarek VER=3.3.2 ./offline.sh sarek-new
# ------------------------------------------------------------
set -Eeuo pipefail

PIPE=${PIPE:-nf-core/demo}
VER=${VER:-1.0.2}
PROJECT_NAME=${1:-demo}
ROOT="$HOME/pipe"
PROJ="$ROOT/$PROJECT_NAME"
OUT="$PROJ/offline"
S3_PREFIX="lifebit-user-data-nextflow/pipe"

source "$HOME/.env"
export NXF_HOME="$HOME/.nextflow"
export NXF_OFFLINE=true
export NXF_DEBUG=2

# 1. Pull artefacts from S3
aws s3 sync "s3://$S3_PREFIX/" "$ROOT" --delete

mkdir -p "$PROJ" && cd "$PROJ"
cp -r offline-fastq /tmp/                     # local SSD for reads

# 2. Retag mirrored images ➜ quay.io/biocontainers/*
bash ./retag_biocontainers.sh

# 3. (optional) adjust memory or other test-profile tweaks
cp -v test.config offline/1_0_2/conf/test.config || true
echo "offline/1_0_2/conf/test.config"
cat offline/1_0_2/conf/test.config

# 4. Launch
nextflow -log /tmp/run.log run offline/1_0_2/ \
  -profile test,docker \
  --input ./data_offline.csv \
  --outdir /tmp/out-demo \
  -w /tmp/work-demo

echo "✅  Offline run completed for $PROJECT_NAME"


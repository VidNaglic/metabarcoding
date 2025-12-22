#!/usr/bin/env bash
set -euo pipefail

# 1. Define source & target
SRC_ROOT="/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/GIS_december2025"
FASTQ_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/fastq"

if [ ! -d "$SRC_ROOT" ]; then
  echo "Source folder not found: $SRC_ROOT" >&2
  exit 1
fi

# 2. Make sure the target exists (and is empty if you like)
mkdir -p "$FASTQ_DIR"
# rm -f "$FASTQ_DIR"/*.fastq.gz    # (uncomment if you want to wipe out old files)

# 3. Copy (or symlink) all R1/R2 FASTQs into one flat folder
for d in "$SRC_ROOT"/*; do
  [ -d "$d" ] || continue
  # inside each sample‐dir you should have exactly two files: *_R1_001.fastq.gz and *_R2_001.fastq.gz
  for fq in "$d"/*_R?_001.fastq.gz; do
    echo "→ Copying $(basename "$fq")"
    cp "$fq" "$FASTQ_DIR"/
    # or: ln -s "$fq" "$FASTQ_DIR"/   # if you prefer symlinks
  done
done

echo "All FASTQs are now in $FASTQ_DIR"

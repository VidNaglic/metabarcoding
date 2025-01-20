#!/bin/bash
# BOLDigger Pipeline Script (03_BOLDigger_pipeline.sh)
# This script runs the BOLDigger3 identification pipeline.

# Enable strict error handling
set -euo pipefail

# Log file for capturing output and errors
LOG_FILE="boldigger_pipeline.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting BOLDigger pipeline..."
echo "Activating boldigger3-env environment..."

# Ensure Conda is set up for this script
if [ -f "$(conda info --base)/etc/profile.d/conda.sh" ]; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
else
    echo "Error: Conda setup file not found. Ensure Conda is properly installed."
    exit 1
fi

conda activate boldigger3-env
echo "Environment activated: boldigger3-env"


echo "Starting BOLDigger pipeline..."

# Define paths
FASTA_FILE="/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/dna-sequences-validated.fasta"
OUTPUT_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/boldigger3-results"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Activate BOLDigger3 environment
echo "Activating boldigger3-env environment..."
conda activate boldigger3-env

# Run BOLDigger3
echo "Running BOLDigger3 identification..."

# Run BOLDigger3
echo "Running BOLDigger3 identification..."

# Define parameters
DB=1  # Database: ANIMAL LIBRARY (PUBLIC)
MODE=2  # Operating mode: Genus and Species Search
THRESHOLDS="98 95 90 85"  # Thresholds for species, genus, family, order
FASTA_FILE="/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/dna-sequences-validated.fasta"

# Run the identification process
boldigger3 identify \
  "$FASTA_FILE" \
  --db "$DB" \
  --mode "$MODE" \
  --thresholds $THRESHOLDS


# Move results to output directory
echo "Exporting BOLDigger3 results..."
mv dna-sequences-validated_identification_result.xlsx "$OUTPUT_DIR/" || echo "No Excel output found."
mv dna-sequences-validated_result_storage.h5.lz "$OUTPUT_DIR/" || echo "No HDF storage found."
mv dna-sequences-validated_identification_result.parquet.snappy "$OUTPUT_DIR/" || echo "No Parquet output found."

echo "BOLDigger pipeline completed. Results saved in $OUTPUT_DIR"

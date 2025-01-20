#!/bin/bash
# This is a metabarcoding data processing script

# Enable strict error handling
set -euo pipefail

# Log file for capturing output and errors
LOG_FILE="processing.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Setup directories - you need a directory where you have your fastq files and a directory where output will be generated
DATA_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/fastq"
OUTPUT_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo"
SCRIPT_DIR="$(dirname "$0")"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "Starting metabarcoding data processing..."
echo "Working directory: $DATA_DIR"
echo "Output directory: $OUTPUT_DIR"

# Change to data directory
cd "$DATA_DIR"

# List all FASTQ files and count them
echo "Counting FASTQ files..."
ls *.fastq.gz | wc -l

# Activate QIIME2 environment
echo "Activating QIIME2 environment..."
conda activate qiime2-2023.5

# Step 1: Create Manifest File
echo "Creating manifest file..."
echo "sample-id,absolute-filepath,direction" > "$OUTPUT_DIR/manifest.csv"
for i in *_R1_* ; do
    echo "${i/_R1_001.fastq.gz},$PWD/$i,forward"
done >> "$OUTPUT_DIR/manifest.csv"

for i in *_R2_* ; do
    echo "${i/_R2_001.fastq.gz},$PWD/$i,reverse"
done >> "$OUTPUT_DIR/manifest.csv"

# Step 2: Import Data into QIIME 2
echo "Importing data into QIIME 2..."
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path "$OUTPUT_DIR/manifest.csv" \
  --output-path "$OUTPUT_DIR/paired-end-demux.qza" \
  --input-format PairedEndFastqManifestPhred33

# Step 3: Check Quality of Sequencing Run
echo "Checking quality of the sequencing run..."
qiime demux summarize \
  --i-data "$OUTPUT_DIR/paired-end-demux.qza" \
  --o-visualization "$OUTPUT_DIR/paired-end-demux.qzv"

echo "Quality check completed. Please visualize the file 'paired-end-demux.qzv' using QIIME2 View."
echo "Once you determine the trimming and truncation parameters, edit the next section accordingly."

# Placeholder for user to adjust trimming and truncation parameters
read -p "Press Enter to continue once you've determined the trimming/truncation values..."

# Example trimming and truncation values to be edited by user
TRIM_LEFT=26
TRUNC_LEN_F=230
TRUNC_LEN_R=210
THREADS=8

# Step 4: Denoising with DADA2
echo "Starting DADA2 denoising with parameters:"
echo "  Trim left: $TRIM_LEFT"
echo "  Trunc length forward: $TRUNC_LEN_F"
echo "  Trunc length reverse: $TRUNC_LEN_R"
echo "  Threads: $THREADS"

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs "$OUTPUT_DIR/paired-end-demux.qza" \
  --p-trim-left-f "$TRIM_LEFT" \
  --p-trim-left-r "$TRIM_LEFT" \
  --p-trunc-len-f "$TRUNC_LEN_F" \
  --p-trunc-len-r "$TRUNC_LEN_R" \
  --p-n-threads "$THREADS" \
  --o-table "$OUTPUT_DIR/COI-table.qza" \
  --o-representative-sequences "$OUTPUT_DIR/COI-rep-seqs.qza" \
  --o-denoising-stats "$OUTPUT_DIR/COI-denoising-stats.qza" \
  --verbose

echo "DADA2 denoising completed."
echo "Outputs:"
echo "  Feature table: $OUTPUT_DIR/COI-table.qza"
echo "  Representative sequences: $OUTPUT_DIR/COI-rep-seqs.qza"
echo "  Denoising stats: $OUTPUT_DIR/COI-denoising-stats.qza"

echo "Denoising part completed successfully."

# Step 5: Visualizing Denoising Stats and Representative Sequences
echo "Visualizing denoising stats and representative sequences..."

qiime metadata tabulate \
  --m-input-file "$OUTPUT_DIR/COI-denoising-stats.qza" \
  --o-visualization "$OUTPUT_DIR/COI-denoising-stats.qzv" \
  --verbose

qiime feature-table tabulate-seqs \
  --i-data "$OUTPUT_DIR/COI-rep-seqs.qza" \
  --o-visualization "$OUTPUT_DIR/COI-rep-seqs.qzv" \
  --verbose

#qiime metadata tabulate: Converts the denoising stats to a visualization (COI-denoising-stats.qzv).
#qiime feature-table tabulate-seqs: Converts the representative sequences to a visualization (COI-rep-seqs.qzv).

#Here we come to the part of the process which will take longer time to compute. For that reason we can write a "screen" command and have the task running in background.
#If we are using the Elixir server to run the task we have to use SLURM (https://slurm.schedmd.com/)

8.	Start a screen session to have a command working in background

Screen


10.	Assigning Taxonomy

##Asssinging the taxonomy
##withoug training the database 
qiime feature-classifier classify-consensus-vsearch \
  --i-query COI-rep-seqs.qza \
  --i-reference-reads /Databases/DataBase_Amplicon/MIDORI260/MIDORI2_LONGEST_NUC_GB260_CO1_QIIME_Seq.qza  \
  --i-reference-taxonomy /Databases/DataBase_Amplicon/MIDORI260/MIDORI2_LONGEST_NUC_GB260_CO1_QIIME_taxa.qza \
  --p-threads 50 \
  --o-classification COI-rep-seqs-vsearch_taxonomy_midori260.qza \
  --output-dir ./vsearch2  \
  --verbose 

##without training the database 
qiime feature-classifier classify-consensus-vsearch \
  --i-query COI-rep-seqs.qza \
  --i-reference-reads /data/rusa/DataBase/COI_2020/bold_derep1_seqs.qza  \
  --i-reference-taxonomy /data/rusa/DataBase/COI_2020/bold_derep1_taxa.qza \
  --p-threads 20 \
  --o-classification COI-rep-seqs-vsearch_taxonomy_bold.qza \
  --verbose 
##

11.	Detach the screen to run in background

#detaching the screen option 
Ctrl-a and then d

12.	Visualizing Taxonomy Output

##visualizing taxonomy output
qiime metadata tabulate \
  --m-input-file COI-rep-seqs-vsearch_taxonomy_midori260.qza \
  --o-visualization COI-rep-seqs-taxonomy_midori260.qzv

•	qiime metadata tabulate: Converts the taxonomy classification results to a visualization (COI-rep-seqs-taxonomy_midori260.qzv).

13.	Exporting Data for Analysis in R

##exporting data into R for plyseq
#table of otus
qiime tools export \
  --input-path  COI-table.qza \
  --output-path Dada2_midori260-output
  
#convert otus to text format
biom convert -i Dada2_midori260-output/feature-table.biom -o Dada2_midori260-output/otu_table.txt --to-tsv

# table of taxonomy
qiime tools export \
  --input-path COI-rep-seqs-vsearch_taxonomy_midori260.qza \
  --output-path Dada2_midori260-output

##using the recent bold database
qiime tools export \
  --input-path COI-rep-seqs-vsearch_taxonomy_bold.qza \
  --output-path Dada2-output

# sequences
qiime tools export \
  --input-path COI-rep-seqs.qza  \
  --output-path Dada2_midori260-output
#
biom summarize-table -i Dada2_midori260-output/feature-table.biom > Dada2_midori260-output/otu_summary.txt

•	qiime tools export: Exports the feature table, taxonomy classifications, and representative sequences to a directory (Dada2_midori260-output).
•	biom convert: Converts the feature table from .biom format to a text format (otu_table.txt) for further analysis in R.
•	biom summarize-table: Summarizes the feature table and outputs the summary to otu_summary.txt.

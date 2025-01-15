#!/bin/bash
# This is metabarcoding data processing script


# Set working directory

cd /mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/fastq

# list all fasta files and count them
ls *.fastq.gz | wc -l

# Activating qiime

conda activate qiime2-2023.5

# Creating a Manifest File

echo "sample-id,absolute-filepath,direction" > ../bioinfo/manifest.csv
for i in *_R1_* ; do echo "${i/_R1_001.fastq.gz},$PWD/$i,forward"; done >> ../bioinfo/manifest.csv
for i in *_R2_* ; do echo "${i/_R2_001.fastq.gz},$PWD/$i,reverse"; done >> ../bioinfo/manifest.csv

# echo "sample-id,absolute-filepath,direction" > manifest.csv: Creates a CSV file (manifest.csv) with a header line that includes the columns sample-id, absolute-filepath, and direction.
# for i in *_R1_*; do ... done >> manifest.csv: Loops through all files that contain _R1_ (forward reads) in their names, extracts the sample ID by removing _R1_001.fastq.gz, and appends the line with sample ID, file path, and direction (forward) to the manifest.csv.
# for i in *_R2_*; do ... done >> manifest.csv: Loops through all files that contain _R2_ (reverse reads) and appends the sample ID, file path, and direction (reverse) to the manifest.csv.

# Importing Data into QIIME 2

qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path manifest.csv \
  --output-path paired-end-demux.qza \
  --input-format PairedEndFastqManifestPhred33

# qiime tools import: Imports the paired-end sequence data described in manifest.csv into a QIIME 2 artifact (paired-end-demux.qza), specifying that the data is paired-end sequences with quality scores.

5.	Checking the Quality of the Sequencing Run

##checking the quality of run 
qiime demux summarize \
  --i-data paired-end-demux.qza \
  --o-visualization paired-end-demux.qzv

•	qiime demux summarize: Generates a summary visualization of the demultiplexed data (paired-end-demux.qza) and saves it as paired-end-demux.qzv.








6.	Denoising with DADA2

###joining pairends
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs paired-end-demux.qza \
  --p-trim-left-f 26\
  --p-trim-left-r 26 \
  --p-trunc-len-f 230 \
  --p-trunc-len-r 210 \
  --p-n-threads 40 \
  --o-table COI-table.qza \
  --o-representative-sequences COI-rep-seqs.qza \
  --o-denoising-stats COI-denoising-stats.qza \
  --verbose

•	qiime dada2 denoise-paired: Denoises the paired-end sequences using DADA2, trimming and truncating sequences as specified by the parameters. It outputs:
•	COI-table.qza: Feature table of observed features.
•	COI-rep-seqs.qza: Representative sequences.
•	COI-denoising-stats.qza: Denoising statistics.

7.	Visualizing Denoising Stats

qiime metadata tabulate \
  --m-input-file COI-denoising-stats.qza \
  --o-visualization COI-denoising-stats.qzv

qiime feature-table tabulate-seqs \
  --i-data COI-rep-seqs.qza \
  --o-visualization COI-rep-seqs.qzv

•	qiime metadata tabulate: Converts the denoising stats to a visualization (COI-denoising-stats.qzv).
•	qiime feature-table tabulate-seqs: Converts the representative sequences to a visualization (COI-rep-seqs.qzv).

8.	Start a screen session to have a command working in background

Screen

9.	 Open qiime and activate it

open qiime 
conda activate qiime2-2023.5

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

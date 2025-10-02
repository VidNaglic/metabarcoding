# 1. Convert BIOM to TSV
biom convert \
  -i "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/feature-table.biom" \
  -o "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/feature-table.tsv" \
  --to-tsv --table-type="OTU table"

# 2. Extract OTU IDs
cut -f1 "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/feature-table.tsv" | tail -n +2 > "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/filtered-otu-ids.txt"

# 3. Filter sequences
seqkit grep -f "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/filtered-otu-ids.txt" \
  "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/dna-sequences-all.fasta" \
  > "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/dna-sequences-validated.fasta"

echo "✅ Filtered FASTA ready: dna-sequences-validated.fasta"

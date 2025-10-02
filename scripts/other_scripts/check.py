import pandas as pd

# Load both tables
coi = pd.read_csv("/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/feature-table.tsv",
                  sep="\t", skiprows=1, index_col=0)
bold = pd.read_csv("/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-rep-seqs/dna-sequences-validated_full_results.csv",
                   index_col=0)

# Check intersection
shared = set(coi.index).intersection(bold.index)
print(f"🧬 Feature IDs in QIIME table: {len(coi):,}")
print(f"🔍 Feature IDs in BOLDigger table: {len(bold):,}")
print(f"✅ Shared Feature IDs: {len(shared):,}")

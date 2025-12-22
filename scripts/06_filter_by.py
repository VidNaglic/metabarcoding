#!/usr/bin/env python3
import pandas as pd
import os

# ─── CONFIG ────────────────────────────────────────────────────────────────
input_csv  = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/processed_data/04_arthropoda_renamed_samples.csv"
output_dir = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/processed_data/filtered_output"
os.makedirs(output_dir, exist_ok=True)

output_excel  = os.path.join(output_dir, "filtered_ASV_table.xlsx")
summary_txt   = os.path.join(output_dir, "filtering_summary.txt")

# Filtering thresholds (balanced for R1-only Leray on NextSeq 2×150)
remove_singletons      = True    # drop ASVs seen in only one sample
min_total_abundance    = 5       # require at least 5 total reads
min_relative_abundance = 0.000001  # global relative abundance cutoff
min_sample_reads       = 100
min_richness           = 2       # ASV must appear in ≥2 samples

# ─── LOAD DATA ─────────────────────────────────────────────────────────────
df = pd.read_csv(input_csv)

# Identify numeric sample columns (everything before 'phylum_x')
first_tax_col = df.columns.get_loc("phylum_x")
sample_cols = df.columns[:first_tax_col]
tax_cols = df.columns[first_tax_col:]

# Split sample counts and taxonomic/meta data
asv_table = df[sample_cols].copy()
tax_table = df[tax_cols].copy()

# Track unique taxonomy assignments before filtering
tax_ranks = ["species_x", "genus_x", "family_x"]
unique_before = {rank: tax_table[rank].dropna().nunique() if rank in tax_table else 0 for rank in tax_ranks}

# Store initial shapes
initial_asvs = asv_table.shape[0]
initial_samples = asv_table.shape[1]

# ─── FILTERING STEPS ───────────────────────────────────────────────────────
summary = []

# 1. Remove singletons (ASVs present in ≤1 sample)
if remove_singletons:
    mask = (asv_table > 0).sum(axis=1) > 1
    removed = (~mask).sum()
    asv_table = asv_table[mask]
    tax_table = tax_table[mask]
    summary.append(f"Removed {removed} singleton ASVs")

# 2. Remove ASVs with total abundance < min_total_abundance
mask = asv_table.sum(axis=1) >= min_total_abundance
removed = (~mask).sum()
asv_table = asv_table[mask]
tax_table = tax_table[mask]
summary.append(f"Removed {removed} ASVs with total abundance < {min_total_abundance}")

# 3. Remove ASVs with low relative abundance
total_reads = asv_table.sum().sum()
rel_abundance = asv_table.sum(axis=1) / total_reads
mask = rel_abundance >= min_relative_abundance
removed = (~mask).sum()
asv_table = asv_table[mask]
tax_table = tax_table[mask]
summary.append(f"Removed {removed} ASVs with relative abundance < {min_relative_abundance}")

# 4. Remove samples with < min_sample_reads
sample_reads = asv_table.sum(axis=0)
samples_to_keep = sample_reads[sample_reads >= min_sample_reads].index
removed_samples = set(asv_table.columns) - set(samples_to_keep)
asv_table = asv_table[samples_to_keep]
summary.append(f"Removed {len(removed_samples)} samples with < {min_sample_reads} reads")
if removed_samples:
    summary.append("Samples removed: " + ", ".join(sorted(removed_samples)))

# 5. Remove ASVs with richness < min_richness (i.e., ASVs present in <X remaining samples)
mask = (asv_table > 0).sum(axis=1) >= min_richness
removed = (~mask).sum()
asv_table = asv_table[mask]
tax_table = tax_table[mask]
summary.append(f"Removed {removed} ASVs with richness < {min_richness}")

# ─── OUTPUT ────────────────────────────────────────────────────────────────
filtered = pd.concat([asv_table, tax_table], axis=1)

# Track unique taxonomy assignments after filtering
unique_after = {rank: tax_table[rank].dropna().nunique() if rank in tax_table else 0 for rank in tax_ranks}

filtered.to_excel(output_excel, index=False)

with open(summary_txt, "w") as f:
    f.write("=== FILTERING SUMMARY ===\n")
    f.write(f"Initial ASVs: {initial_asvs}\n")
    f.write(f"Initial Samples: {initial_samples}\n")
    f.write(f"Final ASVs: {asv_table.shape[0]}\n")
    f.write(f"Final Samples: {asv_table.shape[1]}\n\n")
    for line in summary:
        f.write(f"{line}\n")
    f.write("\n--- Taxonomy assignments ---\n")
    for rank in tax_ranks:
        f.write(f"{rank.replace('_x','').title()} unique before: {unique_before[rank]}\n")
        f.write(f"{rank.replace('_x','').title()} unique after : {unique_after[rank]}\n")

print("✅ Filtering complete.")
print(f"→ Output table: {output_excel}")
print(f"→ Summary:      {summary_txt}")

#!/usr/bin/env python3
import pandas as pd
import os
import re

# ─── CONFIG ────────────────────────────────────────────────────────────────
input_file  = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/joined_coi_bold_results.csv"
output_dir  = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/processed_data/"
os.makedirs(output_dir, exist_ok=True)

chunk_size  = 100_000

# Output paths
output_cleaned_table     = os.path.join(output_dir, "01_cleaned_taxa_filtered.csv")
output_arthropoda_table  = os.path.join(output_dir, "02_arthropoda_only.csv")
output_filtered_identity = os.path.join(output_dir, "03_arthropoda_identity_filtered.csv")
output_renamed_table     = os.path.join(output_dir, "04_arthropoda_renamed_samples.csv")
output_summary           = os.path.join(output_dir, "summary_stats.txt")

# remove any existing outputs so we don't append to stale data
for f in [output_cleaned_table, output_arthropoda_table,
          output_filtered_identity, output_renamed_table,
          output_summary]:
    if os.path.exists(f):
        os.remove(f)

# Taxonomic column mapping
tax_cols = {
    "Species": "species_x",
    "Genus": "genus_x",
    "Family": "family_x",
    "Order": "order_x",
    "Class": "class_x",
    "Phylum": "phylum_x",
}

# identity thresholds (below threshold → demoted to NA)
thresholds = {
    "species_x": 97.0,
    "genus_x":   95.0,
    "family_x":  90.0,
    "order_x":   85.0,
    "class_x":   80.0,
}

# strings that should be treated as missing taxonomy
to_null = {"no-match", "IncompleteTaxonomy", "IncompleteTaxnonmy"}

# sample renaming map
sample_mapping = {
    "KIS0001": "suh_a/1",  "KIS0002": "suh_a/2",  "KIS0003": "suh_a/3",
    "KIS0004": "suh_b/1",  "KIS0005": "suh_b/2",  "KIS0006": "suh_b/3",
    "KIS0007": "suh_d/1",  "KIS0008": "suh_d/2",  "KIS0009": "suh_d/3",
    "KIS0010": "brk_a/1",  "KIS0011": "brk_a/2",  "KIS0012": "brk_a/3",
    "KIS0013": "brk_b/1",  "KIS0014": "brk_b/2",  "KIS0015": "brk_b/3",
    "KIS0016": "brk_c/1",  "KIS0017": "brk_c/2",  "KIS0018": "brk_c/3",
    "KIS0019": "brk_d/1",  "KIS0020": "brk_d/2",  "KIS0021": "brk_d/3",
    "KIS0022": "kan_b/1",  "KIS0023": "kan_b/2",  "KIS0024": "kan_b/3",
    "KIS0025": "kan_b/1/20", "KIS0026": "kan_b/2/20", "KIS0027": "kan_b/3/20",
    "KIS0028": "kan_c/1",  "KIS0029": "kan_c/2",  "KIS0030": "kan_c/3",
    "KIS0031": "kan_d/1",  "KIS0032": "kan_d/2",  "KIS0033": "kan_d/3",
    "KIS0034": "koz_a/1",  "KIS0035": "koz_a/2",  "KIS0036": "koz_a/3",
    "KIS0037": "koz_b/1",  "KIS0038": "koz_b/2",  "KIS0039": "koz_b/3",
    "KIS0040": "koz_c/1",  "KIS0041": "koz_c/2",  "KIS0042": "koz_c/3",
    "KIS0043": "koz_d/1",  "KIS0044": "koz_d/2",  "KIS0045": "koz_d/3",
    "KIS0046": "boh_a/1",  "KIS0047": "boh_a/2",  "KIS0048": "boh_a/3",
    "KIS0049": "boh_b/1",  "KIS0050": "boh_b/2",  "KIS0051": "boh_b/3",
    "KIS0052": "boh_c/1",  "KIS0053": "boh_c/2",  "KIS0054": "boh_c/3",
    "KIS0055": "boh_d/1",  "KIS0056": "boh_d/2",  "KIS0057": "boh_d/3",
    "KIS0058": "rak_a/1",  "KIS0059": "rak_a/2",  "KIS0060": "rak_a/3",
    "KIS0061": "rak_b/1",  "KIS0062": "rak_b/2",  "KIS0063": "rak_b/3",
    "KIS0064": "rak_c/1",  "KIS0065": "rak_c/2",  "KIS0066": "rak_c/3",
    "KIS0067": "rak_d/1",  "KIS0068": "rak_d/2",  "KIS0069": "rak_d/3",
}

# Counters for summary
total_otus      = 0
matched_species = 0
matched_higher  = 0
unmatched       = 0
tax_level_counts = {k: set() for k in tax_cols}  # Species, Genus, etc.

print("🔄 Processing in chunks…")
for i, chunk in enumerate(pd.read_csv(input_file, chunksize=chunk_size)):
    print(f"🧩 Chunk {i + 1}")

    # drop duplicate tax columns that end with "_y" but always keep pct_identity_x
    cols_to_keep = [
        c for c in chunk.columns
        if not c.endswith("_y") or c.startswith("pct_identity")
    ]
    chunk = chunk.loc[:, cols_to_keep].copy()

    # replace "no-match", "IncompleteTaxonomy" etc. with NA
    for col in tax_cols.values():
        if col in chunk.columns:
            chunk[col] = chunk[col].replace(list(to_null), pd.NA)

    # update counts for summary
    total_otus      += len(chunk)
    matched_species += chunk[tax_cols["Species"]].notna().sum()
    # matched_higher: at least genus_x…phylum_x is present (i.e. index 1 onward)
    present_any     = chunk[[tax_cols[k] for k in ("Genus", "Family", "Order", "Class", "Phylum")]].notna().any(axis=1)
    matched_higher  += present_any.sum()
    unmatched       += len(chunk) - present_any.sum()

    # keep only rows where genus_x…phylum_x have at least one non‑NA
    cleaned = chunk[present_any].copy()
    cleaned.to_csv(output_cleaned_table, mode='a', index=False,
                   header=not os.path.exists(output_cleaned_table))

    # filter Arthropoda
    arth = cleaned[cleaned[tax_cols["Phylum"]] == "Arthropoda"].copy()
    if arth.empty:
        continue

    # demote by identity threshold
    for tcol in ["species_x", "genus_x", "family_x", "order_x", "class_x"]:
        if tcol in arth.columns:
            arth.loc[arth["pct_identity_x"] < thresholds[tcol], tcol] = pd.NA

    arth.to_csv(output_arthropoda_table, mode='a', index=False,
                header=not os.path.exists(output_arthropoda_table))
    arth.to_csv(output_filtered_identity, mode='a', index=False,
                header=not os.path.exists(output_filtered_identity))

    # rename sample columns according to KIS→site mapping
    sample_cols = [c for c in arth.columns if re.match(r"KIS\d{4}", c)]
    rename_map  = {
        col: sample_mapping.get(re.match(r"(KIS\d{4})", col).group(1), col)
        for col in sample_cols
    }
    arth = arth.rename(columns=rename_map)
    arth.to_csv(output_renamed_table, mode='a', index=False,
                header=not os.path.exists(output_renamed_table))

    # update sets of unique taxa
    for level, col in tax_cols.items():
        if col in arth.columns:
            tax_level_counts[level].update(arth[col].dropna().unique())

# write summary file after all chunks are processed
with open(output_summary, "w") as f:
    f.write("--- Summary (before filtering) ---\n")
    f.write(f"Total OTUs: {total_otus}\n")
    f.write(f"Matched species: {matched_species}\n")
    f.write(f"Matched genus+ : {matched_higher}\n")
    f.write(f"Unmatched OTUs: {unmatched}\n\n")
    f.write("--- Arthropoda (after demotion + renaming) ---\n")
    for level in ["Species", "Genus", "Family", "Order", "Class"]:
        f.write(f"Unique {level.lower()}s: {len(tax_level_counts[level])}\n")

print("✅ Done with chunked processing.")

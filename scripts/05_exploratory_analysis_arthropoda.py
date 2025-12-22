#!/usr/bin/env python3
import pandas as pd
import os
import re

# ─── CONFIG ────────────────────────────────────────────────────────────────
input_file  = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/joined_coi_bold_results.csv"
output_dir  = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/processed_data/"
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

# sample renaming map (from metadata IDs)
sample_mapping = {
    "KIS_0069": "B1_A",
    "KIS_0070": "B1_C",
    "KIS_0071": "B1_F",
    "KIS_0072": "B1_ART",
    "KIS_0073": "B1_RT",
    "KIS_0074": "B2_A",
    "KIS_0075": "B2_C",
    "KIS_0076": "B2_F",
    "KIS_0077": "B2_ART",
    "KIS_0078": "B2_RT",
    "KIS_0079": "B3_A",
    "KIS_0080": "B3_C",
    "KIS_0081": "B3_F",
    "KIS_0082": "B3_ART",
    "KIS_0083": "B3_RT",
    "KIS_0084": "B4_A",
    "KIS_0085": "B4_C",
    "KIS_0086": "B4_F",
    "KIS_0087": "B4_ART",
    "KIS_0088": "B4_RT",
    "KIS_0089": "Skov_1A",
    "KIS_0090": "Skov_1B",
    "KIS_0091": "Skov_2A",
    "KIS_0092": "Skov_3A",
}
# allow lookups with or without underscore
sample_mapping = {k: v for k, v in sample_mapping.items()} | {k.replace("_", ""): v for k, v in sample_mapping.items()}

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
    sample_cols = [c for c in arth.columns if re.match(r"KIS_?\d{4}", c)]
    rename_map  = {}
    for col in sample_cols:
        m = re.match(r"(KIS_?\d{4})", col)
        if not m:
            continue
        code = m.group(1)
        rename_map[col] = sample_mapping.get(code, sample_mapping.get(code.replace("_", ""), col))
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

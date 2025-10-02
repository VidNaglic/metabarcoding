#!/usr/bin/env python3
import os
import subprocess
import pandas as pd

# ─── USER CONFIG ────────────────────────────────────────────────────────────────
coi_qza_path      = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/COI-table.qza"
biom_path         = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/feature-table.biom"
coi_table_path    = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/feature-table.tsv"

# BOLDigger result: large file → use CSV
bold_results_xlsx = (
    "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/"
    "bioinfo/exported-rep-seqs/"
    "dna-sequences-validated_full_results.xlsx"
)
bold_results_csv = bold_results_xlsx.replace(".xlsx", ".csv")

parquet_path      = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/joined_coi_bold_results.parquet"
excel_path        = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/joined_coi_bold_results.xlsx"
# ────────────────────────────────────────────────────────────────────────────────

# 1) Export COI table if needed
if not os.path.exists(coi_table_path):
    print("⚠️  feature-table.tsv not found. Exporting & converting COI-table.qza…")
    try:
        subprocess.run(
            ["qiime", "tools", "export",
             "--input-path", coi_qza_path,
             "--output-path", os.path.dirname(biom_path)],
            check=True
        )
        subprocess.run(
            ["biom", "convert",
             "-i", biom_path,
             "-o", coi_table_path,
             "--to-tsv", "--table-type=OTU table"],
            check=True
        )
        print("✅ feature-table.tsv successfully generated!")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error generating feature-table.tsv: {e}")
        exit(1)

# 2) Load COI table
try:
    print("🔍  Loading COI feature table…")
    coi_table = pd.read_csv(coi_table_path, sep="\t", skiprows=1, index_col=0)
    print("✅ COI table loaded.")
except Exception as e:
    print(f"❌ Failed to load COI table: {e}")
    exit(1)

# 3) Load BOLDigger results (try Excel, fallback to CSV)
try:
    print(f"🔍  Loading BOLDigger results from Excel:\n    {bold_results_xlsx}")
    bold_results = pd.read_excel(bold_results_xlsx, index_col=0)
except Exception as e:
    print(f"⚠️  Excel load failed: {e}. Trying CSV instead:\n    {bold_results_csv}")
    try:
        bold_results = pd.read_csv(bold_results_csv, index_col=0)
    except Exception as e_csv:
        print(f"❌ Failed to load BOLDigger results from both Excel and CSV: {e_csv}")
        exit(1)

# Drop duplicated *_y columns if present
bold_results = bold_results[[col for col in bold_results.columns if not col.endswith('_y')]]

bold_results.index.name = "Feature ID"
print("✅ BOLDigger results loaded.")

# 4) Merge
print("🔗  Merging COI ↔ BOLDigger on Feature ID…")
merged = coi_table.join(bold_results, how="inner")
if merged.shape[0] == 0:
    raise ValueError("No matching Feature IDs found between the two tables!")

print(f"✅ Merged table shape: {merged.shape}")

# 5) Save Parquet
print(f"💾  Saving joined table to Parquet:\n    {parquet_path}")
merged.to_parquet(parquet_path, index=True)
print("✅ Parquet written!")

# 6) Save Excel (try, may fail if too big)
try:
    print(f"💾  Attempting Excel export to:\n    {excel_path}")
    merged.to_excel(excel_path, index=True)
    print("✅ Excel written!")
except Exception as e:
    print(f"⚠️ Excel export failed, but Parquet is safe: {e}")

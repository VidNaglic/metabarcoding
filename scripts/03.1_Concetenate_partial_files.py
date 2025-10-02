#!/usr/bin/env python3
import pandas as pd
import glob
import sys
import os

# ─── USER CONFIG ────────────────────────────────────────────────────────────────
bold_folder = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/boldigger3_data"

out_parts_all_xlsx = f"{bold_folder}/dna-sequences-validated_bold_results_all.xlsx"
out_parts_all_csv  = out_parts_all_xlsx.replace(".xlsx", ".csv")

parquet_id = f"{bold_folder}/dna-sequences-validated_identification_result.parquet.snappy"
out_id_xlsx = f"{bold_folder}/dna-sequences-validated_identification_result.xlsx"

out_final_xlsx = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-rep-seqs/dna-sequences-validated_full_results.xlsx"
out_final_csv  = out_final_xlsx.replace(".xlsx", ".csv")
# ────────────────────────────────────────────────────────────────────────────────

# 1) Merge all the bold_results parts
print("🔍 1) Merging batch‐wise bold_results…")
parts = glob.glob(f"{bold_folder}/*_bold_results_part_*.xlsx")
if not parts:
    print("❌ No bold_results parts found! Check your path.")
    sys.exit(1)
df_parts = pd.concat((pd.read_excel(p) for p in parts), ignore_index=True)
df_parts.to_csv(out_parts_all_csv, index=False)
print(f"✅ All {len(parts)} parts merged → {out_parts_all_csv}")

# 2) Load the identification‐engine Parquet and also dump it as Excel
print("🔍 2) Loading identification result (Parquet)…")
try:
    df_id = pd.read_parquet(parquet_id)
except Exception as e:
    print("❌ Could not read Parquet:", e)
    sys.exit(1)
df_id.to_excel(out_id_xlsx, index=False)
print(f"✅ Identification table written as Excel → {out_id_xlsx}")

# 3) Auto‐detect join key and merge
print("🔍 3) Inspecting columns…")
print(" • parts columns:", df_parts.columns.tolist())
print(" • id table columns:", df_id.columns.tolist())

if "fasta_order" in df_parts.columns and "fasta_order" in df_id.columns:
    key = "fasta_order"
elif "id" in df_parts.columns and "id" in df_id.columns:
    key = "id"
else:
    print("❌ No common key to merge on (need 'fasta_order' or 'id').")
    sys.exit(1)

print(f"🔗 4) Joining on '{key}'…")
df_full = df_parts.merge(df_id, on=key, how="left")
df_full.to_csv(out_final_csv, index=False)
print(f"✅ Full merged table saved → {out_final_csv}")

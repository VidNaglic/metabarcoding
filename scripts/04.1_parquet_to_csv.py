#!/usr/bin/env python3
import pyarrow.parquet as pq
import csv

# ─── CONFIG ─────────────────────────────────────────────────────────
parquet_path = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/joined_coi_bold_results.parquet"
csv_path     = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_forest_PHK/bioinfo/joined_coi_bold_results.csv"
batch_size   = 5_000  # adjust depending on memory
# ────────────────────────────────────────────────────────────────────

# 1) Open Parquet file
pf = pq.ParquetFile(parquet_path)

# 2) Write CSV in batches
with open(csv_path, "w", newline='', encoding="utf-8") as f:
    writer = None
    for batch in pf.iter_batches(batch_size=batch_size):
        df = batch.to_pandas()
        if writer is None:
            writer = csv.DictWriter(f, fieldnames=df.columns)
            writer.writeheader()
        for row in df.to_dict(orient="records"):
            writer.writerow(row)

print(f"✅ CSV export complete → {csv_path}")

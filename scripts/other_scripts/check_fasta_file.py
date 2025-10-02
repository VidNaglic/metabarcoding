import pandas as pd

path = "/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-rep-seqs/dna-sequences-validated_full_results.csv"
df = pd.read_csv(path, index_col=0, low_memory=False)

print(f"🔍 Table shape: {df.shape}")

# Show first few column names
print("\n📋 First few columns:")
print(df.columns[:10].tolist())

# Detect taxonomy columns with suffixes
key_cols = ['phylum', 'class', 'order', 'family', 'genus', 'species', 'pct_identity']
for base in key_cols:
    x = base + "_x"
    y = base + "_y"
    present = [c for c in [x, y, base] if c in df.columns]
    print(f" • {base:15}: {'✅ ' + present[0] if present else '❌ MISSING'}")

# Count non-NA species
for col in ["species_x", "species_y"]:
    if col in df.columns:
        count = df[col].notna().sum()
        print(f"\n🧬 Non-NA species assignments in '{col}': {count:,}")
        break

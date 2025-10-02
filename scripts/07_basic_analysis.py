#!/usr/bin/env python3
"""
Run a full metabarcoding analysis across **all** ASVs in a filtered count table.

This script is a corrected version of the original `run_full_metabarcoding_analysis.py`.  The
major changes address the issue where metadata columns (e.g., latitude/longitude,
country, BIN codes, etc.) were being interpreted as sample read counts.  To
prevent this, the script now uses both an explicit list of known metadata
columns and a regular expression to identify legitimate sample columns.  Only
columns matching the sample naming pattern (e.g. `suh_a/1`, `kan_b/3/20`) and
not in the metadata list are treated as samples.

Features:
  * Computes per‑sample alpha diversity metrics (library size, observed ASVs,
    Shannon index, Pielou evenness) on all ASV rows.
  * Counts unique species, genera and families across all samples.
  * Aggregates read counts by order and genus, then computes relative
    composition per sample and per site.
  * Performs non‑metric multidimensional scaling (NMDS) on genus‑level
    Bray–Curtis distances when scipy and sklearn are available; otherwise
    gracefully skips.
  * Writes results to an Excel workbook with multiple sheets, along with
    several PNG figures and a summary JSON file.  The Excel writer uses
    openpyxl by default, removing any dependency on XlsxWriter.

Usage:
    python run_full_metabarcoding_analysis_corrected.py \
        --input filtered_ASV_table.xlsx \
        --outdir results_full

Dependencies:
    - openpyxl, pandas, numpy, matplotlib
    - Optionally scipy and scikit‑learn for NMDS

Author: OpenAI's ChatGPT (corrected version)
"""
import argparse
import sys  # Needed for printing progress to stderr
import json
import math
import os
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from openpyxl import load_workbook


def pick_tax_col(col_idx, base):
    """Return the first matching taxonomy column name for a given base rank.

    Some tables may use variants like `order_x`, `order_y`.  This helper
    checks for the presence of such columns in priority order.
    """
    for cand in (f"{base}_x", base, f"{base}_y"):
        if cand in col_idx:
            return cand
    return None


def parse_sample_name(name: str) -> dict:
    """Parse a sample identifier into site, plot, replicate and depth.

    A sample name is expected to look like `site_plot/rep` (e.g., `kan_a/3`) or
    possibly `site_plot/rep/20` when indicating a deeper (10–20 cm) soil layer.
    Depth is flagged as `10-20` if the name contains `10-20`, `20cm`,
    `bottom`, `deep` or `bott` (case insensitive), otherwise it defaults to
    `0-10`.  Missing fields are set to empty strings.
    """
    s = str(name)
    site = plot = rep = ""
    depth = "0-10"
    lower = s.lower()
    if any(k in lower for k in ("10-20", "20cm", "bottom", "deep", "bott")):
        depth = "10-20"
    # Split on slash first
    if "/" in s:
        left, rep = s.split("/", 1)
        rep = rep.strip()
    else:
        left = s
    # Now split left part on underscore to get site/plot
    if "_" in left:
        site, plot = left.split("_", 1)
    else:
        site = left
        plot = ""
    return {"sample": s, "site": site, "plot": plot, "rep": rep, "depth": depth}


def determine_sample_columns(header: list) -> list:
    """Return a list of column names that correspond to samples.

    Sample columns are those that:
      1. Are not in a hard‑coded list of known metadata/taxonomy columns.
      2. Match a regular expression capturing the structure of your sample names
         (site code, underscore, plot letter(s), slash, replicate number, and
         optional depth indicator).  This helps exclude numeric metadata like
         latitude/longitude or counts such as `records`.

    If a column is numeric but does not match the regex, it will be ignored
    and a warning can be logged later if needed.
    """
    # Explicit metadata/taxonomy fields to exclude.  Adjust this list if your
    # data includes additional metadata columns.  Comparison is case
    # insensitive.
    metadata_cols = {
        # taxonomy columns and their duplicates
        "kingdom", "phylum", "class", "order", "family", "genus", "species",
        "kingdom_x", "phylum_x", "class_x", "order_x", "family_x", "genus_x", "species_x",
        "kingdom_y", "phylum_y", "class_y", "order_y", "family_y", "genus_y", "species_y",
        # sequence/identity metadata
        "pct_identity", "pct_identity_x", "pct_identity_y",
        "process_id", "bin_uri", "bin", "database", "request_date",
        "taxon_id", "sequence_id", "database_accession",
        # environmental or specimen metadata
        "lat", "latitude", "lon", "longitude", "country", "continent", "ocean",
        "life_stage", "sex", "status", "process", "operator", "identification_method", "marker_code",
        # BOLD/GBIF specific metadata
        "record_ratio", "records", "selected_level", "flags", "selected", "stage",
    }
    # Compile a regex that describes legitimate sample names.  This expects
    # something like `suh_a/1`, `brk_b/2/20` or `kan_c/3`.  The site part may
    # have 2–3 letters (case insensitive), the plot part can have one or more
    # letters, and the replicate part is one or more digits with an optional
    # depth indicator separated by `/` or `-`.
    sample_regex = re.compile(r"^[A-Za-z]{2,3}_[A-Za-z]+/[0-9]+(?:[-/][0-9]+)?$", re.IGNORECASE)
    sample_cols = []
    for col in header:
        col_lower = str(col).lower()
        if col_lower in metadata_cols:
            continue
        # Accept only columns matching the sample naming pattern
        if sample_regex.match(str(col)):
            sample_cols.append(col)
        else:
            # Column does not look like a sample.  If it's numeric, it will be
            # ignored.  You could log or print a message here if desired.
            continue
    return sample_cols


def main(inp: str, outdir: str) -> None:
    """Perform the metabarcoding analysis and write outputs to `outdir`."""
    out_path = Path(outdir)
    out_path.mkdir(parents=True, exist_ok=True)

    # Load the workbook in read‑only streaming mode
    wb = load_workbook(inp, read_only=True, data_only=True)
    ws = wb.active
    header = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1))]
    col_idx = {name: i for i, name in enumerate(header)}

    # Determine taxonomy rank columns (some may be missing)
    tax_rank_cols = {rank: pick_tax_col(col_idx, rank) for rank in ["phylum", "class", "order", "family", "genus", "species"]}
    rank_indices = {rank: (col_idx[col] if col is not None else None) for rank, col in tax_rank_cols.items()}

    # Determine which columns are samples
    sample_cols = determine_sample_columns(header)
    sample_indices = [col_idx[c] for c in sample_cols]
    # Parse metadata from sample names
    meta_df = pd.DataFrame([parse_sample_name(c) for c in sample_cols])

    # Accumulators for alpha and composition statistics
    libsize = Counter()
    richness = Counter()
    sum_c_logc = Counter()
    species_sets: dict[str, set] = defaultdict(set)
    genus_sets: dict[str, set] = defaultdict(set)
    family_sets: dict[str, set] = defaultdict(set)
    agg_by_order: dict[str, Counter] = defaultdict(Counter)
    agg_by_genus: dict[str, Counter] = defaultdict(Counter)

    # Iterate through ASV rows one by one to reduce memory usage
    total_rows = ws.max_row
    processed = 0
    for row in ws.iter_rows(min_row=2, values_only=True):
        order_val = row[rank_indices["order"]] if rank_indices["order"] is not None else None
        family_val = row[rank_indices["family"]] if rank_indices["family"] is not None else None
        genus_val = row[rank_indices["genus"]] if rank_indices["genus"] is not None else None
        species_val = row[rank_indices["species"]] if rank_indices["species"] is not None else None
        for s_idx, sname in zip(sample_indices, sample_cols):
            val = row[s_idx]
            # Convert value to float if possible; missing or non‑numeric values count as zero
            if val is None or (isinstance(val, str) and not val.strip()):
                cnt = 0.0
            else:
                try:
                    cnt = float(val)
                except Exception:
                    cnt = 0.0
            if cnt > 0.0:
                libsize[sname] += cnt
                richness[sname] += 1
                sum_c_logc[sname] += cnt * math.log(cnt)
                # Taxa sets
                if species_val not in (None, "", "NA"):
                    species_sets[sname].add(str(species_val))
                if genus_val not in (None, "", "NA"):
                    genus_sets[sname].add(str(genus_val))
                    agg_by_genus[sname][str(genus_val)] += cnt
                if family_val not in (None, "", "NA"):
                    family_sets[sname].add(str(family_val))
                if order_val not in (None, "", "NA"):
                    agg_by_order[sname][str(order_val)] += cnt
        processed += 1
        if processed % 10000 == 0:
            print(f"Processed {processed} rows / ~{total_rows - 1} (ASVs).", file=sys.stderr)

    # Construct alpha diversity DataFrame
    samples = sample_cols
    library_sizes = pd.Series([libsize[s] for s in samples], index=samples, name="library_size")
    observed_asvs = pd.Series([richness[s] for s in samples], index=samples, name="observed_asvs")
    shannon_values = []
    for s in samples:
        N = libsize[s]
        if N > 0 and observed_asvs[s] > 0:
            H_i = math.log(N) - (sum_c_logc[s] / N)
        else:
            H_i = 0.0
        shannon_values.append(H_i)
    shannon = pd.Series(shannon_values, index=samples, name="shannon")
    # Pielou evenness: H / log(observed ASVs)
    evenness = pd.Series([
        (shannon[s] / math.log(observed_asvs[s])) if observed_asvs[s] > 1 else np.nan
        for s in samples
    ], index=samples, name="pielou_evenness")
    species_rich = pd.Series([len(species_sets[s]) for s in samples], index=samples, name="species_richness")
    genus_rich = pd.Series([len(genus_sets[s]) for s in samples], index=samples, name="genus_richness")
    family_rich = pd.Series([len(family_sets[s]) for s in samples], index=samples, name="family_richness")
    alpha_df = pd.concat([
        library_sizes, observed_asvs, shannon, evenness, species_rich, genus_rich, family_rich
    ], axis=1).reset_index().rename(columns={"index": "sample"})
    alpha_annot = alpha_df.merge(meta_df, on="sample", how="left")

    # Overall counts of unique taxa across all samples
    overall_species = set().union(*species_sets.values()) if species_sets else set()
    overall_genera = set().union(*genus_sets.values()) if genus_sets else set()
    overall_families = set().union(*family_sets.values()) if family_sets else set()
    overall_counts = pd.DataFrame({
        "rank": ["species", "genus", "family"],
        "unique_taxa": [len(overall_species), len(overall_genera), len(overall_families)]
    })

    # Composition by order: relative abundances
    orders = sorted(set(k for s in agg_by_order.values() for k in s))
    comp_order = pd.DataFrame(0.0, index=samples, columns=orders)
    for s in samples:
        total = float(sum(agg_by_order[s].values()))
        if total > 0:
            for od, cnt in agg_by_order[s].items():
                comp_order.loc[s, od] = cnt / total
    comp_order = comp_order.reset_index().rename(columns={"index": "sample"})
    comp_order = comp_order.merge(meta_df, on="sample", how="left")

    # NMDS analysis at genus level (optional)
    try:
        from scipy.spatial.distance import pdist, squareform
        from sklearn.manifold import MDS
        genera = sorted(set(k for s in agg_by_genus.values() for k in s))
        # Only use samples with non‑zero library size
        samples_nonzero = [s for s in samples if libsize[s] > 0]
        gen_mat = np.zeros((len(samples_nonzero), len(genera)), dtype=float)
        for i, s in enumerate(samples_nonzero):
            total = float(sum(agg_by_genus[s].values()))
            if total > 0:
                for j, g in enumerate(genera):
                    gen_mat[i, j] = agg_by_genus[s].get(g, 0.0) / total
        if len(samples_nonzero) >= 2 and gen_mat.shape[1] > 0:
            bc = squareform(pdist(gen_mat, metric="braycurtis"))
            bc = np.nan_to_num(bc, nan=0.0, posinf=1.0, neginf=0.0)
            nmds = MDS(
                n_components=2,
                dissimilarity="precomputed",
                random_state=42,
                metric=False,
                max_iter=300,
                n_init=4,
            )
            coords = nmds.fit_transform(bc)
            stress = float(nmds.stress_)
            nmds_df = pd.DataFrame(coords, columns=["NMDS1", "NMDS2"])
            nmds_df["sample"] = samples_nonzero
            nmds_df = nmds_df.merge(meta_df, on="sample", how="left")
            nmds_df["stress"] = stress
        else:
            nmds_df = pd.DataFrame(columns=["NMDS1", "NMDS2", "sample", "site", "plot", "rep", "depth", "stress"])
    except Exception as e:
        print(f"NMDS skipped due to missing deps or error: {e}")
        nmds_df = pd.DataFrame(columns=["NMDS1", "NMDS2", "sample", "site", "plot", "rep", "depth", "stress"])

    # Write Excel workbook
    out_xlsx = out_path / "metabarcoding_basic_analysis_FULL.xlsx"
    with pd.ExcelWriter(out_xlsx, engine="openpyxl") as writer:
        meta_df.to_excel(writer, sheet_name="Sample_Metadata", index=False)
        alpha_annot.to_excel(writer, sheet_name="Alpha_Diversity", index=False)
        overall_counts.to_excel(writer, sheet_name="Overall_Taxa_Counts", index=False)
        comp_order.to_excel(writer, sheet_name="Composition_Order", index=False)
        nmds_df.to_excel(writer, sheet_name="NMDS_Genus", index=False)

    # Plot library sizes
    plt.figure(figsize=(max(8, len(alpha_df) * 0.2), 4))
    plt.bar(alpha_df["sample"], alpha_df["library_size"])
    plt.xticks(rotation=90)
    plt.ylabel("Reads per sample")
    plt.title("Library sizes (FULL)")
    plt.tight_layout()
    plt.savefig(out_path / "plot_library_sizes_FULL.png", dpi=180)
    plt.close()

    # ASV richness by site
    alpha_annot["site"] = alpha_annot["site"].fillna("NA")
    sites = sorted(alpha_annot["site"].unique())
    plt.figure(figsize=(max(8, len(sites) * 0.4), 4))
    data = [alpha_annot.loc[alpha_annot["site"] == s, "observed_asvs"].values for s in sites]
    plt.boxplot(data, labels=sites, showfliers=False)
    plt.ylabel("Observed ASVs")
    plt.title("ASV richness by site (FULL)")
    plt.tight_layout()
    plt.savefig(out_path / "plot_richness_by_site_FULL.png", dpi=180)
    plt.close()

    # Shannon index by site
    plt.figure(figsize=(max(8, len(sites) * 0.4), 4))
    data = [alpha_annot.loc[alpha_annot["site"] == s, "shannon"].values for s in sites]
    plt.boxplot(data, labels=sites, showfliers=False)
    plt.ylabel("Shannon (ln)")
    plt.title("Shannon index by site (FULL)")
    plt.tight_layout()
    plt.savefig(out_path / "plot_shannon_by_site_FULL.png", dpi=180)
    plt.close()

    # Composition by order: stacked bar of top 10 orders (others lumped as "Other")
    value_cols = [c for c in comp_order.columns if c not in {"sample", "site", "plot", "rep", "depth"}]
    long_order = comp_order.melt(id_vars=["sample", "site"], value_vars=value_cols, var_name="order", value_name="rel_abund")
    site_mean = long_order.groupby(["site", "order"], as_index=False)["rel_abund"].mean()
    top_orders = (
        site_mean.groupby("order")["rel_abund"].mean().sort_values(ascending=False).head(10).index.tolist()
    )
    site_mean["order_group"] = site_mean["order"].where(site_mean["order"].isin(top_orders), "Other")
    plot_df = site_mean.groupby(["site", "order_group"], as_index=False)["rel_abund"].sum()
    pivot = plot_df.pivot(index="site", columns="order_group", values="rel_abund").fillna(0.0)
    plt.figure(figsize=(max(8, len(pivot) * 0.5), 5))
    bottom = np.zeros(len(pivot))
    x = np.arange(len(pivot.index))
    for col in pivot.columns:
        plt.bar(x, pivot[col].values, bottom=bottom, label=col)
        bottom += pivot[col].values
    plt.xticks(x, pivot.index, rotation=0)
    plt.ylabel("Mean relative abundance")
    plt.title("Order‑level composition by site (Top 10, FULL)")
    plt.legend(bbox_to_anchor=(1.04, 1), loc="upper left")
    plt.tight_layout()
    plt.savefig(out_path / "plot_composition_by_site_order_FULL.png", dpi=180)
    plt.close()

    # NMDS plot, if available
    if not nmds_df.empty:
        plt.figure(figsize=(7, 6))
        for s in sorted(nmds_df["site"].dropna().unique()):
            sub = nmds_df[nmds_df["site"] == s]
            plt.scatter(sub["NMDS1"], sub["NMDS2"], label=s, alpha=0.8)
        plt.axhline(0, linestyle="--", linewidth=0.5)
        plt.axvline(0, linestyle="--", linewidth=0.5)
        stress_val = float(nmds_df["stress"].iloc[0]) if "stress" in nmds_df.columns else float("nan")
        plt.xlabel("NMDS1")
        plt.ylabel("NMDS2")
        plt.title(f"NMDS (genus Bray–Curtis, FULL), stress={stress_val:.2f}")
        plt.legend(bbox_to_anchor=(1.04, 1), loc="upper left")
        plt.tight_layout()
        plt.savefig(out_path / "plot_nmds_genus_FULL.png", dpi=180)
        plt.close()

    # Save a short summary JSON
    summary = {
        "n_samples_total": len(sample_cols),
        "n_samples_nonzero": int(sum(1 for s in sample_cols if libsize[s] > 0)),
        "n_asv_rows": total_rows - 1,
        "n_orders": int(len(set(k for s in agg_by_order.values() for k in s))),
        "n_genera": int(len(set(k for s in agg_by_genus.values() for k in s))),
    }
    (out_path / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("Done. Outputs written to:", out_path.resolve())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Perform metabarcoding analysis on an Excel ASV table.")
    parser.add_argument("--input", "-i", required=True, help="Path to filtered_ASV_table.xlsx")
    parser.add_argument("--outdir", "-o", default="results_full", help="Directory to write outputs")
    args = parser.parse_args()
    main(args.input, args.outdir)
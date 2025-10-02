#!/usr/bin/env bash
# NextSeq-aware metabarcoding pipeline for QIIME 2 (Casava import; no manifest)
# Publishes canonical outputs so your later scripts run unchanged.

set -euo pipefail
set -o errtrace
trap 'echo "❌ Failure at: $BASH_COMMAND (line $LINENO)" >&2' ERR

# ── USER TUNABLES (safe defaults for NextSeq 2×150 + Leray) ─────────────
TRUNC_LEN_R1="${TRUNC_LEN_R1:-145}"
MAX_EE_R1="${MAX_EE_R1:-2}"
PRIMER_F="${PRIMER_F:-GGWACWGGWTGAACWGTWTAYCCYCC}"   # mlCOIintF
PRIMER_R="${PRIMER_R:-TAIACYTCIGGRTGICCRAARAAYCA}"   # jgHCO2198
CUTADAPT_ERROR_RATE="${CUTADAPT_ERROR_RATE:-0.1}"
CUTADAPT_MIN_OVERLAP="${CUTADAPT_MIN_OVERLAP:-10}"

# ── CONFIG (your originals) ─────────────────────────────────────────────
DATA_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/fastq"
BIOINFO_ROOT="/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo"

RUNSTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${BIOINFO_ROOT}/run_${RUNSTAMP}"
EXPORT_DIR="${OUT_DIR}/exported"
LOG="${OUT_DIR}/nextseq_processing.log"

# Canonical targets for downstream scripts:
CANON_EXPORT_FILTERED="${BIOINFO_ROOT}/exported-filtered"     # dna-sequences-validated.fasta (+ boldigger3_data)
CANON_EXPORT_REP="${BIOINFO_ROOT}/exported-rep-seqs"          # merged BOLD results later
CANON_BIOINFO_FILES="${BIOINFO_ROOT}"                         # COI-table.qza, feature-table.biom/tsv

mkdir -p "$OUT_DIR" "$EXPORT_DIR" "$CANON_EXPORT_FILTERED" "$CANON_EXPORT_REP" "$CANON_BIOINFO_FILES"

# ── ENV / PRECHECKS ─────────────────────────────────────────────────────
echo "🌱 Preparing environment…"
if ! command -v qiime >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    conda activate qiime2-2023.5 || { echo "❌ Activate qiime2-2023.5 first"; exit 1; }
  else
    echo "❌ QIIME 2 not found and conda not available."; exit 1
  fi
fi
command -v biom >/dev/null 2>&1 || echo "ℹ️  'biom' not on PATH (export still tries)."
command -v seqkit >/dev/null 2>&1 || echo "ℹ️  'seqkit' not on PATH (rep-seq filtering will be a plain copy)."

# Log everything
exec > >(tee -a "$LOG") 2>&1
echo "🏁 Run: $RUNSTAMP"
echo "📁 FASTQs:   $DATA_DIR"
echo "📁 OUT_DIR:  $OUT_DIR"
echo "📁 EXPORT:   $EXPORT_DIR"
echo "🧪 DADA2 single-end R1 with trunc-len=${TRUNC_LEN_R1}, maxEE=${MAX_EE_R1}"
echo

# ── 0) VERIFY FILES & PAIRS ────────────────────────────────────────────
echo "📄 Listing FASTQs:"
shopt -s nullglob
r1s=( "$DATA_DIR"/*_R1_001.fastq.gz )
r2s=( "$DATA_DIR"/*_R2_001.fastq.gz )
(( ${#r1s[@]} > 0 )) || { echo "❌ No R1 files found in $DATA_DIR"; exit 1; }
(( ${#r2s[@]} > 0 )) || { echo "❌ No R2 files found in $DATA_DIR"; exit 1; }

missing=0
for r1 in "${r1s[@]}"; do
  r2="${r1/_R1_/_R2_}"
  [[ -f "$r2" ]] || { echo "⚠️  Missing R2 for: $r1"; missing=1; }
done
(( missing == 0 )) || { echo "❌ Fix missing pairs and re-run."; exit 1; }
echo "📊 R1 count: ${#r1s[@]} | R2 count: ${#r2s[@]} (pairs OK)"

# ── 1) IMPORT WITH CASAVA FORMAT (no manifest) ─────────────────────────
if [[ ! -f "$OUT_DIR/paired-end-demux.qza" ]]; then
  echo "📥 Importing reads via CasavaOneEightSingleLanePerSampleDirFmt…"
  echo "ℹ️  Casava sets sample IDs to the text before '_S…' (e.g., KIS0001)"
  qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "$DATA_DIR" \
    --input-format CasavaOneEightSingleLanePerSampleDirFmt \
    --output-path "$OUT_DIR/paired-end-demux.qza"
else
  echo "⏩ Skipping import (found paired-end-demux.qza)"
fi

# ── 2) DEMUX SUMMARY (QZV) ─────────────────────────────────────────────
if [[ ! -f "$OUT_DIR/paired-end-demux.qzv" ]]; then
  echo "📊 Generating demux summary (QZV)…"
  qiime demux summarize \
    --i-data "$OUT_DIR/paired-end-demux.qza" \
    --o-visualization "$OUT_DIR/paired-end-demux.qzv"
  echo "🔗 View: $OUT_DIR/paired-end-demux.qzv (https://view.qiime2.org)"
else
  echo "⏩ Skipping demux summary (found paired-end-demux.qzv)"
fi

# ── 3) PRIMER/ADAPTER REMOVAL (Cutadapt, paired) ───────────────────────
if [[ ! -f "$OUT_DIR/trimmed-paired.qza" ]]; then
  echo "✂️  Removing Leray primers with cutadapt (paired)…"
  qiime cutadapt trim-paired \
    --i-demultiplexed-sequences "$OUT_DIR/paired-end-demux.qza" \
    --p-front-f "$PRIMER_F" \
    --p-front-r "$PRIMER_R" \
    --p-error-rate "$CUTADAPT_ERROR_RATE" \
    --p-overlap "$CUTADAPT_MIN_OVERLAP" \
    --p-match-read-wildcards \
    --o-trimmed-sequences "$OUT_DIR/trimmed-paired.qza" \
    --verbose
else
  echo "⏩ Skipping cutadapt (found trimmed-paired.qza)"
fi

# Optional summary after trimming
if [[ ! -f "$OUT_DIR/trimmed-paired.qzv" ]]; then
  qiime demux summarize \
    --i-data "$OUT_DIR/trimmed-paired.qza" \
    --o-visualization "$OUT_DIR/trimmed-paired.qzv" || true
fi

# ── 4) EXPORT TRIMMED READS, DROP R2 & QIIME FILES, RE-IMPORT R1 ───────
TRIM_EXPORT="$OUT_DIR/trimmed-export"
if [[ ! -f "$OUT_DIR/trimmed-R1.qza" ]]; then
  echo "📤 Exporting trimmed reads and keeping R1 only…"
  mkdir -p "$TRIM_EXPORT"
  if [[ -z "$(ls -A "$TRIM_EXPORT" 2>/dev/null)" ]]; then
    qiime tools export --input-path "$OUT_DIR/trimmed-paired.qza" --output-path "$TRIM_EXPORT"
  else
    echo "⏩ Export dir not empty; using existing files."
  fi
  # Remove R2 fastqs, MANIFEST, metadata.yml so Casava importer accepts the dir
  find "$TRIM_EXPORT" -type f -name "*_R2_001.fastq.gz" -delete
  rm -f "$TRIM_EXPORT/MANIFEST" "$TRIM_EXPORT/metadata.yml" || true

  echo "📥 Re-importing R1 as single-end (Casava)…"
  qiime tools import \
    --type 'SampleData[SequencesWithQuality]' \
    --input-path "$TRIM_EXPORT" \
    --input-format CasavaOneEightSingleLanePerSampleDirFmt \
    --output-path "$OUT_DIR/trimmed-R1.qza"
else
  echo "⏩ Skipping re-import (found trimmed-R1.qza)"
fi

# Optional QZV for R1-only
if [[ ! -f "$OUT_DIR/trimmed-R1.qzv" ]]; then
  qiime demux summarize \
    --i-data "$OUT_DIR/trimmed-R1.qza" \
    --o-visualization "$OUT_DIR/trimmed-R1.qzv" || true
fi

# ── 5) DADA2 DENOISE-SINGLE (R1 only) ──────────────────────────────────
if [[ ! -f "$OUT_DIR/COI-table.qza" || ! -f "$OUT_DIR/COI-rep-seqs.qza" ]]; then
  echo "⚙️  Running DADA2 denoise-single on R1…"
  qiime dada2 denoise-single \
    --i-demultiplexed-seqs "$OUT_DIR/trimmed-R1.qza" \
    --p-trim-left 0 \
    --p-trunc-len "$TRUNC_LEN_R1" \
    --p-max-ee "$MAX_EE_R1" \
    --p-n-threads 1 \
    --o-table "$OUT_DIR/COI-table.qza" \
    --o-representative-sequences "$OUT_DIR/COI-rep-seqs.qza" \
    --o-denoising-stats "$OUT_DIR/COI-denoising-stats.qza" \
    --verbose
else
  echo "⏩ Skipping DADA2 (found COI-table/rep-seqs)"
fi

# ── 6) VISUALIZE DADA2 OUTPUTS ─────────────────────────────────────────
if [[ ! -f "$OUT_DIR/COI-denoising-stats.qzv" ]]; then
  echo "📈 Making QZVs (denoise stats, rep seqs)…"
  qiime metadata tabulate \
    --m-input-file "$OUT_DIR/COI-denoising-stats.qza" \
    --o-visualization "$OUT_DIR/COI-denoising-stats.qzv"
  qiime feature-table tabulate-seqs \
    --i-data "$OUT_DIR/COI-rep-seqs.qza" \
    --o-visualization "$OUT_DIR/COI-rep-seqs.qzv"
else
  echo "⏩ Skipping QZVs (found COI-denoising-stats.qzv / COI-rep-seqs.qzv)"
fi

echo "🔗 View stats: $OUT_DIR/COI-denoising-stats.qzv"
echo "🔗 View reps:  $OUT_DIR/COI-rep-seqs.qzv"

# ── 7) EXPORTS ──────────────────────────────────────────────────────────
if [[ ! -f "$EXPORT_DIR/feature-table.biom" || ! -f "$EXPORT_DIR/dna-sequences.fasta" ]]; then
  echo "📤 Exporting feature-table and rep-seqs…"
  qiime tools export --input-path "$OUT_DIR/COI-table.qza"    --output-path "$EXPORT_DIR"
  qiime tools export --input-path "$OUT_DIR/COI-rep-seqs.qza" --output-path "$EXPORT_DIR"
else
  echo "⏩ Skipping export (found BIOM/FASTA in $EXPORT_DIR)"
fi

# ── 8) BIOM → TSV + ID LIST ────────────────────────────────────────────
if [[ ! -f "$EXPORT_DIR/feature-table.tsv" ]]; then
  echo "🛠 Converting BIOM → TSV…"
  if [[ -f "$EXPORT_DIR/feature-table.biom" ]]; then
    biom convert -i "$EXPORT_DIR/feature-table.biom" -o "$EXPORT_DIR/feature-table.tsv" --to-tsv --table-type="OTU table"
  else
    echo "❌ $EXPORT_DIR/feature-table.biom not found"; exit 1
  fi
else
  echo "⏩ Skipping biom→tsv (found feature-table.tsv)"
fi
[[ -s "$EXPORT_DIR/feature-table.tsv" ]] || { echo "❌ feature-table.tsv is empty or missing"; exit 1; }

if [[ ! -f "$EXPORT_DIR/filtered-otu-ids.txt" ]]; then
  echo "🔎 Extracting OTU IDs…"
  cut -f1 "$EXPORT_DIR/feature-table.tsv" | tail -n +2 > "$EXPORT_DIR/filtered-otu-ids.txt"
else
  echo "⏩ Skipping ID list (found filtered-otu-ids.txt)"
fi

# ── 9) FILTER REP SEQS BY VALID IDs ────────────────────────────────────
if [[ -f "$EXPORT_DIR/dna-sequences.fasta" && ! -f "$EXPORT_DIR/dna-sequences-validated.fasta" ]]; then
  echo "🔬 Filtering rep sequences by valid OTUs…"
  mv "$EXPORT_DIR/dna-sequences.fasta" "$EXPORT_DIR/dna-sequences-all.fasta"
  if command -v seqkit >/dev/null 2>&1; then
    seqkit grep -f "$EXPORT_DIR/filtered-otu-ids.txt" "$EXPORT_DIR/dna-sequences-all.fasta" > "$EXPORT_DIR/dna-sequences-validated.fasta"
  else
    echo "⚠️  seqkit not found — copying all sequences as validated (no filtering)."
    cp -f "$EXPORT_DIR/dna-sequences-all.fasta" "$EXPORT_DIR/dna-sequences-validated.fasta"
  fi
else
  echo "⏩ Skipping rep-seq filter (validated.fasta exists or input missing)"
fi

# ── 10) PUBLISH CANONICAL OUTPUTS (for your later scripts) ─────────────
echo "📦 Publishing canonical outputs…"

# a) FASTA for BOLDigger + place for boldigger3_data
cp -f "$EXPORT_DIR/dna-sequences-validated.fasta"  "${CANON_EXPORT_FILTERED}/dna-sequences-validated.fasta"
# optional: keep copies of helpful files next to it
cp -f "$EXPORT_DIR/dna-sequences-all.fasta"        "${CANON_EXPORT_FILTERED}/dna-sequences-all.fasta" || true
cp -f "$EXPORT_DIR/filtered-otu-ids.txt"           "${CANON_EXPORT_FILTERED}/filtered-otu-ids.txt"    || true

# b) QIIME table files to BIOINFO_ROOT for your merge script
cp -f "$OUT_DIR/COI-table.qza"                     "${CANON_BIOINFO_FILES}/COI-table.qza"
cp -f "$EXPORT_DIR/feature-table.biom"             "${CANON_BIOINFO_FILES}/feature-table.biom"
cp -f "$EXPORT_DIR/feature-table.tsv"              "${CANON_BIOINFO_FILES}/feature-table.tsv"

echo
echo "✅ Done."
echo "📂 Run folder: $OUT_DIR"
echo "📝 Log:        $LOG"
echo "📦 Canonical:  ${CANON_EXPORT_FILTERED}  (FASTA for BOLDigger)"
echo "📦 Canonical:  ${CANON_BIOINFO_FILES}   (COI-table.qza + feature-table.*)"
echo "🔗 QZVs:       paired-end-demux.qzv, trimmed-paired.qzv, trimmed-R1.qzv, COI-denoising-stats.qzv, COI-rep-seqs.qzv"
echo "🧪 Params:     TRUNC_LEN_R1=${TRUNC_LEN_R1}  MAX_EE_R1=${MAX_EE_R1}  Cutadapt err=${CUTADAPT_ERROR_RATE}, ovlp=${CUTADAPT_MIN_OVERLAP}"

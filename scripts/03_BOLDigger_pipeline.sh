#!/usr/bin/env bash
# ── BOLDigger3 identification (chunked, RAM-friendly, resumable) ───────────────
set -euo pipefail
set -o errtrace
trap 'echo "❌ Failure at: $BASH_COMMAND (line $LINENO)" >&2' ERR

# Inputs from your previous script (canonical paths)
INPUT_FASTA="/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/dna-sequences-validated.fasta"
RESULTS_DIR="/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/boldigger3_data"

# BOLDigger3 settings (conservative for RAM)
DB=3                     # 1–8 (3 = animal library public+private)
MODE=3                   # 1=rapid, 2=genus+species, 3=exhaustive
THRESHOLDS=(97 95 90 85) # species/genus/family/order; class default = 75
CHUNK_SIZE=120           # 80–150 is typical
MAX_RETRIES=2
RETRY_INTERVAL=8         # seconds
WORKERS=1

mkdir -p "${RESULTS_DIR}"
# Allow overriding log path via env var BOLDIGGER_LOG (optional)
if [[ -n "${BOLDIGGER_LOG:-}" ]]; then
  mkdir -p "$(dirname "$BOLDIGGER_LOG")" 2>/dev/null || true
  LOG_FILE="$BOLDIGGER_LOG"
else
  LOG_FILE="${RESULTS_DIR}/boldigger3_chunked.log"
fi
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🧬 BOLDigger3 (chunked, resumable) started at $(date '+%Y-%m-%d %H:%M:%S')"
echo "📝 Log file: $LOG_FILE"
[[ -s "$INPUT_FASTA" ]] || { echo "❌ FASTA not found or empty: $INPUT_FASTA"; exit 1; }

# Ensure environment
if ! command -v boldigger3 >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    conda activate boldigger3-new || { echo "❌ Activate 'boldigger3-new' first"; exit 1; }
  else
    echo "❌ 'boldigger3' not on PATH and no conda available."; exit 1
  fi
fi

# Record tool version and exact parameters for reproducibility
if command -v boldigger3 >/dev/null 2>&1; then
  echo "🔢 boldigger3 version: $(boldigger3 --version 2>/dev/null | head -n1)"
fi
if [[ ${#THRESHOLDS[@]:-} -gt 0 ]]; then
  _thstr=$(printf "%s," "${THRESHOLDS[@]}"); _thstr="${_thstr%,}"
else
  _thstr=""
fi
echo "🧪 Params:     DB=${DB}  MODE=${MODE}  THRESHOLDS=[${_thstr}]  CHUNK_SIZE=${CHUNK_SIZE}  WORKERS=${WORKERS}  MAX_RETRIES=${MAX_RETRIES}  RETRY_INTERVAL=${RETRY_INTERVAL}s"

# Helper: split FASTA into N-record chunks (no external deps)
split_fasta_by_records() {
  local in="$1" per="$2" outdir="$3" prefix
  prefix="${outdir}/chunk_"
  mkdir -p "$outdir"
  awk -v n="$per" -v p="$prefix" '
    BEGIN{filei=0; rec=0}
    /^>/{ if(rec % n == 0){ filei++; close(out); out=sprintf("%s%03d.fasta", p, filei) } rec++ }
    { print >> out }
  ' "$in"
}

# Create chunks (only once; keep for resume)
CHUNK_DIR="${RESULTS_DIR}/chunks"
mkdir -p "$CHUNK_DIR"
if ! ls -1 "${CHUNK_DIR}"/chunk_*.fasta >/dev/null 2>&1; then
  rm -f "${CHUNK_DIR}"/chunk_*.fasta 2>/dev/null || true
  split_fasta_by_records "$INPUT_FASTA" "$CHUNK_SIZE" "$CHUNK_DIR"
fi
mapfile -t CHUNKS < <(ls -1 "${CHUNK_DIR}"/chunk_*.fasta 2>/dev/null || true)
(( ${#CHUNKS[@]} > 0 )) || { echo "❌ No chunks produced."; exit 1; }
echo "📦 Found ${#CHUNKS[@]} chunks (~${CHUNK_SIZE} seqs each)."

# Detect optional flags
HAS_WORKERS=0
if boldigger3 identify --help 2>/dev/null | grep -q -- '--workers'; then HAS_WORKERS=1; fi
HAS_THRESHOLDS=0
if boldigger3 identify --help 2>/dev/null | grep -q -- '--thresholds'; then HAS_THRESHOLDS=1; fi

# Process each chunk (resume-safe)
total="${#CHUNKS[@]}"
idx=0
for CHUNK in "${CHUNKS[@]}"; do
  idx=$((idx+1))
  part_tag=$(printf "%03d" "$idx")
  base="dna-sequences-validated"

  # Final part files expected by your Python merger (top-level in RESULTS_DIR)
  part_xlsx="${RESULTS_DIR}/${base}_bold_results_part_${part_tag}.xlsx"
  part_parq="${RESULTS_DIR}/${base}_identification_result_part_${part_tag}.parquet.snappy"

  # Resume/skip if both part files exist and are non-empty
  if [[ -s "$part_xlsx" && -s "$part_parq" ]]; then
    echo "⏩ Chunk ${idx}/${total} already done → skipping (${part_tag})"
    continue
  fi

  echo "🚀 Chunk ${idx}/${total}: $(basename "$CHUNK")"

  # Where THIS chunk’s BOLDigger outputs will be written
  chunk_base="$(basename "$CHUNK" .fasta)"
  chunk_out_dir="${CHUNK_DIR}/boldigger3_data"
  mkdir -p "$chunk_out_dir"

  # Known filename variants produced by different BOLDigger versions
  expected_parq="${chunk_out_dir}/${chunk_base}_identification_result.parquet.snappy"
  expected_xlsx_primary="${chunk_out_dir}/${chunk_base}_bold_results.xlsx"
  expected_xlsx_alt1="${chunk_out_dir}/${chunk_base}_bold_results_part_1.xlsx"
  expected_xlsx_alt2="${chunk_out_dir}/${chunk_base}_identification_result.xlsx"

  attempt=0
  while :; do
    echo "   → identify attempt $((attempt+1))/$((MAX_RETRIES+1))"

    # Run identify with outputs forced into chunk_out_dir
    # Put FASTA first to avoid argparse confusion on some builds
    if BOLDIGGER3_DATA_DIR="$chunk_out_dir" \
       boldigger3 identify "$CHUNK" --db "$DB" --mode "$MODE" \
         $( ((HAS_WORKERS)) && printf -- '--workers %d' "$WORKERS" ) \
         $( ((HAS_THRESHOLDS)) && printf -- '--thresholds %d %d %d %d' "${THRESHOLDS[@]}" ); then
      :
    else
      :
    fi

    # Decide which XLSX exists (if any)
    out_xlsx=""
    if [[ -s "$expected_xlsx_primary" ]]; then
      out_xlsx="$expected_xlsx_primary"
    elif [[ -s "$expected_xlsx_alt1" ]]; then
      out_xlsx="$expected_xlsx_alt1"
    elif [[ -s "$expected_xlsx_alt2" ]]; then
      out_xlsx="$expected_xlsx_alt2"
    fi

    if [[ -s "$expected_parq" && -n "$out_xlsx" ]]; then
      cp -f "$out_xlsx" "$part_xlsx"
      cp -f "$expected_parq" "$part_parq"
      echo "   📄 Saved part XLSX: $(basename "$part_xlsx")"
      echo "   🧱 Saved part PARQUET: $(basename "$part_parq")"
      break
    fi

    echo "   ⚠ Outputs not found yet in: $chunk_out_dir"
    # Minimal, pipefail-safe debug dump
    {
      echo "   ── Recent files at $chunk_out_dir:"
      ls -lt "$chunk_out_dir" | sed -n '1,15p' || true
    } || true

    attempt=$((attempt+1))
    if (( attempt > MAX_RETRIES )); then
      echo "   ❌ Reached max retries for this chunk (${chunk_base}). Aborting."
      exit 3
    fi
    echo "   ⏳ Sleeping ${RETRY_INTERVAL}s and retrying…"
    sleep "$RETRY_INTERVAL"
  done
done

# Merge all per-chunk Parquet files into the single file your Python expects
FINAL_PARQ="${RESULTS_DIR}/dna-sequences-validated_identification_result.parquet.snappy"
echo "🧩 Merging parquet parts → $(basename "$FINAL_PARQ")"
RESULTS_DIR="${RESULTS_DIR}" python3 - <<'PY'

import os, glob, sys
import pandas as pd

results_dir = os.environ.get("RESULTS_DIR", "")
if not results_dir:
    print("❌ RESULTS_DIR env missing", file=sys.stderr); sys.exit(1)

parts = sorted(glob.glob(os.path.join(results_dir, "dna-sequences-validated_identification_result_part_*.parquet.snappy")))
if not parts:
    print("❌ No parquet parts found in RESULTS_DIR.", file=sys.stderr); sys.exit(2)

dfs = []
for p in parts:
    try:
        dfs.append(pd.read_parquet(p))
    except Exception as e:
        print(f"❌ Failed reading {p}: {e}", file=sys.stderr); sys.exit(3)

df = pd.concat(dfs, ignore_index=True).drop_duplicates()
final_parq = os.path.join(results_dir, "dna-sequences-validated_identification_result.parquet.snappy")
df.to_parquet(final_parq, index=False)
print(f"✅ Wrote: {final_parq}  (rows: {len(df)})")
PY
echo "🏁 BOLDigger3 (chunked, resumable) complete at $(date '+%Y-%m-%d %H:%M:%S')"
echo "📁 Results dir: ${RESULTS_DIR}"
echo "   • Parts (XLSX): ${RESULTS_DIR}/dna-sequences-validated_bold_results_part_XXX.xlsx"
echo "   • Parts (PARQ): ${RESULTS_DIR}/dna-sequences-validated_identification_result_part_XXX.parquet.snappy"
echo "   • Final parquet: ${FINAL_PARQ}"

#!/usr/bin/env bash
set -eo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ProjectName> <ProjectDataDir>" >&2
  exit 1
fi

PROJECT_NAME="$1"
DATA_DIR="$2"

BIOINFO_DIR="${DATA_DIR}/bioinfo"
EXPORT_FILTERED="${BIOINFO_DIR}/exported-filtered"
BOLD_DIR="${EXPORT_FILTERED}/boldigger3_data"

# Find latest QIIME log
QIIME_LOG=""
if compgen -G "${BIOINFO_DIR}/run_*/nextseq_processing.log" > /dev/null; then
  QIIME_LOG=$(ls -1t ${BIOINFO_DIR}/run_*/nextseq_processing.log | head -n1 || true)
fi
if [[ -z "${QIIME_LOG}" ]]; then
  QIIME_LOG=$(find "${BIOINFO_DIR}" -type f -name 'nextseq_processing.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)
fi

# Parse QIIME params
declare -A Q
if [[ -n "${QIIME_LOG}" && -f "${QIIME_LOG}" ]]; then
  TXT=$(sed -n '1,2000p' "${QIIME_LOG}" 2>/dev/null || true)
  if [[ "$TXT" =~ Run:\ ([0-9_]+) ]]; then Q[runstamp]="${BASH_REMATCH[1]}"; fi
  # Extract single-line paths robustly via grep/sed to avoid multi-line captures
  line=$(grep -m1 'FASTQs:' "${QIIME_LOG}" 2>/dev/null || true); if [[ -n "$line" ]]; then Q[fastq_dir]="$(printf '%s' "$line" | sed -E 's/.*FASTQs:[[:space:]]*//')"; fi
  line=$(grep -m1 'OUT_DIR:' "${QIIME_LOG}" 2>/dev/null || true); if [[ -n "$line" ]]; then Q[out_dir]="$(printf '%s' "$line" | sed -E 's/.*OUT_DIR:[[:space:]]*//')"; fi
  line=$(grep -m1 'EXPORT:' "${QIIME_LOG}" 2>/dev/null || true); if [[ -n "$line" ]]; then Q[export_dir]="$(printf '%s' "$line" | sed -E 's/.*EXPORT:[[:space:]]*//')"; fi
  if [[ "$TXT" =~ trunc-len=([0-9]+),\ maxEE=([0-9]+) ]]; then Q[trunc_len_r1]="${BASH_REMATCH[1]}"; Q[max_ee_r1]="${BASH_REMATCH[2]}"; fi
  if [[ "$TXT" =~ Cutadapt\ primers:\ F=([A-Z]+)\ R=([A-Z]+) ]]; then Q[primer_f]="${BASH_REMATCH[1]}"; Q[primer_r]="${BASH_REMATCH[2]}"; fi
  if [[ "$TXT" =~ Cutadapt:\ error-rate=([0-9.]+),\ min-overlap=([0-9]+),\ match-read-wildcards=([0-9]+) ]]; then Q[cutadapt_error_rate]="${BASH_REMATCH[1]}"; Q[cutadapt_min_overlap]="${BASH_REMATCH[2]}"; Q[match_wildcards]="${BASH_REMATCH[3]}"; fi
  if [[ "$TXT" =~ DADA2:\ trim-left\ R1=([0-9]+),\ mode=([^,]+),\ threads=([0-9]+) ]]; then Q[trim_left_r1]="${BASH_REMATCH[1]}"; Q[dada2_mode]="${BASH_REMATCH[2]}"; Q[threads]="${BASH_REMATCH[3]}"; fi
  # Fallback older style
  if [[ -z "${Q[cutadapt_error_rate]:-}" || -z "${Q[cutadapt_min_overlap]:-}" ]]; then
    if [[ "$TXT" =~ Cutadapt\ err=([0-9.]+),\ ovlp=([0-9]+) ]]; then Q[cutadapt_error_rate]="${BASH_REMATCH[1]}"; Q[cutadapt_min_overlap]="${BASH_REMATCH[2]}"; fi
  fi
fi

# Parse BOLDigger params from log if available
BOLD_LOG="${BOLD_DIR}/boldigger3_chunked.log"
declare -A B
if [[ -f "${BOLD_LOG}" ]]; then
  T=$(sed -n '1,4000p' "${BOLD_LOG}" 2>/dev/null || true)
  # Prefer a Params line if exists
  if grep -qi 'Params:' <<<"$T"; then
    LINE=$(grep -i 'Params:' <<<"$T" | tail -n1)
    if [[ "$LINE" =~ DB=([^[:space:],]+) ]]; then B[db]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ MODE=([^[:space:],]+) ]]; then B[mode]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ CHUNK_SIZE=([^[:space:],]+) ]]; then B[chunk_size]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ WORKERS=([^[:space:],]+) ]]; then B[workers]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ MAX_RETRIES=([^[:space:],]+) ]]; then B[max_retries]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ RETRY_INTERVAL=([^[:space:],]+) ]]; then B[retry_interval]="${BASH_REMATCH[1]}"; fi
    if [[ "$LINE" =~ THRESHOLDS=\[([^\]]+)\] ]]; then B[thresholds]="${BASH_REMATCH[1]}"; fi
  else
    # Try to infer from last identify line
    LAST=$(grep -E 'boldigger3\s+identify' <<<"$T" | tail -n1 || true)
    if [[ "$LAST" =~ --db\ ([0-9]+) ]]; then B[db]="${BASH_REMATCH[1]}"; fi
    if [[ "$LAST" =~ --mode\ ([0-9]+) ]]; then B[mode]="${BASH_REMATCH[1]}"; fi
    if [[ "$LAST" =~ --thresholds\ ([0-9\ ]+) ]]; then B[thresholds]="${BASH_REMATCH[1]}"; fi
    if [[ "$LAST" =~ --workers\ ([0-9]+) ]]; then B[workers]="${BASH_REMATCH[1]}"; fi
  fi
fi

# Fallback to script constants if log had nothing
declare -A BS
if [[ ${#B[@]} -eq 0 ]]; then
  SCRIPTP="scripts/03_BOLDigger_pipeline.sh"
  if [[ -f "$SCRIPTP" ]]; then
    TXT=$(sed -n '1,4000p' "$SCRIPTP")
    if [[ "$TXT" =~ ^DB=([0-9]+) ]]; then BS[db]="${BASH_REMATCH[1]}"; fi
    if [[ "$TXT" =~ ^MODE=([0-9]+) ]]; then BS[mode]="${BASH_REMATCH[1]}"; fi
    if [[ "$TXT" =~ ^THRESHOLDS=\(([^\)]+)\) ]]; then BS[thresholds]="${BASH_REMATCH[1]}"; fi
    if [[ "$TXT" =~ ^CHUNK_SIZE=([0-9]+) ]]; then BS[chunk_size]="${BASH_REMATCH[1]}"; fi
    if [[ "$TXT" =~ ^WORKERS=([0-9]+) ]]; then BS[workers]="${BASH_REMATCH[1]}"; fi
  fi
fi

SNAP_DIR="snapshots/$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
mkdir -p "$SNAP_DIR"

# Build snapshot.json
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat >"${SNAP_DIR}/snapshot.json" <<JSON
{
  "project": "${PROJECT_NAME}",
  "created_utc": "${created}",
  "data_dir": "$(readlink -f "$DATA_DIR" 2>/dev/null || realpath "$DATA_DIR" 2>/dev/null || echo "$DATA_DIR")",
  "bioinfo_dir": "$(readlink -f "$BIOINFO_DIR" 2>/dev/null || realpath "$BIOINFO_DIR" 2>/dev/null || echo "$BIOINFO_DIR")",
  "logs": {
    "qiime2": "${QIIME_LOG:-}",
    "boldigger": "${BOLD_LOG:-}"
  },
  "artifacts": {
    "coi_table_qza": "$(readlink -f "$BIOINFO_DIR/COI-table.qza" 2>/dev/null || realpath "$BIOINFO_DIR/COI-table.qza" 2>/dev/null || echo "$BIOINFO_DIR/COI-table.qza")",
    "feature_table_biom": "$(readlink -f "$BIOINFO_DIR/feature-table.biom" 2>/dev/null || realpath "$BIOINFO_DIR/feature-table.biom" 2>/dev/null || echo "$BIOINFO_DIR/feature-table.biom")",
    "feature_table_tsv": "$(readlink -f "$BIOINFO_DIR/feature-table.tsv" 2>/dev/null || realpath "$BIOINFO_DIR/feature-table.tsv" 2>/dev/null || echo "$BIOINFO_DIR/feature-table.tsv")",
    "rep_seqs_fasta": "$(readlink -f "$EXPORT_FILTERED/dna-sequences-validated.fasta" 2>/dev/null || realpath "$EXPORT_FILTERED/dna-sequences-validated.fasta" 2>/dev/null || echo "$EXPORT_FILTERED/dna-sequences-validated.fasta")",
    "boldigger_merged_parquet": "$(readlink -f "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy" 2>/dev/null || realpath "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy" 2>/dev/null || echo "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy")"
  },
  "params_from_log": $(
    {
      printf '{'
      first=1
      for k in runstamp fastq_dir out_dir export_dir trunc_len_r1 max_ee_r1 cutadapt_error_rate cutadapt_min_overlap match_wildcards primer_f primer_r trim_left_r1 dada2_mode threads; do
        v=${Q[$k]:-}
        [[ -z "$v" ]] && continue
        [[ $first -eq 0 ]] && printf ',' || first=0
        if [[ "$k" =~ ^(trunc_len_r1|max_ee_r1|cutadapt_min_overlap|trim_left_r1|threads|match_wildcards)$ ]]; then
          printf '"%s": %s' "$k" "$v"
        elif [[ "$k" == cutadapt_error_rate ]]; then
          printf '"%s": %s' "$k" "$v"
        else
          printf '"%s": "%s"' "$k" "$v"
        fi
      done
      printf '}'
    }
  ),
  "boldigger_params_from_log": $(
    {
      printf '{'; first=1
      for k in db mode chunk_size workers max_retries retry_interval thresholds; do
        v=${B[$k]:-}
        [[ -z "$v" ]] && continue
        [[ $first -eq 0 ]] && printf ',' || first=0
        if [[ "$k" == thresholds ]]; then
          # normalize thresholds list to array
          if [[ "$v" =~ \, ]]; then arr="[$v]"; else arr="[$(echo "$v" | sed 's/\s\+/,/g')]"; fi
          printf '"%s": %s' "$k" "$arr"
        else
          printf '"%s": %s' "$k" "$v"
        fi
      done
      printf '}'
    }
  ),
  "boldigger_params_from_script": $(
    {
      printf '{'; first=1
      for k in db mode chunk_size workers thresholds; do
        v=${BS[$k]:-}
        [[ -z "$v" ]] && continue
        [[ $first -eq 0 ]] && printf ',' || first=0
        if [[ "$k" == thresholds ]]; then
          # script thresholds are space-separated
          printf '"%s": [%s]' "$k" "$(echo "$v" | sed 's/\s\+/,/g')"
        else
          printf '"%s": %s' "$k" "$v"
        fi
      done
      printf '}'
    }
  )
}
JSON

# Build METHODS.md
{
  echo "Project"
  echo "- Name: ${PROJECT_NAME}"
  echo "- Data root: $(readlink -f "$DATA_DIR" 2>/dev/null || realpath "$DATA_DIR" 2>/dev/null || echo "$DATA_DIR")"
  echo
  echo "Pipeline"
  echo "- QIIME 2 → COI table and representative sequences; exports generated."
  echo "- BOLDigger3 run in chunked mode; parts merged to one parquet."
  echo
  echo "Key Artifacts"
  echo "- QIIME table: $(readlink -f "$BIOINFO_DIR/COI-table.qza" 2>/dev/null || realpath "$BIOINFO_DIR/COI-table.qza" 2>/dev/null || echo "$BIOINFO_DIR/COI-table.qza")"
  echo "- Feature table (TSV): $(readlink -f "$BIOINFO_DIR/feature-table.tsv" 2>/dev/null || realpath "$BIOINFO_DIR/feature-table.tsv" 2>/dev/null || echo "$BIOINFO_DIR/feature-table.tsv")"
  echo "- Rep-seqs (validated FASTA): $(readlink -f "$EXPORT_FILTERED/dna-sequences-validated.fasta" 2>/dev/null || realpath "$EXPORT_FILTERED/dna-sequences-validated.fasta" 2>/dev/null || echo "$EXPORT_FILTERED/dna-sequences-validated.fasta")"
  echo "- BOLDigger merged parquet: $(readlink -f "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy" 2>/dev/null || realpath "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy" 2>/dev/null || echo "$BOLD_DIR/dna-sequences-validated_identification_result.parquet.snappy")"
  echo
  if [[ ${#Q[@]} -gt 0 ]]; then
    echo "QIIME2 Parameters"
    [[ -n ${Q[trunc_len_r1]:-} ]] && echo "- trunc-len R1: ${Q[trunc_len_r1]}"
    [[ -n ${Q[max_ee_r1]:-} ]] && echo "- maxEE R1: ${Q[max_ee_r1]}"
    [[ -n ${Q[trim_left_r1]:-} ]] && echo "- trim-left R1: ${Q[trim_left_r1]}"
    [[ -n ${Q[dada2_mode]:-} ]] && echo "- DADA2 mode: ${Q[dada2_mode]}"
    [[ -n ${Q[threads]:-} ]] && echo "- DADA2 threads: ${Q[threads]}"
    [[ -n ${Q[cutadapt_error_rate]:-} ]] && echo "- Cutadapt error rate: ${Q[cutadapt_error_rate]}"
    [[ -n ${Q[cutadapt_min_overlap]:-} ]] && echo "- Cutadapt min overlap: ${Q[cutadapt_min_overlap]}"
    [[ -n ${Q[match_wildcards]:-} ]] && echo "- Cutadapt match-read-wildcards: ${Q[match_wildcards]}"
    [[ -n ${Q[primer_f]:-} ]] && echo "- Primer F: ${Q[primer_f]}"
    [[ -n ${Q[primer_r]:-} ]] && echo "- Primer R: ${Q[primer_r]}"
    echo
  fi
  echo "BOLDigger Settings"
  if [[ ${#B[@]} -gt 0 ]]; then
    [[ -n ${B[db]:-} ]] && echo "- DB: ${B[db]} (from log)"
    [[ -n ${B[mode]:-} ]] && echo "- MODE: ${B[mode]} (from log)"
    [[ -n ${B[thresholds]:-} ]] && echo "- Thresholds: ${B[thresholds]} (from log)"
    [[ -n ${B[chunk_size]:-} ]] && echo "- Chunk size: ${B[chunk_size]} (from log)"
    [[ -n ${B[workers]:-} ]] && echo "- Workers: ${B[workers]} (from log)"
    [[ -n ${B[max_retries]:-} ]] && echo "- Max retries: ${B[max_retries]} (from log)"
    [[ -n ${B[retry_interval]:-} ]] && echo "- Retry interval: ${B[retry_interval]} (from log)"
  elif [[ ${#BS[@]} -gt 0 ]]; then
    [[ -n ${BS[db]:-} ]] && echo "- DB: ${BS[db]} (from script)"
    [[ -n ${BS[mode]:-} ]] && echo "- MODE: ${BS[mode]} (from script)"
    [[ -n ${BS[thresholds]:-} ]] && echo "- Thresholds: ${BS[thresholds]} (from script)"
    [[ -n ${BS[chunk_size]:-} ]] && echo "- Chunk size: ${BS[chunk_size]} (from script)"
    [[ -n ${BS[workers]:-} ]] && echo "- Workers: ${BS[workers]} (from script)"
  fi
} >"${SNAP_DIR}/METHODS.md"

echo "Snapshot written: ${SNAP_DIR}"

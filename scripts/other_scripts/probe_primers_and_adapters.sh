#!/usr/bin/env bash
# Primer/adapter probe for paired-end demuxed reads
set -eu; (set -o pipefail) >/dev/null 2>&1 || true

# ====== CONFIG ======
BASE="/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo"
FWD_FOLMER="GGTCAACAAATCATAAAGATATTGG"   # LCO1490 (forward primer; for R1 5′)
REV_FOLMER="TAAACTTCAGGGTGACCAAAAAATCA"   # HCO2198 (reverse primer; for R2 5′)
ILLUMINA_AD1="AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
ILLUMINA_AD2="AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"
ERROR_RATE="0.10"
# =====================

echo "== Primer/Adapter Probe =="
echo "WSL base: $BASE"
date +"Started at: %Y-%m-%d %H:%M:%S"

command -v qiime >/dev/null || { echo "❌ QIIME2 not in PATH"; exit 1; }
command -v cutadapt >/dev/null || { echo "❌ cutadapt CLI missing. Install: conda install -c bioconda cutadapt"; exit 1; }

STAMP=$(date +%Y%m%d_%H%M%S)
WORK="$BASE/primer_probe_$STAMP"
mkdir -p "$WORK"

DEMUX_QZA="$BASE/paired-end-demux.qza"
[[ -f "$DEMUX_QZA" ]] || DEMUX_QZA=$(find "$BASE" -maxdepth 3 -type f -name "*demux*.qza" | head -n1 || true)
[[ -f "$DEMUX_QZA" ]] || { echo "❌ No demux .qza found under $BASE"; exit 1; }
echo "Using demux artifact: $DEMUX_QZA"

# Summarize + export FASTQs
qiime demux summarize --i-data "$DEMUX_QZA" --o-visualization "$WORK/demux-original.qzv" >/dev/null
qiime tools export --input-path "$DEMUX_QZA" --output-path "$WORK/demux_export" >/dev/null

R1_LIST=($(ls "$WORK"/demux_export/*_R1_*.fastq.gz 2>/dev/null || true))
R2_LIST=($(ls "$WORK"/demux_export/*_R2_*.fastq.gz 2>/dev/null || true))
echo "Exported ${#R1_LIST[@]} R1 files; ${#R2_LIST[@]} R2 files."

# ---------- helpers ----------
# Pull a clean integer (removes commas) from cutadapt’s report line labels
get_int() { tr -d '\r' | grep -Eo "$1[[:space:]]*[0-9,]+" | grep -Eo '[0-9,]+' | tr -d ',' | head -n1; }

# Try to find an R2 mate for a given R1, allowing for naming quirks
find_mate() {
  local r1="$1" base="${r1##*/}" dir="${r1%/*}" cand
  for cand in \
    "${r1/_R1_/_R2_}" "${r1/_R1/_R2}" "${r1/R1_001/R2_001}" \
    "${dir}/$(echo "$base" | sed 's/_R1_/_R2_/')" \
    "${dir}/$(echo "$base" | sed 's/R1_001/R2_001/')";
  do [[ -f "$cand" ]] && { echo "$cand"; return; }; done
  echo ""
}

pct() { awk -v t="$1" -v h="$2" 'BEGIN{if(t==0) printf "0.00"; else printf "%.2f", 100.0*h/t}'; }

run_cutadapt_pairs() {
  local flagF="$1" flagR="$2" label="$3" sum="$WORK/cutadapt_${label}_PAIRED_summary.txt"
  local tot=0 hit=0
  for r1 in "${R1_LIST[@]}"; do
    r2=$(find_mate "$r1"); [[ -z "$r2" ]] && continue
    out=$(cutadapt $flagF $flagR -e "$ERROR_RATE" --no-indels --discard-untrimmed \
          -o /dev/null -p /dev/null "$r1" "$r2" 2>&1 || true)
    tp=$(echo "$out" | get_int "Total read pairs processed:")
    pa=$(echo "$out" | get_int "Pairs with adapters:")
    tp=${tp:-0}; pa=${pa:-0}; tot=$((tot+tp)); hit=$((hit+pa))
  done
  echo "LABEL=${label}_PAIRED" > "$sum"
  echo "TOTAL_PAIRS=$tot" >> "$sum"
  echo "PAIRS_WITH_ADAPTERS=$hit" >> "$sum"
  echo "PCT_PAIRS_WITH_ADAPTERS=$(pct "$tot" "$hit")" >> "$sum"
  echo "   [${label}_PAIRED] total pairs: $tot ; pairs with adapters: $hit ($(awk -F= '/PCT/{print $2}' "$sum")%)"
}

run_cutadapt_single() {
  local flag="$1" label="$2" which="$3" sum="$WORK/cutadapt_${label}_${which}_summary.txt"
  local tot=0 hit=0; local files=("${R1_LIST[@]}"); [[ "$which" == "R2" ]] && files=("${R2_LIST[@]}")
  for f in "${files[@]}"; do
    out=$(cutadapt $flag -e "$ERROR_RATE" --no-indels --discard-untrimmed -o /dev/null "$f" 2>&1 || true)
    trd=$(echo "$out" | get_int "Total reads processed:")
    rad=$(echo "$out" | get_int "Reads with adapters:")
    trd=${trd:-0}; rad=${rad:-0}; tot=$((tot+trd)); hit=$((hit+rad))
  done
  echo "LABEL=${label}_${which}" > "$sum"
  echo "TOTAL_READS=$tot" >> "$sum"
  echo "READS_WITH_ADAPTERS=$hit" >> "$sum"
  echo "PCT_READS_WITH_ADAPTERS=$(pct "$tot" "$hit")" >> "$sum"
  echo "   [${label}_${which}] total reads: $tot ; reads with adapters: $hit ($(awk -F= '/PCT/{print $2}' "$sum")%)"
}
# ------------------------------

echo "→ Probing 5′-anchored Folmer primers (PAIRED)…"
run_cutadapt_pairs "-g ^$FWD_FOLMER" "-G ^$REV_FOLMER" "folmer_5prime"

echo "→ Probing 5′-anchored Folmer primers (SINGLE-END)…"
run_cutadapt_single "-g ^$FWD_FOLMER" "folmer_5prime" "R1"
run_cutadapt_single "-g ^$REV_FOLMER" "folmer_5prime" "R2"

echo "→ Probing Folmer primers ANYWHERE (SINGLE-END)…"
run_cutadapt_single "-b $FWD_FOLMER" "folmer_anywhere" "R1"
run_cutadapt_single "-b $REV_FOLMER" "folmer_anywhere" "R2"

echo "→ Probing Illumina adapters ANYWHERE (SINGLE-END)…"
run_cutadapt_single "-b $ILLUMINA_AD1 -b $ILLUMINA_AD2" "illumina_anywhere" "R1"
run_cutadapt_single "-b $ILLUMINA_AD1 -b $ILLUMINA_AD2" "illumina_anywhere" "R2"

# QIIME-native probe artifact (optional; non-destructive)
qiime cutadapt trim-paired \
  --i-demultiplexed-sequences "$DEMUX_QZA" \
  --p-front-f "$FWD_FOLMER" \
  --p-front-r "$REV_FOLMER" \
  --p-error-rate "$ERROR_RATE" --p-no-indels --p-discard-untrimmed \
  --o-trimmed-sequences "$WORK/demux-primers-found.qza" \
  --verbose > "$WORK/qiime_cutadapt_5prime.log" 2>&1 || true
qiime demux summarize --i-data "$WORK/demux-primers-found.qza" --o-visualization "$WORK/demux-primers-found.qzv" >/dev/null

echo
echo "===================== FINAL SUMMARY ====================="
for f in "$WORK"/cutadapt_*_summary.txt; do
  echo "--- $(basename "$f") ---"
  cat "$f"
done
echo
echo "Open in QIIME 2 View:"
echo "  • $WORK/demux-original.qzv"
echo "  • $WORK/demux-primers-found.qzv"
echo "FASTQs: $WORK/demux_export/"
echo "Logs:   $WORK/"
date +"Finished at: %Y-%m-%d %H:%M:%S"

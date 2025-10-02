#!/usr/bin/env python3
"""
Parse QIIME2 processing logs produced by 02_data_processing.sh and emit a
compact JSON summary with key parameters useful for methods sections.

Inputs:
  - Path to a QIIME2 processing log (nextseq_processing.log)

Outputs:
  - JSON to stdout with fields if found: trunc_len_r1, max_ee_r1,
    primer_f, primer_r, cutadapt_error_rate, cutadapt_min_overlap,
    fastq_dir, out_dir, export_dir, runstamp.

Usage:
  python scripts/extract_params_from_logs.py path/to/nextseq_processing.log
"""
import json
import re
import sys
from pathlib import Path


def parse_log(text: str) -> dict:
    d = {}

    # Runstamp
    m = re.search(r"Run:\s*(\d{8}_\d{6})", text)
    if m:
        d["runstamp"] = m.group(1)

    # Directories
    for key, pat in {
        "fastq_dir": r"FASTQs:\s*(.+)",
        "out_dir": r"OUT_DIR:\s*(.+)",
        "export_dir": r"EXPORT:\s*(.+)",
    }.items():
        m = re.search(pat, text)
        if m:
            d[key] = m.group(1).strip()

    # DADA2 params
    m = re.search(r"DADA2 single-end R1 with trunc-len=(\d+), maxEE=(\d+)", text)
    if m:
        d["trunc_len_r1"] = int(m.group(1))
        d["max_ee_r1"] = int(m.group(2))

    # Final params line
    m = re.search(r"Params:\s*TRUNC_LEN_R1=(\d+)\s+MAX_EE_R1=(\d+)\s+Cutadapt err=([0-9.]+), ovlp=(\d+)", text)
    if m:
        d.setdefault("trunc_len_r1", int(m.group(1)))
        d.setdefault("max_ee_r1", int(m.group(2)))
        d["cutadapt_error_rate"] = float(m.group(3))
        d["cutadapt_min_overlap"] = int(m.group(4))

    # Primers (may be visible earlier in script logs)
    m = re.search(r"PRIMER_F=([A-Z]+)", text)
    if m:
        d["primer_f"] = m.group(1)
    m = re.search(r"PRIMER_R=([A-Z]+)", text)
    if m:
        d["primer_r"] = m.group(1)

    return d


def main():
    if len(sys.argv) < 2:
        print("{}", end="")
        return
    p = Path(sys.argv[1])
    if not p.exists():
        print("{}", end="")
        return
    txt = p.read_text(errors="ignore")
    data = parse_log(txt)
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()


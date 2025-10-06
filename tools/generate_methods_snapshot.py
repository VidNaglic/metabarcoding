#!/usr/bin/env python3
"""
Generate snapshot.json and METHODS.md without modifying original scripts.

Discovers the latest QIIME run log and BOLDigger outputs in a project
data directory, parses parameters from logs where available, and writes
rich documentation under snapshots/<project>/.

Usage:
  python tools/generate_methods_snapshot.py \
    --project-name travniki \
    --project-data-dir c:/Users/vidna/Documents/mtb/data/mtb_travniki

This script is read-only with respect to your original pipeline scripts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional, List, Any


def sha256_file(p: Path) -> Optional[str]:
    try:
        h = hashlib.sha256()
        with p.open('rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None


def find_latest_qiime_log(bioinfo: Path) -> Optional[Path]:
    runs = sorted([d for d in bioinfo.glob('run_*') if d.is_dir()], key=lambda p: p.name, reverse=True)
    for d in runs:
        p = d / 'nextseq_processing.log'
        if p.exists():
            return p
    # fallback: search recursively
    matches = sorted(bioinfo.rglob('nextseq_processing.log'), key=lambda p: p.stat().st_mtime, reverse=True)
    return matches[0] if matches else None


def parse_qiime_log_text(text: str) -> Dict[str, Any]:
    d: Dict[str, Any] = {}
    m = re.search(r"Run:\s*(\d{8}_\d{6})", text)
    if m:
        d["runstamp"] = m.group(1)
    for key, pat in {
        "fastq_dir": r"FASTQs:\s*(.+)",
        "out_dir": r"OUT_DIR:\s*(.+)",
        "export_dir": r"EXPORT:\s*(.+)",
    }.items():
        m = re.search(pat, text)
        if m:
            d[key] = m.group(1).strip()

    m = re.search(r"DADA2 single-end R1 with trunc-len=(\d+), maxEE=(\d+)", text)
    if m:
        d["trunc_len_r1"] = int(m.group(1))
        d["max_ee_r1"] = int(m.group(2))

    m = re.search(r"Cutadapt primers: F=([A-Z]+) R=([A-Z]+)", text)
    if m:
        d["primer_f"] = m.group(1)
        d["primer_r"] = m.group(2)
    m = re.search(r"Cutadapt: error-rate=([0-9.]+), min-overlap=(\d+), match-read-wildcards=(\d+)", text)
    if m:
        d["cutadapt_error_rate"] = float(m.group(1))
        d["cutadapt_min_overlap"] = int(m.group(2))
        d["match_wildcards"] = int(m.group(3))
    m = re.search(r"DADA2: trim-left R1=(\d+), mode=([^,]+), threads=(\d+)", text)
    if m:
        d["trim_left_r1"] = int(m.group(1))
        d["dada2_mode"] = m.group(2).strip()
        d["threads"] = int(m.group(3))

    # Fallback generic Params line(s)
    params_lines = re.findall(r"^.*Params:\s*(.+)$", text, flags=re.MULTILINE)
    if params_lines:
        kv_line = params_lines[-1]
        tokens = kv_line.strip().split()
        for tok in tokens:
            if '=' not in tok:
                continue
            key, val = tok.split('=', 1)
            key = key.strip()
            val = val.strip().strip(',')
            norm = {
                'TRUNC_LEN_R1': 'trunc_len_r1',
                'MAX_EE_R1': 'max_ee_r1',
                'TRIM_LEFT_R1': 'trim_left_r1',
                'DADA2_MODE': 'dada2_mode',
                'THREADS': 'threads',
                'MATCH_WILDCARDS': 'match_wildcards',
                'PRIMER_F': 'primer_f',
                'PRIMER_R': 'primer_r',
                'CUTADAPT_ERR': 'cutadapt_error_rate',
                'CUTADAPT_OVLP': 'cutadapt_min_overlap',
            }.get(key)
            if not norm:
                continue
            if norm in {"trunc_len_r1", "max_ee_r1", "trim_left_r1", "threads", "match_wildcards", "cutadapt_min_overlap"}:
                try:
                    d[norm] = int(val)
                except ValueError:
                    pass
            elif norm == "cutadapt_error_rate":
                try:
                    d[norm] = float(val)
                except ValueError:
                    pass
            else:
                d[norm] = val

    if "cutadapt_error_rate" not in d or "cutadapt_min_overlap" not in d:
        m = re.search(r"Cutadapt err=([0-9.]+), ovlp=(\d+)", text)
        if m:
            d.setdefault("cutadapt_error_rate", float(m.group(1)))
            d.setdefault("cutadapt_min_overlap", int(m.group(2)))

    return d


def parse_boldigger_from_log(text: str) -> Dict[str, Any]:
    d: Dict[str, Any] = {}
    # Try an explicit Params line if present
    m = re.findall(r"^.*Params:\s*(.+)$", text, flags=re.MULTILINE)
    if m:
        tokens = m[-1].strip()
        # thresholds may be in [a,b,c]
        th = re.search(r"THRESHOLDS=\[([^\]]+)\]", tokens)
        if th:
            d["thresholds"] = [int(x) for x in re.split(r"\s*,\s*", th.group(1).strip()) if x]
        for k, norm in {
            'DB': 'db', 'MODE': 'mode', 'CHUNK_SIZE': 'chunk_size', 'WORKERS': 'workers',
            'MAX_RETRIES': 'max_retries', 'RETRY_INTERVAL': 'retry_interval'
        }.items():
            mm = re.search(rf"{k}=([^\s,]+)", tokens)
            if mm:
                try:
                    d[norm] = int(mm.group(1).rstrip('s'))
                except ValueError:
                    d[norm] = mm.group(1)
    # If no Params line, attempt to parse any identify command line traces
    if not d:
        cmd = re.findall(r"boldigger3\s+identify\b[^\n]*", text)
        if cmd:
            last = cmd[-1]
            mm = re.search(r"--db\s+(\d+)", last)
            if mm:
                d["db"] = int(mm.group(1))
            mm = re.search(r"--mode\s+(\d+)", last)
            if mm:
                d["mode"] = int(mm.group(1))
            th = re.search(r"--thresholds\s+([0-9\s]+)", last)
            if th:
                d["thresholds"] = [int(x) for x in th.group(1).split() if x]
            mm = re.search(r"--workers\s+(\d+)", last)
            if mm:
                d["workers"] = int(mm.group(1))
    # Version line if present
    mm = re.search(r"boldigger3 version:\s*(.+)$", text, flags=re.MULTILINE)
    if mm:
        d["version"] = mm.group(1).strip()
    return d


def load_text(path: Path) -> str:
    try:
        return path.read_text(errors='ignore')
    except Exception:
        return ""


def parse_boldigger_from_script(repo_root: Path) -> Dict[str, Any]:
    d: Dict[str, Any] = {}
    script = repo_root / 'scripts' / '03_BOLDigger_pipeline.sh'
    if not script.exists():
        return d
    text = load_text(script)
    mm = re.search(r"^DB=(\d+)", text, flags=re.MULTILINE)
    if mm:
        d['db'] = int(mm.group(1))
    mm = re.search(r"^MODE=(\d+)", text, flags=re.MULTILINE)
    if mm:
        d['mode'] = int(mm.group(1))
    mm = re.search(r"^THRESHOLDS=\(([^)]+)\)", text, flags=re.MULTILINE)
    if mm:
        d['thresholds'] = [int(x) for x in mm.group(1).split() if x]
    mm = re.search(r"^CHUNK_SIZE=(\d+)", text, flags=re.MULTILINE)
    if mm:
        d['chunk_size'] = int(mm.group(1))
    mm = re.search(r"^WORKERS=(\d+)", text, flags=re.MULTILINE)
    if mm:
        d['workers'] = int(mm.group(1))
    d['_script_path'] = str(script)
    d['_script_sha256'] = sha256_file(script)
    return d


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--project-name', required=True)
    ap.add_argument('--project-data-dir', required=True)
    args = ap.parse_args()

    proj = args.project_name
    data_dir = Path(args.project_data_dir).resolve()
    bioinfo = data_dir / 'bioinfo'
    export_filtered = bioinfo / 'exported-filtered'
    bold_data_dir = export_filtered / 'boldigger3_data'

    # Discover logs
    qiime_log = find_latest_qiime_log(bioinfo)
    bold_log = bold_data_dir / 'boldigger3_chunked.log'
    qiime_params: Dict[str, Any] = {}
    if qiime_log and qiime_log.exists():
        qiime_params = parse_qiime_log_text(load_text(qiime_log))

    bold_params_log: Dict[str, Any] = {}
    if bold_log.exists():
        bold_params_log = parse_boldigger_from_log(load_text(bold_log))

    # Fallback to script constants if log lacks explicit params
    repo_root = Path.cwd()
    bold_params_script: Dict[str, Any] = {}
    if not bold_params_log:
        bold_params_script = parse_boldigger_from_script(repo_root)

    # Canonical artifacts
    artifacts = {
        'coi_table_qza': str((bioinfo / 'COI-table.qza')),
        'feature_table_biom': str((bioinfo / 'feature-table.biom')),
        'feature_table_tsv': str((bioinfo / 'feature-table.tsv')),
        'rep_seqs_fasta': str((export_filtered / 'dna-sequences-validated.fasta')),
        'boldigger_merged_parquet': str((bold_data_dir / 'dna-sequences-validated_identification_result.parquet.snappy')),
    }

    # Prepare snapshot dir
    snap_root = Path.cwd() / 'snapshots'
    snap_dir = snap_root / proj.lower()
    snap_dir.mkdir(parents=True, exist_ok=True)

    snapshot = {
        'project': proj,
        'created_utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'data_dir': str(data_dir),
        'bioinfo_dir': str(bioinfo),
        'logs': {
            'qiime2': str(qiime_log) if qiime_log else None,
            'boldigger': str(bold_log) if bold_log.exists() else None,
        },
        'artifacts': artifacts,
        'params_from_log': qiime_params or None,
        'boldigger_params_from_log': bold_params_log or None,
        'boldigger_params_from_script': bold_params_script or None,
    }

    # Write snapshot.json
    snap_json_path = snap_dir / 'snapshot.json'
    snap_json_path.write_text(json.dumps(snapshot, indent=2), encoding='utf-8')

    # Compose METHODS.md
    methods_lines: List[str] = []
    methods_lines += [
        'Project',
        f'- Name: {proj}',
        f'- Data root: {data_dir}',
        '',
        'Pipeline',
        '- QIIME 2 → COI table and representative sequences; exports generated.',
        '- BOLDigger3 run in chunked mode; parts merged to one parquet.',
        '',
        'Key Artifacts',
        f'- QIIME table: {artifacts["coi_table_qza"]}',
        f'- Feature table (TSV): {artifacts["feature_table_tsv"]}',
        f'- Rep-seqs (validated FASTA): {artifacts["rep_seqs_fasta"]}',
        f'- BOLDigger merged parquet: {artifacts["boldigger_merged_parquet"]}',
        '',
    ]

    if qiime_params:
        methods_lines += ['QIIME2 Parameters']
        if 'trunc_len_r1' in qiime_params:
            methods_lines.append(f'- trunc-len R1: {qiime_params["trunc_len_r1"]}')
        if 'max_ee_r1' in qiime_params:
            methods_lines.append(f'- maxEE R1: {qiime_params["max_ee_r1"]}')
        if 'trim_left_r1' in qiime_params:
            methods_lines.append(f'- trim-left R1: {qiime_params["trim_left_r1"]}')
        if 'dada2_mode' in qiime_params:
            methods_lines.append(f'- DADA2 mode: {qiime_params["dada2_mode"]}')
        if 'threads' in qiime_params:
            methods_lines.append(f'- DADA2 threads: {qiime_params["threads"]}')
        if 'cutadapt_error_rate' in qiime_params:
            methods_lines.append(f'- Cutadapt error rate: {qiime_params["cutadapt_error_rate"]}')
        if 'cutadapt_min_overlap' in qiime_params:
            methods_lines.append(f'- Cutadapt min overlap: {qiime_params["cutadapt_min_overlap"]}')
        if 'match_wildcards' in qiime_params:
            methods_lines.append(f'- Cutadapt match-read-wildcards: {qiime_params["match_wildcards"]}')
        if 'primer_f' in qiime_params:
            methods_lines.append(f'- Primer F: {qiime_params["primer_f"]}')
        if 'primer_r' in qiime_params:
            methods_lines.append(f'- Primer R: {qiime_params["primer_r"]}')
        methods_lines.append('')

    methods_lines += ['BOLDigger Settings']
    if bold_params_log:
        bp = bold_params_log
        if 'db' in bp:
            methods_lines.append(f'- DB: {bp["db"]} (from log)')
        if 'mode' in bp:
            methods_lines.append(f'- MODE: {bp["mode"]} (from log)')
        if 'thresholds' in bp:
            methods_lines.append(f'- Thresholds: {", ".join(map(str, bp["thresholds"]))} (from log)')
        if 'chunk_size' in bp:
            methods_lines.append(f'- Chunk size: {bp["chunk_size"]} (from log)')
        if 'workers' in bp:
            methods_lines.append(f'- Workers: {bp["workers"]} (from log)')
        if 'max_retries' in bp:
            methods_lines.append(f'- Max retries: {bp["max_retries"]} (from log)')
        if 'retry_interval' in bp:
            methods_lines.append(f'- Retry interval: {bp["retry_interval"]} (from log)')
    elif bold_params_script:
        bp = bold_params_script
        if 'db' in bp:
            methods_lines.append(f'- DB: {bp["db"]} (from script)')
        if 'mode' in bp:
            methods_lines.append(f'- MODE: {bp["mode"]} (from script)')
        if 'thresholds' in bp:
            methods_lines.append(f'- Thresholds: {", ".join(map(str, bp["thresholds"]))} (from script)')
        if 'chunk_size' in bp:
            methods_lines.append(f'- Chunk size: {bp["chunk_size"]} (from script)')
        if 'workers' in bp:
            methods_lines.append(f'- Workers: {bp["workers"]} (from script)')
        if '_script_path' in bp and bp.get('_script_sha256'):
            methods_lines.append(f'- Script: {bp["_script_path"]} (SHA256 {bp["_script_sha256"][:12]}…)')
    methods_lines.append('')

    methods_path = snap_dir / 'METHODS.md'
    methods_path.write_text('\n'.join(methods_lines), encoding='utf-8')

    print(f"Snapshot written: {snap_dir}")


if __name__ == '__main__':
    main()


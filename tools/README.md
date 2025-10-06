Tools for post-run summarization without modifying original scripts

Overview
- This folder contains helper utilities that parse existing run logs and files to produce rich snapshots and METHODS documentation without editing your pipeline scripts.

Included
- generate_methods_snapshot.py — discovers logs/artifacts, extracts parameters, and writes `snapshots/<project>/snapshot.json` and `METHODS.md`.

Usage
1) Run your existing scripts as usual to produce logs and outputs under your project data directory (e.g., `<data>/bioinfo`).
2) Generate snapshot + methods:
   - Python: `python tools/generate_methods_snapshot.py --project-name <name> --project-data-dir <path-to-project-data>`

Notes
- BOLDigger parameters are taken from the boldigger log if present. If logs do not contain explicit parameters, the tool falls back to reading values from `scripts/03_BOLDigger_pipeline.sh` and includes a script SHA256 so you can verify correspondence with the run.
- QIIME parameters are parsed from `nextseq_processing.log`. The parser supports both the compact “Params: …” line and older individual messages.

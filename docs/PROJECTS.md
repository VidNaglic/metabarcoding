Projects Overview

- Neretva: finished (freeze outputs; keep logs for methods).
- Magistrska: largely complete (final checks and documentation left).
- Travniki: basic bioinformatics finished; downstream analysis pending.

Run Logs and Reproducibility

- Numbered scripts under `scripts/` define the canonical pipeline. Do not modify them; use environment variables or upstream data to vary runs.
- QIIME2 processing logs: created per-run at `${BIOINFO_ROOT}/run_YYYYMMDD_HHMMSS/nextseq_processing.log` and echoed to console.
- BOLDigger3 logs: `boldigger3_chunked.log` inside the results directory. Chunk outputs are resumable and merged into a single Parquet at the end.
- Keep all per-run folders in your data space (`data/`) and reference them in manuscripts to justify trimming, filtering, and thresholds.

Git/GitHub Hygiene

- Data and large artifacts are excluded via `.gitignore` to keep the repo lean and avoid leaking large files.
- Commit only scripts and small metadata required to run the pipeline; store all big outputs in `data/`.
- If needed, capture run parameters in a tiny `params.json` next to each run’s log.


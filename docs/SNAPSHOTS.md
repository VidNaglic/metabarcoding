Snapshots

- Purpose: freeze metadata about completed bioinformatics runs for each project without committing large data. Output lives under `snapshots/<project>/`.

How to Generate

- Neretva:
  - powershell -File scripts/make_snapshot.ps1 -ProjectName "Neretva" -ProjectDataDir "data/mtb_neretva"
- Magistrska:
  - powershell -File scripts/make_snapshot.ps1 -ProjectName "Magistrska" -ProjectDataDir "data/mtb_mag"
- Travniki:
  - powershell -File scripts/make_snapshot.ps1 -ProjectName "Travniki" -ProjectDataDir "data/mtb_travniki"

What It Captures

- Paths to canonical artifacts (COI table, feature table, rep-seqs, merged BOLD results)
- Locations of QIIME2 and BOLDigger logs
- Tool versions (if tools are on PATH)
- Key parameters parsed from the QIIME log (truncation, maxEE, cutadapt, primers)
- BOLDigger settings parsed from the pipeline script (DB, MODE, thresholds, chunk size, workers)
- Script signatures (SHA-256) for numbered scripts used in this repo
- Git commit/branch at snapshot time (if `.git/` present)

Notes

- The script looks for the latest `run_*` folder under the project’s `bioinfo` directory to find logs.
- It writes both a human-readable `METHODS.md` and a machine-readable `snapshot.json` under `snapshots/<project>/`.
- Data files remain in `data/` and are not committed to Git.

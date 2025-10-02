Neretva — Bioinformatics Methods Snapshot

Summary
- Pipeline executed via numbered scripts (01–04) without modifications.
- Outputs frozen under project data directories; this repo stores only methods metadata.

Key Artifacts (paths)
- QIIME2 table (QZA): C:\Users\vidna\Documents\mtb\data\mtb_neretva\bioinfo\COI-table.qza
- Feature table (TSV): C:\Users\vidna\Documents\mtb\data\mtb_neretva\bioinfo\feature-table.tsv
- Rep-seqs (validated FASTA): C:\Users\vidna\Documents\mtb\data\mtb_neretva\bioinfo\exported-filtered\dna-sequences-validated.fasta
- BOLDigger merged parquet: C:\Users\vidna\Documents\mtb\data\mtb_neretva\bioinfo\exported-filtered\boldigger3_data\dna-sequences-validated_identification_result.parquet.snappy

Logs
- QIIME2 processing log: not captured in latest snapshot (run folder not found)
- BOLDigger3 log: C:\Users\vidna\Documents\mtb\data\mtb_neretva\bioinfo\exported-filtered\boldigger3_data\boldigger3_chunked.log

Notes for Manuscript
- Refer to the Feature table (TSV) and merged BOLD parquet as the basis for downstream taxonomic summaries and trait joins.
- If exact trimming/denoising parameters are required, reference the QIIME2 run folder used originally; future runs should preserve the per-run log under bioinfo/run_YYYYMMDD_HHMMSS.


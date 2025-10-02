Travniki — Bioinformatics Methods Snapshot

Summary
- Pipeline executed via numbered scripts (01–04) without modifications.
- Outputs frozen under project data directories; this repo stores only methods metadata.

Key Artifacts (paths)
- QIIME2 table (QZA): C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\COI-table.qza
- Feature table (TSV): C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\feature-table.tsv
- Rep-seqs (validated FASTA): C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\dna-sequences-validated.fasta
- BOLDigger merged parquet: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\boldigger3_data\dna-sequences-validated_identification_result.parquet.snappy

Logs
- QIIME2 processing log: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\run_20250904_155334\nextseq_processing.log
- BOLDigger3 log: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\boldigger3_data\boldigger3_chunked.log

Parameters (from log)
- trunc-len R1: 145
- maxEE R1: 2
- Cutadapt error rate: 0.1
- Cutadapt min overlap: 10

Notes for Manuscript
- Use the feature table (TSV) and merged BOLD parquet as primary inputs for taxonomic summaries and further analyses.
- Parameters above are extracted from the QIIME2 run log `run_20250904_155334`.


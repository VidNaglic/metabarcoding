Project
- Name: Travniki
- Data root: C:\Users\vidna\Documents\mtb\data\mtb_travniki

Pipeline
- Numbered scripts (01-04) executed as per repo.
- QIIME 2 concluded with COI table and rep-seqs; exports created.
- BOLDigger3 run in chunked mode; results merged to a single parquet.

Key Artifacts
- QIIME table: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\COI-table.qza
- Feature table (TSV): C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\feature-table.tsv
- Rep-seqs (validated FASTA): C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\dna-sequences-validated.fasta
- BOLDigger merged parquet: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\boldigger3_data\dna-sequences-validated_identification_result.parquet.snappy

Logs
- QIIME2 log: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\run_20250904_155334\nextseq_processing.log
- BOLDigger log: C:\Users\vidna\Documents\mtb\data\mtb_travniki\bioinfo\exported-filtered\boldigger3_data\boldigger3_chunked.log

Run Parameters
- trunc-len R1: 145
- maxEE R1: 2
- Cutadapt error rate: 0.1
- Cutadapt min overlap: 10

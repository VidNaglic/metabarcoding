Project
- Name: Travniki
- Data root: /mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki

Pipeline
- QIIME 2 → COI table and representative sequences; exports generated.
- BOLDigger3 run in chunked mode; parts merged to one parquet.

Key Artifacts
- QIIME table: /mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/COI-table.qza
- Feature table (TSV): /mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/feature-table.tsv
- Rep-seqs (validated FASTA): /mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/dna-sequences-validated.fasta
- BOLDigger merged parquet: /mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/bioinfo/exported-filtered/boldigger3_data/dna-sequences-validated_identification_result.parquet.snappy

QIIME2 Parameters
- trunc-len R1: 145
- maxEE R1: 2

BOLDigger Settings
- Thresholds: 97,95,90,85 (from log)

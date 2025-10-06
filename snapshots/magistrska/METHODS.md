Project
- Name: Magistrska
- Data root: /mnt/c/Users/vidna/Documents/mtb/data/mtb_mag

Pipeline
- QIIME 2 → COI table and representative sequences; exports generated.
- BOLDigger3 run in chunked mode; parts merged to one parquet.

Key Artifacts
- QIIME table: /mnt/c/Users/vidna/Documents/mtb/data/mtb_mag/bioinfo/COI-table.qza
- Feature table (TSV): /mnt/c/Users/vidna/Documents/mtb/data/mtb_mag/bioinfo/feature-table.tsv
- Rep-seqs (validated FASTA): data/mtb_mag/bioinfo/exported-filtered/dna-sequences-validated.fasta
- BOLDigger merged parquet: /mnt/c/Users/vidna/Documents/mtb/data/mtb_mag/bioinfo/boldigger3-results/dna-sequences-validated_identification_result.parquet.snappy

QIIME2 Parameters
- trunc-len R1: 230
- maxEE R1: 2.0
- trim-left R1: 20
- DADA2 threads: 8

BOLDigger Settings
- DB: 3                     # 1–8 (3 = animal library public+private) (from script)
- MODE: 3                   # 1=rapid, 2=genus+species, 3=exhaustive (from script)
- Thresholds: 97,95,90,85 (from script)
- Chunk size: 120           # 80–150 is typical (from script)
- Workers: 1 (from script)

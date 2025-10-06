Project
- Name: Neretva
- Data root: /mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva

Pipeline
- QIIME 2 → COI table and representative sequences; exports generated.
- BOLDigger3 run in chunked mode; parts merged to one parquet.

Key Artifacts
- QIIME table: /mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/COI-table.qza
- Feature table (TSV): /mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/feature-table.tsv
- Rep-seqs (validated FASTA): data/mtb_neretva/bioinfo/exported-filtered/dna-sequences-validated.fasta
- BOLDigger merged parquet: /mnt/c/Users/vidna/Documents/mtb/data/mtb_neretva/bioinfo/exported-rep-seqs/dna-sequences-validated_identification_result.parquet.snappy

BOLDigger Settings
- DB: 3                     # 1–8 (3 = animal library public+private) (from script)
- MODE: 3                   # 1=rapid, 2=genus+species, 3=exhaustive (from script)
- Thresholds: 97,95,90,85 (from script)
- Chunk size: 120           # 80–150 is typical (from script)
- Workers: 1 (from script)

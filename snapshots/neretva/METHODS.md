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
- BOLDigger merged parquet: data/mtb_neretva/bioinfo/exported-filtered/boldigger3_data/dna-sequences-validated_identification_result.parquet.snappy

BOLDigger Settings

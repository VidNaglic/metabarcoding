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
- BOLDigger merged parquet: data/mtb_mag/bioinfo/exported-filtered/boldigger3_data/dna-sequences-validated_identification_result.parquet.snappy

BOLDigger Settings

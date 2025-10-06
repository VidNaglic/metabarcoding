Methods — Neretva (artifacts present; limited logs)

Paired-end Illumina reads were processed in QIIME 2, following standard practice: reads were imported via a manifest and inspected with demux summarize to guide trimming; DADA2 denoise-paired performed filtering, error correction, merging, chimera removal and dereplication to produce ASVs. Per-run parameter details are not available in a dedicated project log for this dataset.

Available artifacts
- QIIME outputs: data/mtb_neretva/bioinfo/COI-table.qza; feature-table.(biom|tsv)
- Representative sequences and BOLD results: data/mtb_neretva/bioinfo/exported-rep-seqs/

Taxonomic assignment
- BOLDigger v3 was used to generate merged identification results (Parquet/XLSX present under exported-rep-seqs). Default identity thresholds (97 %, 95 %, 90 %, 85 %) and exhaustive search mode (mode 3; DB 3) are assumed based on current pipeline configuration; no project-local BOLDigger log was found for confirmation.

References
- Bolyen et al. 2019; Callahan et al. 2016; Buchner & Leese 2020; Buchner & Shah 2025.


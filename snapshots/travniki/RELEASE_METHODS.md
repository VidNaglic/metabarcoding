Methods — Travniki (exact per-run settings)

Paired-end Illumina reads were processed with QIIME 2 (v2023.5) following the official installation and usage guidelines. Reads were imported in Casava format and quality-checked with demux summarize to guide trimming. Primer/adapters were removed with cutadapt in paired mode (error-rate 0.1, min-overlap 10, read-wildcards enabled). After trimming, analyses proceeded on the forward reads only using DADA2 via qiime dada2 denoise-single, which performs quality filtering, error correction and chimera removal to produce ASVs.

Exact QIIME 2 parameters for this run
- denoise-single (R1): trim-left = 0 bp; trunc-len = 145 bp; max-EE = 2; threads = 1; trunc-Q = default
- cutadapt (paired): error-rate = 0.1; min-overlap = 10; match-read-wildcards = true
- Per-run log: data/mtb_travniki/bioinfo/run_20250904_155334/nextseq_processing.log

Taxonomic assignment
- BOLDigger v3 (exhaustive mode; DB = 3). Default identity thresholds applied: 97 %, 95 %, 90 %, 85 % for species, genus, family and order, respectively (as recorded in the BOLDigger log for this run).
- Per-run log: data/mtb_travniki/bioinfo/exported-filtered/boldigger3_data/boldigger3_chunked.log

Downstream handling
- Per-chunk identification results were merged to a single Parquet and joined to the QIIME 2 ASV table for subsequent filtering and analyses.

References
- Bolyen et al. 2019; Callahan et al. 2016; Buchner & Leese 2020; Buchner & Shah 2025.


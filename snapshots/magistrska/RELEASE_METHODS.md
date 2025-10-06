Methods — Magistrska (recovered from logs)

Paired-end Illumina reads were processed in QIIME 2, following standard practice: reads were imported via a manifest and inspected with demux summarize to guide trimming. Primer sequences and low-quality leading bases were removed by trimming 20 bp from the 5′ end of both reads. DADA2 denoise-paired then performed filtering, error correction, merging, chimera removal and dereplication to produce ASVs.

Exact QIIME 2 parameters (from scripts/processing.log)
- denoise-paired: trim-left F/R = 20/20 bp; trunc-len F/R = 230/180 bp; max-EE F/R = 2.0/2.0; trunc-Q = 2; min-overlap = 12; pooling = independent; chimera method = consensus; threads = 8
- Source log: scripts/processing.log (matching Data Directory for this project)

Taxonomic assignment
- BOLDigger v3 (exhaustive mode; DB = 3). Default identity thresholds applied: 97 %, 95 %, 90 %, 85 % for species, genus, family and order, respectively.
- Note: No project-local BOLDigger log was found; settings are reported from script defaults and verified by presence of merged identification outputs under data/mtb_mag/bioinfo/boldigger3-results.

Downstream handling
- Per-batch identification results were merged and linked to the QIIME 2 ASV table for subsequent filtering and analyses.

References
- Bolyen et al. 2019; Callahan et al. 2016; Buchner & Leese 2020; Buchner & Shah 2025.


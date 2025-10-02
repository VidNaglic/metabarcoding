#!/usr/bin/env Rscript
library(dada2)

# point to your fastq folder
fwd <- sort(list.files("/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/fastq",
                       pattern="_R1_001.fastq.gz$", full.names=TRUE))
rev <- sort(list.files("/mnt/c/Users/vidna/Documents/mtb/data/mtb_travniki/fastq",
                       pattern="_R2_001.fastq.gz$", full.names=TRUE))

# prepare output filenames
dir.create("filt_check", showWarnings=FALSE)
outF <- file.path("filt_check", basename(fwd))
outR <- file.path("filt_check", basename(rev))

# run FILTER ONLY, single-threaded
res <- filterAndTrim(fwd, outF, rev, outR,
                     trimLeft=20,
                     truncLen=c(207,156),
                     maxEE=c(2,2),
                     truncQ=2,
                     multithread=FALSE,    # <— run sequentially
                     verbose=TRUE)

print(res)
zeros <- res[ res[,2]==0 | res[,4]==0, ]
if(nrow(zeros)>0){
  cat("⚠ These samples lost ALL reads during filtering:\n")
  print(zeros)
} else {
  cat("✅ All samples retained ≥1 read through filtering.\n")
}

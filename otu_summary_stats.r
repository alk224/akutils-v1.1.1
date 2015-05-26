#!/usr/bin/env Rscript

## Recieve input file from bash
args <- commandArgs(TRUE)
d <- read.table(args[1], sep="\t")

## extract counts and produce summary stats

titles <- c("mean", "median", "min", "max")
otu_counts <- d[,2]
stats <- c(mean(otu_counts), median(otu_counts), min(otu_counts), max(otu_counts))

result = data.frame(stat = (titles), value = (stats))

## write result to output file

write.table(result, file = "otus_per_taxon_summary.txt", quote = FALSE, col.names = TRUE, sep = "\t", row.names = FALSE)



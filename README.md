# RNA-seq Analysis Pipeline (STAR & Salmon)

This repository contains the configuration and execution scripts for running RNA-sequencing data processing using the `nf-core/rnaseq` (v3.17.0) pipeline.

## Overview

The analysis is divided into two main execution paths to optimize server resource usage and separate the output results:
1. **STAR Alignment (`star.sh`)**: Performs rigorous genome alignment and read quantification.
2. **Salmon Pseudo-alignment (`salmon.sh`)**: Performs ultra-fast transcript quantification.

## Batched Execution

To avoid overloading the server's compute and memory resources (96 cores, 1TB RAM), the 39 patient samples have been split into two batches:
- `samplesheet_batch1.csv`: First 25 samples.
- `samplesheet_batch2.csv`: Remaining 14 samples.
- `samplesheet.csv`: Backup combining all 39 samples.

## Requirements
- **Nextflow**: version 24.04.x LTS or 25.04.x
- **Singularity/Apptainer**: For containerized execution of pipeline tools.
- **Reference Genome**: GRCh38 primary assembly (symlinked in the data directory).

## Usage
Run the pipeline in a background process or `tmux`/`screen` session:

```bash
# Execute STAR mapping for Batch 1
./star.sh

# Execute Salmon quantification for Batch 1 (Run this sequentially AFTER star finishes to prevent resource exhaustion)
./salmon.sh
```

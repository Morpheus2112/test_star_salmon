export NXF_SINGULARITY_CACHEDIR=$(realpath ./singularity/ )

./nextflow-24 run nf-core/rnaseq \
  -profile singularity \
  -r 3.17.0 \
  --max_cpus 16 \
  --max_memory 100.GB \
  --input samplesheet.csv \
  --outdir results_salmon_pseudo_batch1 \
  -work-dir work_salmon_batch1 \
  --fasta GRCh38.primary_assembly.genome.fa \
  --gtf gencode.v39.annotation.gtf \
  --gencode \
  --skip_alignment \
  --pseudo_aligner salmon \
  --skip_multiqc --skip_preseq --skip_biotype_qc \
  --skip_qualimap --skip_dupradar --skip_rseqc \
  --skip_deseq2_qc --skip_markduplicates \
  --skip_stringtie --skip_bigwig

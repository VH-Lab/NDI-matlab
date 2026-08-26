# geneList

The `geneList` document class stores the ordered gene dictionary that a
gene expression dataset is indexed against. It holds no counts. Its only
job is to give a stable meaning to the integer `gene_index` values stored
in other documents.

## Why it is separate

A gene index is meaningless without the list it indexes. Storing the list
as its own document, rather than as a file on each dataset, has three
consequences:

1. **Datasets that share an annotation share one document.** All levels of
   a `spatialGeneExpressionPyramid` index the same list, and a dissociated
   RNA-seq dataset built from the same GTF can point at it too.
2. **Datasets that do not share an annotation cannot silently pretend to.**
   Two datasets with different gene lists depend on different `geneList`
   documents, so combining them requires an explicit `geneListMapping`
   rather than an implicit assumption that index *i* means the same gene
   in both.
3. **Rebuilding counts does not rewrite the dictionary.** The list has its
   own identity and version.

Gene lists differ more often than they match. A spatial assay and a
dissociated atlas of the same tissue routinely disagree in gene count, in
identifier namespace (Ensembl accession versus official symbol), and in
symbol completeness — a Stereo-seq GEF commonly leaves 10-20 percent of
`geneName` entries blank. Treat a match as something to verify, not
assume.

## Files

* **genes.tsv**

Tab-separated, uncompressed, one header row. The `gene_index` column is
the value stored in other documents and MUST be the 0-based row number.
It is written explicitly so a reader can verify it rather than assume row
order survived transport — a silent re-sort would mislabel every count
that references this list with no error raised anywhere.

```
gene_index	gene_id	gene_name
0	ENSMODG00000020019	A1CF
1	ENSMODG00000003447	Pvalb
```

`gene_id` is the stable accession in `gene_id_namespace`; `gene_name` is
the human-readable symbol in `gene_symbol_namespace` and may be empty.
Uncompressed because the file is a few megabytes against a multi-gigabyte
dataset, and plain text keeps it readable by `readtable`,
`pandas.read_csv`, and `grep` with no decode step.

## Fields

### label

A human-readable label for this gene list.

### n_genes

The number of data rows in `genes.tsv`. Every `gene_index` referring to
this list must be less than this value.

### genome_assembly

The reference genome assembly the annotation was built against (e.g.
`monDom5`, `GRCm39`).

This describes the **annotation**, not the animal. The subject's species
belongs in an `animalsubject` or `openminds_subject` document depending
on `subject_id`, per NDI convention, and duplicating it here would create
a second place for it to be wrong. The assembly is recorded because it,
together with `annotation_source`, is what actually determines the gene
set — and because a gene list is a property of a reference, not of any
one animal, so it can legitimately be used with subjects of a different
species during cross-species work.

### gene_id_namespace, gene_symbol_namespace

The identifier systems of the two columns. Two lists in different
namespaces cannot be compared without a `geneListMapping`, even when they
describe the same species.

### annotation_source

Identifier of the genome annotation (GTF/GFF) the list came from,
including any modification. Counts assigned against a modified annotation
are not reproducible without knowing which one was used.

### gene_name_completeness

Fraction of rows with a non-empty `gene_name`. A reader that keys on
symbols rather than accessions needs to know how much of the list it will
fail to match.

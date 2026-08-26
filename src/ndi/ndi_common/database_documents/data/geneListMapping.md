# geneListMapping

The `geneListMapping` document class stores a correspondence between the
genes of two `geneList` documents, so that datasets indexed against
different gene lists can be combined.

## Two kinds of correspondence

`mapping_type` distinguishes them, and the distinction is not cosmetic:

* **`alias`** — the two rows denote the **same gene** under different
  identifier systems. An Ensembl accession and an official symbol for one
  gene. This is a lossless renaming; applying it changes nothing about the
  data.
* **`ortholog`** — the two rows denote **different genes, in different
  species**, inferred to be homologous. This is a biological inference
  produced by a method with assumptions and failure modes. It can be
  wrong, it is frequently many-to-many, and a gene may have no counterpart
  at all.

Treating an `ortholog` mapping as an `alias` silently converts an
inference into an assertion. A reader that joins two datasets must branch
on this field.

## Files

* **mapping.tsv**

Tab-separated, uncompressed, one header row. One row per corresponding
pair; a gene may appear in many rows, so the mapping is a relation, not a
function in either direction.

```
gene_index_a	gene_index_b	score
417	1902	
418	2044	
418	2045	
```

`gene_index_a` indexes the `geneList` named by `geneList_id_a`, and
likewise for b. The `score` column is present only when `has_score` is 1;
for an orthology mapping it typically carries a confidence or alignment
score, and rows should be read as candidates ranked by it rather than as
settled facts.

## Fields

### label

A human-readable label for this mapping.

### mapping_type

`alias` or `ortholog`, as described above.

### method

How the mapping was produced, specifically enough to reproduce it — the
tool and its version, not just its name.

### symmetric

1 if the mapping may be applied in either direction, 0 if it is only
valid from list a to list b.

### n_pairs

The number of data rows in `mapping.tsv`.

### n_genes_mapped_a, n_genes_mapped_b

How many distinct genes of each list appear at least once. Compare
against each list's `n_genes` to see coverage; a mapping that covers half
of one list will silently drop half the data of any analysis that uses
it, so coverage belongs in the document rather than being rediscovered
each time.

### has_score

1 if `mapping.tsv` carries a `score` column.

## Dependencies

* **geneList_id_a**, **geneList_id_b**: the two gene lists related by this
  mapping.

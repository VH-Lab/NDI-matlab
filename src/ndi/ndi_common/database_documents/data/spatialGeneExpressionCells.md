# spatialGeneExpressionCells

The `spatialGeneExpressionCells` document class stores segmented cells
for a spatial gene expression dataset: one centroid per cell, an optional
boundary polygon per cell, and per-cell quality measures. It carries no
labels and no counts.

## Model

Cells sit in the same coordinate frame as the pyramid they depend on, so
placing them requires that pyramid's `origin_x` and `origin_y`. That is
why those fields are required rather than optional.

Cell type calls are **not** stored here. They live in `cellTypeLabels`
documents that depend on this one. The separation is deliberate:
geometry comes from the expression data plus a stain image, while a
transferred label comes from a third source entirely, and one
segmentation commonly carries several competing labelings whose
membership varies by species. A single document cannot express those
different parentages honestly, and bundling them would mean rewriting
geometry to revise a label.

## Files

* **cells.tsv** — one row per cell
* **contours.bin** — boundary polygons, present only when
  `contours_present` is 1

### cells.tsv

Tab-separated, uncompressed, one header row. `cell_index` is the 0-based
row number and is the key that `contours.bin` and every `cellTypeLabels`
document reference. `cell_id` preserves the identifier from the source
file so a cell can be traced back to it.

```
cell_index	cell_id	x	y	area	dnb_count	total_counts	n_genes
0	10093173156650	4821	7734	118	96	312	187
```

`x` and `y` are the centroid in `coordinate_units`.

### contours.bin (contour_format_version 1)

All values use the pyramid's `byte_order`. Types are named by the
`data_type_*` fields.

| field | type | count |
|---|---|---|
| `n_cells` | `data_type_offset` | 1 |
| `n_vertices_total` | `data_type_offset` | 1 |
| `offset` | `data_type_offset` | `n_cells + 1` |
| `vx` | `data_type_vertex` | `n_vertices_total` |
| `vy` | `data_type_vertex` | `n_vertices_total` |

Cell *i* has vertices `offset[i] : offset[i+1]`. The polygon is closed
implicitly; the first vertex is not repeated.

Contours are **ragged**, which is why an offset array is present. Source
formats often store a fixed-width padded array instead — SAW writes a
32-slot array per cell with a sentinel in unused slots, and roughly two
thirds of the slots are padding. Padding is stripped on ingest, which
removes the sentinel from the format entirely and makes the file about
2.6 times smaller than the padded form.

When `n_vertices_per_cell` is a positive value, every cell has exactly
that many vertices, no `offset` array is present, and vertex *j* of cell
*i* is at position `i * n_vertices_per_cell + j`.

## Fields

### label

A human-readable label for this segmentation.

### n_cells

The number of data rows in `cells.tsv`.

### segmentation_method

How cells were segmented, with version. Worth stating plainly in the
label as well: Stereo-seq CellBin segments **nuclei** from the stain
image and dilates outward, so a "cell" here is a nucleus plus a margin,
not a measured cell body. Analyses that assume a true cell boundary need
to know this.

### segmentation_dilation

The radial expansion applied to each segmented nucleus, in
`coordinate_units`. 0 if none.

### coordinate_units

The units of the centroid and contour coordinates. These are the
**source** coordinate units — DNB chip units for Stereo-seq — matching
the pyramid's `origin_x` and `origin_y`. They are not micrometers unless
this field says so.

### contours_present

1 if `contours.bin` was written.

### contour_reference

`centroid` if vertices are stored relative to their cell's centroid,
`absolute` if in source coordinates. Recording this removes the need to
infer it from vertex magnitude, which is what reading the source h5ad
otherwise requires and which can be guessed wrong.

### n_vertices_per_cell

0 for ragged contours with an offset array, which is the normal case. A
positive value means fixed-stride contours with no offset array.

### data_type_vertex, data_type_offset

Integer types of the contour arrays. `int16` suffices for
centroid-relative vertices at cellular scale.

### contour_format_version

The version of the binary layout described above.

## Dependencies

* **spatialGeneExpressionPyramid_id**: the dataset these cells were
  segmented from, and the source of the coordinate frame.
* **subject_id**: the subject the tissue came from.
* **source_file_id**: optional, for provenance back to the file the
  segmentation was read from.

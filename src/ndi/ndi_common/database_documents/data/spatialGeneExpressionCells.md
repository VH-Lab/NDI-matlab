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

## Measured behaviour

Values below are measured on a real SAW cellbin (opossum V1,
`cellbin_1.0.adjusted.labeled.h5ad`, 80,369 cells) rather than assumed.

| what | measured |
|---|---|
| `obsm['cell_border']` | `(80369, 32, 2)`, dtype `int64` |
| padding sentinel | `32767`, filling 67% of slots |
| real vertices per cell | min 4, median 10, **max 24** |
| `contour_reference` | `centroid` (median vertex 10 against a centroid scale of 9,695) |
| `n_vertices_per_cell` | **0** — ragged |

Three consequences.

**The source array is far larger than the information in it.** It
allocates 32 slots where at most 24 are ever used, fills two thirds with
a sentinel, and stores in `int64` values that fit in `int16`. Stripping
the padding and narrowing the type shrinks contours by roughly twenty
times, which is why this document stores them ragged rather than
mirroring the source layout.

**Stored contours are not guaranteed renderable.** They are traced from a
segmentation mask, not idealised, so they contain repeated vertices and
occasional self-intersections. A consumer must add them as OUTLINES --
paths -- and not as filled polygons: a renderer that triangulates faces
will reject them, and one bad contour among eighty thousand is enough to
lose the whole layer. Rendered as closed paths, 80,369 outlines build in
about five seconds.

**Placing cells uses the centroid, not the origin.** See the coordinate
rule below; getting it wrong displaces every cell by exactly the origin,
which looks plausible and is not.

## The coordinate rule

Contours are stored relative to their cell's centroid, and centroids are
in source coordinate units. A source coordinate `(x, y)` reaches world
position by multiplying by the pixel size alone:

    world_x = x * pixel_size_x        world_y = y * pixel_size_y

`origin_x` and `origin_y` on the pyramid say where the tiled region
begins in source coordinates. They are **not** subtracted when placing
cells. Whatever positions the raster -- a viewer's translate, or an
offset applied when reading tiles -- already accounts for the origin, so
subtracting it again here removes it once and adds it once, leaving every
cell displaced from the expression data by exactly the origin. That
failure is silent: both layers look internally correct and simply
disagree about where zero is.

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

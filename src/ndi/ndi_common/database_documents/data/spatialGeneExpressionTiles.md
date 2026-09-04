# spatialGeneExpressionTiles

The `spatialGeneExpressionTiles` document class stores one resolution level of a
spatially tiled gene expression pyramid. Each level is a sparse
(pixel x gene) count matrix cut into rectangular tiles, one binary file
per tile, so that a viewer can fetch a viewport without reading the
whole level.

It is the spatial counterpart to `pyraview`. Where `pyraview` stores one
whole file per decimation level and seeks to a sample range inside it,
`spatialGeneExpressionTiles` stores many files per level and selects among them,
because the seek-inside-a-file model does not survive an interface that
can only retrieve whole files.

## Model

A `spatialGeneExpressionPyramid` document owns the shared identity: the
gene list it is indexed against, the coordinate origin, the tile grid, and the list of bin
sizes. One `spatialGeneExpressionTiles` document exists per bin size, each
depending on that parent. Levels are siblings rather than a chain, so
enumerating them is a single query and no level orphans another.

The tile grid (`tile_rows`, `tile_columns`) is **identical at every
level**, which is unusual for a pyramid. It follows from the data: as
bin size grows the number of occupied pixels falls but the number of
genes detected per pixel rises almost as fast, so total nonzeros are
nearly constant down the pyramid and every level wants comparable
tiling. The useful consequence is that tile (row, column) covers the
same physical region at every level, so a viewport maps to tile indices
once, independent of zoom.

## Measured behaviour

The defaults are measured on a real Stereo-seq section (opossum V1,
18126 x 18968 bin1 units, 30,434 genes, 120,966,551 records) rather than
estimated. Every stored tile was measured, not sampled.

| level | size | tiles | median tile | largest tile | level total |
|---|---|---|---|---|---|
| bin1  | 18126 x 18968 | 74 / 81 | 11.57 MB | 46.78 MB | 1195.0 MB |
| bin2  |  9063 x  9484 | 74 / 81 |  9.59 MB | 37.46 MB |  964.9 MB |
| bin4  |  4532 x  4742 | 74 / 81 |  7.65 MB | 31.22 MB |  782.5 MB |
| bin8  |  2266 x  2371 | 74 / 81 |  6.61 MB | 28.57 MB |  707.5 MB |
| bin16 |  1133 x  1186 | 74 / 81 |  6.13 MB | 26.36 MB |  653.7 MB |
| bin32 |   567 x   593 | 74 / 81 |  5.43 MB | 22.99 MB |  577.3 MB |

Four consequences worth carrying into any implementation.

**A coarse level costs nearly as much as a fine one.** bin32 is a 32x
linear downsample and still costs 48% of bin1, because coarsening trades
occupied pixels for genes detected per pixel: fewer pixels, but each
holding more of the gene axis. The whole pyramid is **4.1 times** the base
level rather than the 4/3 an image pyramid costs. That is also why the
tile grid is constant across levels -- every level wants comparable
tiling, so tile (row, column) can cover the same physical region at every
zoom.

**The largest tile is about four times the median** -- 46.78 against
11.57 MB at bin1 -- because tissue does not fill a rectangle. Size the
grid from the largest tile; a grid chosen from the median will be
exceeded in the middle of the section.

**A 9 x 9 grid is only just adequate for a section this size.** The
largest tile reaches 46.78 MB against the 50 MB per-file budget the grid
was sized for -- 94% of it, with 3.2 MB to spare. A denser section, or one
with more genes, will exceed it. `tile_rows` and `tile_columns` are
per-document fields precisely so this can be raised without a format
change; 10 x 10 gives roughly 38 MB on this section.

> Earlier revisions of this table reported per-level *nonzero* counts and
> a "17% falloff" derived from them. Those came from a build whose sort
> key overflowed int32, silently merging distinct (pixel, gene) pairs, so
> they understated every figure by about 1%. The byte measurements above
> replace them and are what the grid is actually sized against. The
> corrected per-level nonzero counts have not been re-measured; at bin1 it
> is 120,966,551, the full record count, because that section turns out to
> contain no genuine duplicate (pixel, gene) pairs at all.

**A reader must crop each level to `dimension_size`.** Tiles are laid out
on a `tile_rows` by `tile_columns` grid, so the assembled array is
`tile_rows * tile_size_y_bins` by `tile_columns * tile_size_x_bins`, which
overshoots the level whenever its dimensions do not divide evenly by the
grid. Left uncropped, a level covers more ground than the extent it
claims, levels of one pyramid disagree about their own field of view, and
a viewer registering them by scale and translate misaligns them -- worse
at coarse levels, where the rounding is proportionally larger. It also
dilutes mean density: on one 8192-wide section a 1,5,10,20,50 ladder
padded bin50 from 164 to 168 columns and diluted the mean by 4.9%. The
level's true size is in `dimension_size`; slice to it.

**Prefer a uniform, small ratio between levels.** `bin_sizes` defaults to
a dyadic ladder for a measurable reason rather than convention. Binning
preserves mean density but not the distribution: at the finest level a
nonzero pixel holds one or two counts, while at bin N the same density
arrives spread across N^2 pixels, so the peak falls by roughly the step's
AREA factor while the mean does not move. With a single contrast range
per layer, that area factor is the brightness discontinuity a viewer shows
at each transition -- 4x for a doubling, 25x for a five-fold step.
Measured on one section, the 99th percentile of nonzero density fell
0.54x across the worst dyadic transition and 0.31x across the worst
1,5,10,20,50 one, and the latter was visibly jumpy where the former was
not.

**Do not display summed counts directly.** Binning sums, so a level is
bin_size^2 brighter than the one below it, and a viewer carrying a
single contrast range per layer (napari does) cannot serve every level.
Dividing by bin_size^2 at render time gives counts per base pixel, and
makes mean intensity identical across levels. Nothing changes on disk:
tiles stay raw integer counts and the divisor comes from bin_size.

## Files

* **tile.bin_#** — one file per stored tile

The gene dictionary is **not** a file of this document. It lives in the
`geneList` document that the parent pyramid depends on, so that a
dissociated RNA-seq dataset built on the same annotation can share it.

`#` is a non-negative integer computed from the tile's (row, column) by
the parent's `index_order`; for `row-major` it is
`row * tile_columns + column`. Tiles containing no data are not written.
Use `ndi.document/current_file_list` to discover which tiles exist —
there is no separate index file.

### tile.bin_N layout (tile_format_version 1)

All values use the parent's `byte_order`. Types are named by the
`data_type_*` fields rather than fixed here, so a level can widen a field
without a new format version.

| offset | field | type | count |
|---|---|---|---|
| 0 | `n_pixels` | `data_type_offset` | 1 |
| | `n_nonzero` | `data_type_offset` | 1 |
| | `x` | `data_type_coordinate` | `n_pixels` |
| | `y` | `data_type_coordinate` | `n_pixels` |
| | `offset` | `data_type_offset` | `n_pixels + 1` |
| | `gene_index` | `data_type_gene_index` | `n_nonzero` |
| | `count` | `data_type_count` | `n_nonzero` |

`x` and `y` are tile-local pixel coordinates, in pixels of this level,
relative to the tile's upper-left corner. Absolute position is
`origin + (tile_column * tile_size_x_bins + x) * bin_size` in base pixel
units, and likewise for y.

Rows are pixels, in the order given by `x`/`y`. Pixel `i` holds the
nonzero genes `gene_index[offset[i] : offset[i+1]]` with the matching
entries of `count`. This is CSR over occupied pixels: it stores each
pixel's coordinate once rather than once per transcript, which is why a
tiled pyramid is smaller than the source GEF it was built from despite
holding the same counts.

Every tile carries the full gene axis. A viewer downloads a tile once
and can then toggle any gene on or off with no further transfer.

## Fields

### label

A string label for this level, e.g. `bin20`.

### bin_size

The edge length of one pixel of this level in base pixel units. `1` is
native resolution. Must appear in the parent's `bin_sizes`.

### pixel_size_x, pixel_size_y, pixel_size_units

The physical size of one pixel of this level. Equal to `bin_size` times
the parent's `base_pixel_size_x` / `base_pixel_size_y`. Stored rather
than only derived so a reader never has to consult the parent to place
data in space.

### dimension_order, dimension_labels, dimension_size, dimension_scale, dimension_scale_units

The axis description for the whole level, following the
`imageStack_parameters` convention, with `G` denoting the gene
dimension. `dimension_size` is the level's full extent in pixels plus
the gene count, not a per-tile size.

### tile_size_x_bins, tile_size_y_bins

The size of one tile in pixels of this level. Edge tiles may be
partially filled when the extent is not an exact multiple.

### n_tiles_stored

How many tile files were written. Less than
`tile_rows * tile_columns` when empty tiles were omitted.

### data_type_gene_index, data_type_count, data_type_offset, data_type_coordinate

The integer types of the four arrays in the tile layout above.
`data_type_gene_index` must be wide enough for the geneList's `n_genes`;
prefer `uint32` over `uint16` even when the gene count would fit, since
gene counts near 65535 are common and leave no margin.

### tile_compression

`none` or `gzip`, applied to the tile file as a whole.

### tile_format_version

The version of the binary layout described above.

## Dependencies

* **spatialGeneExpressionPyramid_id**: the pyramid this level belongs to.
* **subject_id**: the subject the tissue came from. Present on each level
  as well as the parent so a level is independently queryable by subject.
* **source_file_id**: optional. The `generic_file` or other document
  holding the file this level was built from, for provenance.

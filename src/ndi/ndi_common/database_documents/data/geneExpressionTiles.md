# geneExpressionTiles

The `geneExpressionTiles` document class stores one resolution level of a
spatially tiled gene expression pyramid. Each level is a sparse
(pixel x gene) count matrix cut into rectangular tiles, one binary file
per tile, so that a viewer can fetch a viewport without reading the
whole level.

It is the spatial counterpart to `pyraview`. Where `pyraview` stores one
whole file per decimation level and seeks to a sample range inside it,
`geneExpressionTiles` stores many files per level and selects among them,
because the seek-inside-a-file model does not survive an interface that
can only retrieve whole files.

## Model

A `geneExpressionPyramid` document owns the shared identity: the gene
dictionary, the coordinate origin, the tile grid, and the list of bin
sizes. One `geneExpressionTiles` document exists per bin size, each
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

## Files

* **genes.tsv** (on the parent `geneExpressionPyramid`)
* **tile.bin_#** — one file per stored tile

`#` is a non-negative integer computed from the tile's (row, column) by
the parent's `index_order`; for `row-major` it is
`row * tile_columns + column`. Tiles containing no data are not written.
Use `ndi.document/current_file_list` to discover which tiles exist —
there is no separate index file.

### genes.tsv

Tab-separated, uncompressed, one header row. The `gene_index` column is
the value stored in each tile's `gene_index` array and MUST be the
0-based row number; it is written explicitly so a reader can verify it
rather than assume row order survived transport.

```
gene_index	gene_id	gene_name
0	ENSMODG00000020019	A1CF
1	ENSMODG00000003447	Pvalb
```

Uncompressed because the file is a few megabytes against a multi-gigabyte
pyramid, and staying plain text keeps it readable by `readtable`,
`pandas.read_csv`, and `grep` with no decode step.

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
`data_type_gene_index` must be wide enough for the parent's `n_genes`;
prefer `uint32` over `uint16` even when the gene count would fit, since
gene counts near 65535 are common and leave no margin.

### tile_compression

`none` or `gzip`, applied to the tile file as a whole.

### tile_format_version

The version of the binary layout described above.

## Dependencies

* **geneExpressionPyramid_id**: the pyramid this level belongs to.
* **subject_id**: the subject the tissue came from. Present on each level
  as well as the parent so a level is independently queryable by subject.
* **source_file_id**: optional. The `generic_file` or other document
  holding the file this level was built from, for provenance.

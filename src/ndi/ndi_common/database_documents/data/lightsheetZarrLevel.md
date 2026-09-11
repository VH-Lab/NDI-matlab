# lightsheetZarrLevel

One resolution level of a `lightsheetZarrPyramid`. Owns the chunk bytes
for that level as a `chunk.bin_#` file series, plus enough metadata for
a reader to reconstruct the level as a lazy multiscale array.

NDI documents are immutable, so each level is a document of its own.
Adding a new reduction (a `max` pyramid alongside a mean one, for
example) means writing more `lightsheetZarrLevel` documents — no parent
edit, no rewrite. The parent describes the source volume; the ladder is
discovered from its children.

Level 0 is often shared across reductions: two NGFF multiscales entries
(mean and max) whose `datasets[0].path` is the same string are the same
underlying array. This document class represents that honestly — one
level doc with `reduction_function: 'none'` — instead of writing the
raw bytes twice.

## What this document is

- **The chunk container.** The `files.file_list` names one file series
  `chunk.bin_#`, one file per stored chunk. Chunk index numbering is
  1-based to match NDI's file-series convention, and the mapping from
  the file's 1-based number to the C-order chunk coordinate is defined
  by `chunk_grid` and `chunk_order`.
- **Level-local metadata.** `shape`, `chunks`, `voxel_size`, and
  `translation` describe this level as it sits inside the parent's
  coordinate system. A viewer that wants only one level does not have
  to touch the parent's fields.

## Fields

- `label` — human-readable name for the level (e.g.
  `"mean level 2 (12.8um)"`). Empty allowed.
- `level` — 0-based level index within the parent pyramid. 0 is the
  finest.
- `reduction_function` — the function used to produce this level from
  level 0: `'mean'`, `'max'`, ... `'none'` means the array is the raw
  source (typical for level 0 when it is shared across reductions). A
  reader asking for reduction `R` takes levels with
  `reduction_function in {'none', R}`, sorted by `level` ascending.
- `axes_order` — copied from the parent; carried here for
  self-describing reads.
- `shape` — per-axis size of this level's array, in `axes_order`.
- `chunks` — per-axis chunk size, in `axes_order`. This is the NGFF /
  Zarr chunk shape.
- `chunk_grid` — per-axis count of chunks along each axis =
  `ceil(shape ./ chunks)`.
- `n_chunks_stored` — number of `chunk.bin_#` files that were written.
  May be less than `prod(chunk_grid)` when trailing empty (fill-value)
  chunks were elided.
- `chunk_index_origin` — the first `#` in the `chunk.bin_#` series.
  Always 1 by convention (NDI file series are 1-based).
- `chunk_order` — the order in which the chunk grid is flattened to
  the 1-based file series. `"C"` for C-order (last axis fastest);
  `"F"` for Fortran-order.
- `dtype` — the Zarr dtype string (e.g. `<u2`, `<f4`).
- `fill_value` — fill value for chunks that were elided.
- `byte_order` — byte order of the on-disk chunk bytes.
- `codec` — Zarr codec name (`raw`, `blosc`, `zstd`). `raw` means the
  chunk file is the plain little-endian array bytes in `dtype` /
  `chunk_order`.
- `codec_params` — JSON-encoded string of the codec parameters
  (`cname`, `clevel`, `shuffle`, ...). Empty JSON `{}` for `raw`.
- `voxel_size` — per-axis voxel size at this level.
- `voxel_size_units` — the unit that `voxel_size` is expressed in.
- `translation` — per-axis translation at this level.

## Depends on

- `lightsheetZarrPyramid_id` — the parent pyramid (the source volume
  and its coordinate frame).
- `subject_id` — subject imaged.
- `source_file_id` — `fileReference` for the OME-Zarr store the level
  was materialized from. All levels of one pyramid share this id.

## Files

- `chunk.bin_#` — one file per stored chunk, index 1..`n_chunks_stored`.
  Each file is a single chunk's byte payload, after `codec` compression
  is applied and in `chunk_order`; a reader decodes it in isolation
  and does not need any of its neighbors. To locate the chunk grid
  coordinates from a 1-based `#`, unflatten `# - 1` against
  `chunk_grid` in `chunk_order`.

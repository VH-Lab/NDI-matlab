# lightsheetZarrPyramid

Parent document for one **reduction variant** of an OME-Zarr (NGFF v0.4)
multiscale pyramid captured by a lightsheet microscope. It carries the
metadata that is shared across every level and pins the coordinate system
in physical units so a viewer can render the pyramid without touching a
single chunk.

One `lightsheetZarrPyramid` document describes exactly one reduction. A
volume that ships both a mean pyramid and a max pyramid becomes two
`lightsheetZarrPyramid` documents, each with its own children. NDI
documents are immutable, so a new reduction is a new document, not an
edit to the existing one.

## What this document is

- **A parent that names the pyramid.** Level documents (see
  `lightsheetZarrLevel`) reference it by `depends_on` `pyramid_id`. To
  enumerate a pyramid's levels, query `lightsheetZarrLevel` for that
  parent id.
- **A coordinate anchor.** `shape_level0`, `voxel_size_level0`, and
  `translation_level0` describe the finest resolution. Each level then
  reports its own `voxel_size` and `translation` so a level can be drawn
  without recomputing from a downsample factor.
- **A description of the source volume.** `source_file_id` points at a
  `fileReference` naming the OME-Zarr store in the cloud cache. The
  chunks themselves live inside the child `lightsheetZarrLevel`
  documents' `chunk.bin_#` file series.

## What this document is not

- **Not a chunk container.** No bytes are stored here. Chunks are in
  `lightsheetZarrLevel` file series.
- **Not multi-reduction.** `reduction` names a single reduction (`mean`,
  `max`, ...). To hold two reductions of the same volume, create two
  parents.

## Fields

- `label` - human-readable name shown in a manager UI. Empty allowed.
- `reduction` - the downsampling function used between levels
  (`mean`, `max`). First-class; the viewer switches between reductions by
  switching parents.
- `pyramid_name` - the NGFF `multiscales.name` from the source store, if
  any. Descriptive; not the source of truth for `reduction`.
- `pyramid_type` - the NGFF `multiscales.type` field, verbatim.
  Descriptive only: an earlier writer of this format sometimes labeled
  the mean pyramid `gaussian`, so `reduction` is what code should
  branch on.
- `axes_order` - the axis order carried in every child level, e.g.
  `tczyx`. Follows NGFF conventions. All child levels use this order.
- `axes_units` - per-axis physical unit strings, aligned with
  `axes_order`.
- `channel_names` - display names of the channels, in the order of the
  `c` axis.
- `n_channels` - convenience count; must equal `numel(channel_names)`.
- `n_levels` - number of `lightsheetZarrLevel` documents that should
  reference this pyramid.
- `shape_level0` - shape of the finest resolution array, in
  `axes_order`.
- `voxel_size_level0` - per-axis voxel size at level 0.
- `voxel_size_units` - the unit that `voxel_size_level0` and each
  child's `voxel_size` are expressed in.
- `translation_level0` - per-axis translation at level 0.
- `dtype` - the array dtype string as written in NGFF `.zarray` (e.g.
  `<u2`). Every level shares it.
- `pipeline_version` - identifier of the pipeline that produced this
  pyramid.
- `byte_order` - byte order used when the child level chunks were
  written into the `chunk.bin_#` file series.

## Depends on

- `subject_id` - subject imaged.
- `element_id` - imaging element (session probe / element) that
  captured the source volume. Empty when the volume is standalone.
- `source_file_id` - `fileReference` describing the source OME-Zarr
  store in the cloud cache.

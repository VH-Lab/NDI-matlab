# lightsheetZarrPyramid

Parent document for an OME-Zarr (NGFF v0.4) multiscale pyramid captured
by a lightsheet microscope. Describes the **source volume**: what was
imaged, what its axes and coordinate system are, and where the raw file
came from. One document per source volume — the reductions (mean, max,
...) live on the level children, so a source volume that ships both
mean and max pyramids is still one parent.

## What this document is

- **The identity of the source volume.** `axes_order`, `channel_names`,
  `shape_level0`, `voxel_size_level0`, `translation_level0`, `dtype`
  — all describe the raw volume the ladder was built from. None of
  these change when you add another reduction or another coarser level,
  which is why they live here and not on the children.
- **A pointer at the source.** `source_file_id` names a
  `fileReference` document that describes the OME-Zarr store on disk /
  in the cloud cache. `fileReference` describes rather than attaches;
  an OME-Zarr store is a directory tree of many GB and the pyramid
  documents already carry every byte of it we care about.

## What this document is not

- **Not reduction-specific.** There is no `reduction` field. Level
  children carry `reduction_function` (`'none'` for the shared raw
  level 0, `'mean'`/`'max'`/... for reduced levels), and a reader
  discovers what reductions exist by querying children.
- **Not a ladder count.** There is no `n_levels`. It is discoverable
  from the child query, and storing it here would force a rewrite of
  the parent every time a new level was added — NDI documents are
  immutable, so that would mean a new parent.
- **Not a chunk container.** No bytes are stored here. Chunks are in
  `lightsheetZarrLevel` file series.

## Fields

- `label` — human-readable name shown in a manager UI. Empty allowed.
- `pyramid_name` — the NGFF `multiscales.name` from the source store,
  if any. Descriptive.
- `pyramid_type` — the NGFF `multiscales.type` field, verbatim.
  Descriptive only: an earlier writer of this format sometimes labeled
  the mean pyramid `gaussian`, so `reduction_function` on the level
  children is what code should branch on.
- `axes_order` — the axis order carried in every child level, e.g.
  `tczyx`. Follows NGFF conventions. All child levels use this order.
- `axes_units` — per-axis physical unit strings, aligned with
  `axes_order`.
- `channel_names` — display names of the channels, in the order of the
  `c` axis.
- `n_channels` — convenience count; must equal `numel(channel_names)`.
  Describes the source volume, not the ladder.
- `shape_level0` — shape of the finest resolution array, in
  `axes_order`.
- `voxel_size_level0` — per-axis voxel size at level 0.
- `voxel_size_units` — the unit that `voxel_size_level0` and each
  child's `voxel_size` are expressed in.
- `translation_level0` — per-axis translation at level 0.
- `dtype` — the array dtype string as written in NGFF `.zarray` (e.g.
  `<u2`). Every level shares it.
- `pipeline_version` — identifier of the pipeline that produced this
  pyramid.
- `byte_order` — byte order used when the child level chunks were
  written into the `chunk.bin_#` file series.

## Discovery patterns

Enumerate the reductions this pyramid holds:

```matlab
levels = session.database_search(ndi.query('','isa','lightsheetZarrLevel') ...
    & ndi.query('depends_on','depends_on','lightsheetZarrPyramid_id', p.id()));
reductions = setdiff(unique(cellfun(@(l) l.document_properties.lightsheetZarrLevel.reduction_function, ...
    levels, 'UniformOutput', false)), {'none'});
```

Ask for the ladder to use when reading reduction `R`:

```matlab
keep = arrayfun(@(l) any(strcmp(l.reduction_function, {'none', R})), rows);
ladder = sortrows(rows(keep,:), 'level');
```

## Depends on

- `subject_id` — subject imaged.
- `element_id` — imaging element (session probe / element) that
  captured the source volume. Empty when the volume is standalone.
- `source_file_id` — `fileReference` describing the source OME-Zarr
  store on disk / in the cloud cache.

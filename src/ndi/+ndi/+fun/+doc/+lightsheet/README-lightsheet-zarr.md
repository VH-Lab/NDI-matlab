# lightsheet OME-Zarr documents (design + status)

This package (`+ndi/+fun/+doc/+lightsheet/`) lets a session hold a
lightsheet OME-Zarr (NGFF v0.4) multiscale pyramid as NDI documents,
and hands one to napari for viewing through NDI-python.

The pattern mirrors `+ndi/+fun/+doc/+gene/` (spatial transcriptomics
Stereo-seq / GEF) so a reader of that package will recognise every
piece here.

## Document shape

Two new document classes:

- **`lightsheetZarrPyramid`** - one per REDUCTION variant (`mean`,
  `max`, ...). Holds the frame (axes, level-0 shape, voxel size,
  translation, channels, dtype). Depends on subject + optional element
  + optional `fileReference` for the source store.
- **`lightsheetZarrLevel`** - one per (pyramid, level). Owns the chunk
  bytes as a `chunk.bin_#` file series and the per-level metadata
  (shape, chunks, voxel size, translation, codec, ...). Depends on its
  parent pyramid.

NDI documents are immutable, so:
- A new reduction is a new pyramid document + its own level ladder.
- A deeper coarsening is a new level document; the parent's `n_levels`
  is out of date until a new parent version is written for that count.

## MATLAB API surface

- `ndi.fun.doc.lightsheet.fromOMEZarr(session, zarrPath, ...)` -
  probe an OME-Zarr store, write ONE pyramid document per multiscales
  entry and ONE level document per level. Metadata-only; does not copy
  chunk bytes. **Working.**
- `ndi.fun.doc.lightsheet.makePyramid(session, pyramidEntry, ...)` -
  the per-multiscales-entry worker `fromOMEZarr` calls. Reusable when
  the caller already has an `ndr.format.omezarr.listPyramids` struct
  in hand. **Working.**
- `ndi.fun.doc.lightsheet.makeSourceFile(session, zarrPath)` -
  fileReference for the store. **Working.**
- `ndi.fun.doc.lightsheet.levelTable(session, pyramidDoc)` -
  finest-first table of a pyramid's levels; `Properties.UserData`
  carries the parent frame. **Working.**
- `ndi.fun.doc.lightsheet.chooseLevel(levels, targetVoxelSize)` -
  pick the coarsest level whose voxel size still meets the target.
  **Working.**
- `ndi.fun.doc.lightsheet.viewCommand(launcher, sessionPath, pyramidID, ...)`
  - pure command builder. Same pattern as
  `ndi.gui.app.GEFManager.viewCommand`; the launcher is
  `/usr/local/bin/napariViewLightsheet`, a shell wrapper around the
  `napariViewLightsheet` console script that ships in
  `Waltham-Data-Science/NDI-python`. **Working.**

## GUI

`ndi.gui.app.LightsheetZarrManager(session)` mirrors `GEFManager`:
lists pyramids in a session, and drives Add / View / Delete. `View`
builds the napari command from `viewCommand` and shells out.

## What still needs building

1. **Chunk materialization** into `chunk.bin_#` on
   `lightsheetZarrLevel`. Uses the same file-series upload path as
   `ndi.cloud.sync.internal.uploadFilesForDatasetDocuments`, plus a
   small `chunk_index` side-field so sparse pyramids can elide
   fill-value chunks without breaking the 1-based `chunk.bin_#`
   addressing. Land that side-field on the schema first, then a
   `makePyramid` option (or a stand-alone `materializeChunks`
   function) can write bytes.
2. **NDI-python napari reader.** The MATLAB `viewCommand` targets
   `/usr/local/bin/napariViewLightsheet`, a shell wrapper around
   `ndi.gui.app.lightsheetZarr.cli:main` in
   `Waltham-Data-Science/NDI-python` (installed as
   `[project.scripts].napariViewLightsheet`). The CLI, viewer, and
   metadata reader are landed; the per-chunk dask fetcher that
   `levelArrays` calls is a scaffold today. See that repo's
   `src/ndi/gui/app/lightsheetZarr/README-lightsheet-zarr.md`.
3. **`readViewport` (MATLAB).** A MATLAB path for reading a rectangle
   out of a pyramid at the appropriate level. Two backends are
   plausible: read the source store via `ndr.format.omezarr.readArray`
   (works today, but only when the store is on disk), or read the
   materialized `chunk.bin_#` files via the cloud API (blocked on #1).
   The scaffold from an earlier version of this PR was removed to
   keep the package free of `notImplemented` bodies; add it back with
   real code when #1 lands.
4. **NDR helpers.** `ndr.format.omezarr.probe` is small; when it lands
   in NDR-matlab / NDR-python, `fromOMEZarr` here can call it instead
   of `listPyramids` for cheaper metadata reads. (Landing on the same
   branch name in the NDR repos.)
5. **Tests.** Once #1 lands, extend
   `tests/+ndi/+unittest/+fun/+doc/+lightsheet/` with round-trip and
   viewport tests analogous to `+gene/`'s.

## Related

- `ndi.gui.app.GEFManager` - the sibling manager for Stereo-seq GEF
  spatial transcriptomics. Same launcher pattern (a shell wrapper
  around an NDI-python console script). Read it first if this is your
  first NDI file-format ingest.
- `ndr.format.omezarr.*` - the metadata / read primitives this
  package builds on.

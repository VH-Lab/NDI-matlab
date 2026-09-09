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
  - pure command builder. Same pattern as `ndi.gui.app.GEFManager.viewCommand`;
  the launcher is `/usr/local/bin/napariViewLightsheet`, a shell
  wrapper around the napari console script that ships in NDI-python.
  **Working.**
- `ndi.fun.doc.lightsheet.writeChunkFile(session, levelDoc, pyramidEntry, level)`
  - materialize a level's chunks into its `chunk.bin_#` file series.
  **Scaffold.** See "What still needs building" below.
- `ndi.fun.doc.lightsheet.readViewport(session, pyramidDoc, region, ...)`
  - read a rectangle from the appropriate level. **Scaffold**; the
  napari viewer in NDI-python is the primary reader.

## GUI

`ndi.gui.app.LightsheetZarrManager(session)` mirrors `GEFManager`:
lists pyramids in a session, and drives Add / View / Delete. `View`
builds the napari command from `viewCommand` and shells out.

## What still needs building

1. **Chunk materialization across the HIPAA-compliant NDI cloud API.**
   `writeChunkFile.m` is a scaffold today because the file-series
   upload path we need is the one already used by
   `ndi.cloud.sync.internal.uploadFilesForDatasetDocuments`, and
   wiring it in here needs a small chunk-index side-file (level
   document field `chunk_index`) so we can elide fill-value chunks
   without breaking the 1-based `chunk.bin_#` addressing. Design and
   land that first, then remove the `notImplemented` guard.
2. **NDI-python napari console script.** The MATLAB `viewCommand`
   targets `/usr/local/bin/napariViewLightsheet`, a shell wrapper
   around a Python console script that ships in NDI-python (see
   `ndi/lightsheet/napari_view.py`). That console script is the piece
   that actually reads the pyramid + level documents through the NDI
   cloud API and hands lazy dask arrays to napari.
3. **`readViewport` MATLAB backend.** Two paths are already
   documented: read the source store via `ndr.format.omezarr.readArray`
   (works today, but only for the session that has the store on-disk),
   or read `chunk.bin_#` from a level document through the cloud API
   (blocked on #1).
4. **NDR helpers.** `ndr.format.omezarr.probe` is small; when it lands
   in NDR-matlab / NDR-python, `fromOMEZarr` here can call it instead
   of `listPyramids` for cheaper metadata reads.
5. **Tests.** Once #1 lands, extend
   `tests/+ndi/+unittest/+fun/+doc/+lightsheet/` with round-trip and
   viewport tests analogous to `+gene/`'s.

## Related

- `ndi.gui.app.GEFManager` - the sibling manager for Stereo-seq GEF
  spatial transcriptomics. Same launcher pattern (a shell wrapper
  around a NDI-python console script). Read it first if this is your
  first NDI file-format ingest.
- `ndr.format.omezarr.*` - the metadata / read primitives this
  package builds on.

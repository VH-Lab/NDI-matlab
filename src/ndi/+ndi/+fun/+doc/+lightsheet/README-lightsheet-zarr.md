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
- `ndi.fun.doc.lightsheet.chooseTileShape(shape, axesOrder, voxelSize, dtype, budgetBytes)` -
  size a chunk to a byte budget with tiles isotropic in world space.
  Default budget 32 MB uncompressed, sized to the measured
  signing+fetch+decode sweet spot for a viewer on an ~200 MB/s link.
  Used by `makePyramid` per level; the source store's chunk shape is
  not preserved. **Working.**
- `ndi.fun.doc.lightsheet.viewCommand(launcher, sessionPath, pyramidID, ...)`
  - pure command builder. Same pattern as
  `ndi.gui.app.GEFManager.viewCommand`; the launcher is the
  `napariViewLightsheet` console script that ships in
  `Waltham-Data-Science/NDI-python`, found by
  `ndi.python.findCommand('napariViewLightsheet')` (install it with
  `ndi.python.install()`) and started with `NDI_FROM_MATLAB=1`.
  **Working.**

## Straight from SmartSPIM: `fromSPIM`

`ndi.fun.doc.lightsheet.fromSPIM(S, rootDir, 'subjectID', id)` builds the
same pyramid + level documents as `fromOMEZarr`, but reads the SmartSPIM
acquisition directly -- no spim2zarr step. Level 0 (all channels, axes
`tczyx`) comes from the stitched, harmonized `All_Channels` slices
(`ndr.format.smartspim.readAllChannelsInfo`; only the needed rows and
columns of each slice are read). The mean and max ladders are built
here, each level by block-reducing the one just written
(`ndi.fun.doc.lightsheet.reduceBlocks`), halving x/y/z while the voxel
size allows (coarse-z stacks even out in x/y first) until every spatial
axis is at most `minLevelSize` (512) voxels. Chunking, encoding,
parallel compression and installation are `makePyramid`'s, through its
`levelSources` option.

## Straight to a cloud session: `ndi.cloud.upload.SessionWriter`

Both builders accept an `ndi.cloud.upload.SessionWriter` in place of a
session. The documents then go directly to one session of an NDI Cloud
dataset, without a local session or `uploadDataset` step:

```matlab
sessions = ndi.cloud.upload.SessionWriter.listSessions(datasetId);
subjects = ndi.cloud.upload.SessionWriter.listSubjects(datasetId, sessionId);
W = ndi.cloud.upload.SessionWriter(datasetId, sessionId);
[P, L, info] = ndi.fun.doc.lightsheet.fromOMEZarr(W, zarrPath, ...
    'subjectID', subjectId, 'codec', 'blosc-zstd');
```

- **A session, never just the dataset.** `sessionId` must be one of the
  dataset's sessions (its `session_in_a_dataset` records). Every document
  gets it as `base.session_id`, so the pyramid is in that session when
  the dataset is downloaded.
- **The subject must already be there, in that session.** The builders
  check this (and `elementID` / `sourceFileID`, if given) before any
  chunk is built.
- **Chunks are always materialized.** The cloud cannot read a store on
  local disk.
- **Files are sent first and checked; the documents go up last.** Each
  level's chunk files and series manifest are uploaded as soon as the
  level is built, under the uids DID assigned them. For a document with
  many files they go in zip batches, otherwise one at a time with a
  signed CRC-32. Each file is then compared against the CRC-32 NDI Cloud
  records (`lookupFiles`; size when no checksum was recorded). A file
  that is missing or different is uploaded again on its own; if it is
  still wrong, that is an error. Documents are added only by
  `SessionWriter/commit`, after every file has passed, so a failed run
  leaves no document in the cloud pointing at missing files.
- **Disk.** The writer keeps a local copy of what it sent until the
  commit, so `fromSPIM` can reduce each level from the one before it.
  This takes as much space as a local ingest would.

## GUI

`ndi.gui.app.LightsheetZarrManager(session)` mirrors `GEFManager`:
lists pyramids in a session, and drives Add / View / Delete. `View`
builds the napari command from `viewCommand` and shells out. `Add...`
asks whether the pyramid goes to this session or to an NDI Cloud
session. For the cloud, it then asks for the dataset, one of its
sessions, and a subject of that session, and runs `fromOMEZarr` through
a `SessionWriter`. The table lists the local session only, so a pyramid
added to the cloud does not appear in it.

### Viewer logs

Both `View` and `ndi.fun.doc.lightsheet.view` launch the viewer through
`ndi.fun.doc.lightsheet.launchViewer`, which turns on the viewer's
debugging lines (`NDI_LIGHTSHEET_DEBUG=1`) and appends its stdout and
stderr to `lightsheet_YYYYMMDDHHMMSS.txt` in
`ndi.common.PathConstants.TempFolder`. The path is printed in the
Command Window (and shown in the manager's status line); open it with
`edit` or `type` to see what the viewer fetched and what failed.

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
   the `napariViewLightsheet` console script
   (`ndi.gui.app.lightsheetZarr.cli:main`) in
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

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
- **Streamed, declared first.** Before a level is built, it is declared:
  every chunk gets its uid, and the level document and its manifest
  (which lists those uids) are uploaded at once, after the pyramid
  document. The pyramid's label carries " (uploading)" until the end.
  Chunks are then uploaded as each super-block is written, in batches.
  A batch goes up in the background: one curl process
  (`ndi.cloud.upload.CurlSender`, curl 7.68+) sends 4 files at a time
  while MATLAB compresses the next super-block (`ParallelUploads` on
  `SessionWriter`; with an older curl the files go one by one). Each
  batch is checked against the CRC-32 NDI Cloud records (`lookupFiles`; size
  when no checksum was recorded) while the next is built. A missing or
  different file is sent again on its own; still wrong is an error.
  Nothing in the cloud is ever unreferenced, so the orphan cleanup has
  nothing to remove; a stopped run leaves a pyramid labelled
  "(uploading)" with some chunks missing.
- **Reading the slices.** Each batch of slices is read by several pool
  workers at once, each a slab along z (`readWorkers`, default 8): over a
  network every slice file costs a round trip, so reading them one at a
  time left the link mostly idle. Level 1 of both ladders is built
  during level 0, from the same reads: each read is a region holding
  whole level-0 chunks and whole level-1 chunks, cut into level 0's
  chunks and block-reduced to each ladder's level 1, so the slices are
  read once in all. (When that cannot be done -- resuming a job whose
  level 0 is finished, say -- both level 1s are built afterwards from one
  more read.) Both level 1s then stay on this disk until level 2 of their
  ladder is made from them.
- **Disk.** A chunk is deleted locally once the cloud has it, unless a
  later level is reduced from its level; that level is deleted once the
  later level is built. For SmartSPIM, level 1 of each ladder is reduced
  straight from the slices (one more read of them per ladder), so level
  0 is never kept. Peak disk is roughly one level 1 plus one level 2.
- **Commit.** At the end every declared chunk is looked up once more, the
  remaining documents are added, and the pyramid's label is updated to
  drop " (uploading)".

## GUI

`ndi.gui.app.LightsheetManager(session)` (Apps menu: **Lightsheet Manager**)
mirrors `GEFManager`: it lists the pyramids in a session and drives Add /
View / Delete. `View` builds the napari command from `viewCommand` and
shells out.

`Add...` opens one dialog, filled in top to bottom:

1. **Add to**: this session, or a session in an NDI Cloud dataset (then
   pick the dataset and one of its sessions).
2. **Subject**: one of that session's subjects, or **New subject...**,
   which adds one (local identifier and description) to that session.
3. **Image folder**: a SmartSPIM acquisition folder (the one holding the
   stitched `All_Channels`) or an OME-Zarr store. The type is detected and
   shown; SmartSPIM uses `fromSPIM`, OME-Zarr `fromOMEZarr`.
4. **Label** (defaults to the folder name) and, for SmartSPIM, an optional
   **voxel size** when the acquisition's metadata does not give one.
5. **Compression**: the Blosc-Zstd level of the stored chunks, 1-9. It
   defaults to 8 for the cloud and 5 for this session. Level 9 is
   allowed but warned about: c-blosc maps Blosc level L to Zstd level
   2L-1, except that 9 is Zstd's maximum (22), which is many times slower
   and needs far more memory per worker for a percent or two smaller
   files.
6. **Reductions** (SmartSPIM only): mean and max, mean only, or max only.
   An OME-Zarr store brings its own ladders.
7. **Workers**: parallel workers compressing chunks. It starts at the
   size of an open parallel pool, otherwise min(8, cores); more than 1
   opens a pool of that size.

The box at the bottom lists what is still missing, and **Add** stays
disabled until nothing is. Chunks are always stored in NDI, locally too:
the viewer reads only stored chunks. A pyramid added to the cloud goes
through `ndi.cloud.upload.SessionWriter` and is not listed in the table,
which shows the local session. The dialog's decisions are static
functions (`addChoices`, `sourceKind`, `addPlan`, `addMessage`,
`subjectProblems`) and its work is `addSubject` and `runAdd`, so the same
add can be scripted:

```matlab
c = ndi.gui.app.LightsheetManager.addChoices();
c.subjectID = subjectId;
c.sourcePath = '/data/ferret42_SmartSPIM';
c.sourceKind = ndi.gui.app.LightsheetManager.sourceKind(c.sourcePath);
ndi.gui.app.LightsheetManager.runAdd(S, c);
```

### Jobs: pause, resume, restart

Adding to an NDI Cloud session from the dialog runs as a job
(`ndi.job.LightsheetToCloud`, a subclass of `ndi.job.Job`), kept in
`~/.ndi/jobs/<id>/`, and listed in the navigator's **Jobs** pane with
**Pause**, **Resume**, **Restart** and **Remove**.

- **Pause** takes effect after the current super-block: its chunks are
  sent, the job's place is saved, and it stops.
- **Resume** works after a pause, a failure, Ctrl+C, quitting MATLAB or a
  crash. The job saved every document it uploaded (with its chunk uids),
  so it adopts the pyramid and the levels already declared, asks the
  cloud which chunks it has, and builds only the rest. The level kept for
  the next one to be reduced from is in the job's folder, so it survives
  a restart; if it is gone, those chunks are downloaded.
- **Restart** starts over with a new pyramid; the earlier partial one stays
  in the dataset, labelled "(uploading)".
- **Short outages are ridden out without stopping**: cloud calls are
  retried for up to 30 minutes (`SessionWriter` `RetrySeconds`), an
  `addDocument` only after checking it did not arrive, and slice reads
  likewise, unless the slice's folder is reachable and the file is not.

The job record is shared with NDI-python: `job.json` is defined by
`ndi_common/job_schema/job.schema.json` (format version 1). Its `kind` is a
language-neutral name (`lightsheetToCloud`) that each language maps to its
own class (`ndi.job.Job.register` in MATLAB); `runtime` says which language
last ran it; times are UTC; `host` and `pid` say where it runs. A job whose
kind is unknown here, or whose format is newer, is listed as an
`ndi.job.ForeignJob` but not run.

A job runs in the MATLAB that started it, which stays busy meanwhile; the
job lets the window redraw at each heartbeat, which is when Pause takes.
Running jobs in a separate background MATLAB is a planned next step.

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

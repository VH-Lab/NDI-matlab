# `ndi.setup.conv.haley.import_V2` — decision log

The running record of the choices made while building `import_V2`, the V2
(V_eta) importer for the Haley (JH) C. elegans / E. coli foraging dataset.
`import_V2` is meant to be the canonical example of importing a dataset
(and the basis of a GUI importer), so the reasoning is kept, not just the result.

Entries marked **DECIDED** were made by the dataset owner (jess) in
conversation; **OPEN** entries are questions still to answer. The existing
`doImport.m` is left unchanged (backwards compatibility).

## Principles (DECIDED 2026-09-30)

- Changes to NDI-matlab and DID-matlab are backwards compatible: new
  functions/classes beside the old ones, existing behaviour unchanged.
- Documents are built with `did2.build` (DID-matlab V2), so no importer or
  NDIMaker carries a field list of its own.
- New NDI object classes stay thin; everything added must be portable to
  NDI-python.
- The import is worked through one section at a time, updating the relevant
  NDIMakers and object classes as it goes.
- The spec is an OUTPUT, not an input. A user cannot describe a dataset before
  reading its files, so the importer first DISCOVERS and PROFILES the source
  tables, then each stage asks its questions about them; the answers
  accumulate into a spec that is saved for re-imports and similar datasets.

## Stage order (DECIDED in outline 2026-09-30; details per section)

discover/profile -> dataset metadata -> sessions -> entities -> relations ->
assertions -> manipulations -> observations -> calculations -> check & write.
Each stage returns an id map (source key -> document id) that later stages use.

## Decisions

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | 2026-09-30 | **Plates and patches are subjects** (not `ontologyTableRow` rows), so worms can be related to them and observations can be about them. | DECIDED |
| 2 | 2026-09-30 | **Excluded data is tagged, not dropped**: a `term_assertion` on the plate (e.g. the `exclude` column / tableOfContents `include = no`), carrying the reason where one is recorded (tableOfContents `notes`). | DECIDED |
| 3 | 2026-09-30 | `foragingConcentration/tableOfContents.xlsx` row `0014`: `wormNumber` `0449-0546` is a typo (overlaps row `0013`, `0451-0498`); the intended range is `0499-0546`. The importer must not trust the column blindly: it cross-checks each day's worm range against the worms present in `experimentInfo` and reports mismatches. | DECIDED (typo); correction mechanism OPEN |
| 4 | 2026-09-30 | Images are typed by what a pixel holds: fluorescence = intensity, masks = logical, closest-patch = which patch. Exact V2 classes to be checked against the #73 schema at the observations stage (the V2 `image` data_type was retired in #73 item 51). | OPEN |
| 5 | 2026-09-30 | **One session per experimental day.** An `ndi.session` is a unit of acquisition (one directory of raw files, its DAQ systems, one `syncgraph` of related clocks; `session.m`), so a day's recordings are a session. "All subjects in the dataset" is one `ndi.dataset.database_search` (it spans the dataset's database and every linked session, `dataset.m:748`); "all C. elegans" is a species assertion on each subject, not a level. (`doImport` made 2 sessions: all C. elegans, all E. coli.) | DECIDED |
| 8 | 2026-09-30 | **A grouping of sessions above the day is needed** for foragingConcentration / Matching / Mini / Mutants / Sensory (and the E. coli imaging). V2 has nothing between session and dataset: `part_of` allows only session -> dataset (`build_v_eta.py` `_rel("part_of"...)`), a term assertion must be about a `subject` (not a session), and `follows_protocol` runs dataset -> `web_resource`. Needs a new entity + relation (schema change, team decision). Name: NOT `protocol` (reads as a recipe; the five share one foraging recipe and differ in design). Proposed: `study`, as in ISA's investigation / study / assay. | OPEN (direction agreed; name + schema change pending) |
| 9 | 2026-09-30 | **Videos are imported through a DAQ reader as image-series epochs**, so each recording is an epoch with a clock and the tracks are observations timed against it (`doImport` attached mp4s as `imageStack` files and made no epochs). NDI already has `ndi.daq.system.image` / `ndi.daq.reader.image` / `ndi.daq.reader.image.ndr` (movie clock `dev_local_time` + per-frame times); NDR-matlab's `imagestack` reader (NANSEN `ImageStack`) lists `.mp4`/`.avi`/`.mov` (`+ndr/+reader/imagestack.m:120`), so no new reader is needed; per-frame times still to confirm against `frameRate` / the tracks' `time`. | DECIDED (direction) |
| 10 | 2026-09-30 | **E. coli: one epoch per image**, timed by `acquisitionTime`. The plates were moved between images and the images are not spatially registered, so a time-lapse epoch would claim a registration that does not exist; the plate SUBJECT carries the continuity across images. | DECIDED |
| 11 | 2026-09-30 | `study` entity (proposal, for #8): fields `name` (req), `short_name`, `description`, `factors` (terms: the variables deliberately varied, same vocabulary as statement `variable`), `design` (terms, optional); `global_identifier` inherited. People / publications / protocols as relations. `part_of` widened to session -> study, study -> dataset, study -> study (nesting allowed; transitive lookup in one NDI helper). JH: six flat studies under the dataset. | OPEN (proposed; schema change needs team sign-off) |
| 6 | — | Distance-to-patch model (was `distance_metadata`). | OPEN |
| 7 | — | Encounters: one statement per encounter, or a keyed series per worm. | OPEN |

## Source inventory (from the file list, 2026-09-30)

Raw data (everything under `.ndi/`, `.ndi_/`, `haley_2025/` and `haley/*.zip`
is output of earlier `doImport` runs and must be skipped by discovery):

- `celegans/<experiment>/experimentInfo.mat` — one row per plate-video, 67–70
  columns: plate prep timeline, bacteria/OD600, cultivation ("growth*", the L4
  plate), environment (temp, humidity), video/camera, arena and lawn geometry,
  and per-plate 1024x1024 images (`firstFrame`, `arenaMask`, `refMask`,
  `lawnMask`, `lawnClosest`, `lawnClosestOD600`). Experiments:
  foragingConcentration (193 rows, 18 days), foragingMatching (60 rows / 50
  plates, 5 days), foragingMini (234, 24), foragingMutants (93 / 84, 4),
  foragingSensory (38 / 36, 2). Extra columns: `configuration` (Matching,
  Mutants, Sensory), `starvedTime`/`starvedDuration` (Mutants, Sensory).
- `celegans/<experiment>/{midpoint,head,tail}.mat` — per frame per worm tracks
  (foragingSensory midpoint: 1,550,152 rows x 25 columns: position, velocity,
  path angle, turn, neighbour distances, distance to lawn/arena edge, closest
  lawn, flags). head/tail only in foragingMini.
- `celegans/encounter.mat` — 21,543 encounters x 39 columns, all experiments.
- `celegans/<experiment>/tableOfContents.xlsx` — one row per experiment day:
  number, directory, lab notebook, worm range, conditions, include, notes.
  NOT read by `doImport`.
- `celegans/<experiment>/videos/<yy-mm-dd>/*.mp4` — one per plate-video.
- `ecoli/bacteria.mat` — `info` (126 plates, 5 experiments), `metaData`
  (3,725 images incl. brightfield/background), `lawnAnalysis` (7,204 patches
  over 1,521 fluorescence images).
- `ecoli/{images/*.tiff, mask/*.png, closest/*.png}` — 1,575 each.

Identity: `expNum`, `plateNum` and `wormNum` restart per experiment folder
(e.g. `encounter.mat` has 232 distinct `plateNum` for 618 plate rows), so every
key is qualified by the experiment name.

To reconcile: 1,575 image files on disk vs 1,521 analysed images in
`lawnAnalysis` vs 3,725 images in `metaData`.

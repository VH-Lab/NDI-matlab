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

## Stage order (DECIDED 2026-09-30, revised after discovery)

The first outline (discover -> dataset metadata -> sessions -> entities -> ...)
was flat and had no acquisition stage. Discovery changed three things:
every interaction statement needs a time reference (`subject_interaction`
declares `time_reference_id` with `min_count 1`), so EPOCHS must exist before
any statement; the source data comes per study (1-4 GB of tracks per folder)
and is recorded per day, so the loop is NESTED; and some content spans days or
studies (`encounter.mat` covers all five C. elegans studies; relative patch
density comes from the E. coli study), so it runs in a final dataset pass.

    A. dataset, once
       0  discover       list source files; skip earlier import output
       1  profile        describe tables (on demand)
       2  metadata       people, organizations, funding, publication, studies,
                         strains, products, instruments   (BUILT)
    B. per study (E. coli FIRST), tables loaded once + named corrections;
       per day:
       3  session        one per day, `part_of` its study
       4  acquisition    camera / microscope system, one epoch per video or
                         image, clocks + syncgraph
       5  subjects       cultivation (L4) plates, behaviour plates, patches, worms
       6  relations      patch part_of plate, worm on plate, worm from its
                         cultivation plate
       7  assertions     strain, species, exclusion tag on plates
       8  manipulations  plate preparation timeline (absolute UTC times),
                         food deprivation, transfer
       9  observations   tracks per video epoch, temperature/humidity, arena
                         and patch geometry, fluorescence images
       10 calculations   per day: masks, closest-patch maps from the first frame
          write the session
    C. dataset-wide, once
       11 encounters     the cross-study encounter table
       12 calculations   cross-study: relative density (E. coli -> C. elegans)
       13 check & write  validate, census, write the dataset

Each stage returns an id map (source key -> document id) that later stages use.

## Decisions

| # | Date | Decision | Status |
|---|---|---|---|
| 1 | 2026-09-30 | **Plates and patches are subjects** (not `ontologyTableRow` rows), so worms can be related to them and observations can be about them. | DECIDED |
| 2 | 2026-09-30 | **Excluded data is tagged, not dropped**: a `term_assertion` on the plate (e.g. the `exclude` column / tableOfContents `include = no`), carrying the reason where one is recorded (tableOfContents `notes`). | DECIDED |
| 3 | 2026-09-30 | `foragingConcentration/tableOfContents.xlsx` row `0014`: `wormNumber` `0449-0546` is a typo (overlaps row `0013`, `0451-0498`); the intended range is `0499-0546`. The importer must not trust the column blindly: it cross-checks each day's worm range against the worms present in `experimentInfo` and reports mismatches. | DECIDED (typo); correction mechanism OPEN |
| 4 | 2026-09-30 | Images are typed by what a pixel holds: fluorescence = intensity, masks = logical, closest-patch = which patch. Exact V2 classes to be checked against the #73 schema at the observations stage (the V2 `image` data_type was retired in #73 item 51). | OPEN |
| 5 | 2026-09-30 | **One session per experimental day.** An `ndi.session` is a unit of acquisition (one directory of raw files, its DAQ systems, one `syncgraph` of related clocks; `session.m`), so a day's recordings are a session. "All subjects in the dataset" is one `ndi.dataset.database_search` (it spans the dataset's database and every linked session, `dataset.m:748`); "all C. elegans" is a species assertion on each subject, not a level. (`doImport` made 2 sessions: all C. elegans, all E. coli.) | DECIDED |
| 8 | 2026-09-30 | **A grouping of sessions above the day is needed** for foragingConcentration / Matching / Mini / Mutants / Sensory (and the E. coli imaging). V2 has nothing between session and dataset: `part_of` allows only session -> dataset (`build_v_eta.py` `_rel("part_of"...)`), a term assertion must be about a `subject` (not a session), and `follows_protocol` runs dataset -> `web_resource`. Needs a new entity + relation (schema change, team decision). Name: NOT `protocol` (reads as a recipe; the five share one foraging recipe and differ in design). Proposed: `study`, as in ISA's investigation / study / assay. | DECIDED: `study` (built, see #11) |
| 9 | 2026-09-30 | **Videos are imported through a DAQ reader as image-series epochs**, so each recording is an epoch with a clock and the tracks are observations timed against it (`doImport` attached mp4s as `imageStack` files and made no epochs). NDI already has `ndi.daq.system.image` / `ndi.daq.reader.image` / `ndi.daq.reader.image.ndr` (movie clock `dev_local_time` + per-frame times); NDR-matlab's `imagestack` reader (NANSEN `ImageStack`) lists `.mp4`/`.avi`/`.mov` (`+ndr/+reader/imagestack.m:120`), so no new reader is needed; per-frame times still to confirm against `frameRate` / the tracks' `time`. | DECIDED (direction) |
| 10 | 2026-09-30 | **E. coli: one epoch per image**, timed by `acquisitionTime`. The plates were moved between images and the images are not spatially registered, so a time-lapse epoch would claim a registration that does not exist; the plate SUBJECT carries the continuity across images. | DECIDED |
| 11 | 2026-09-30 | `study` entity (proposal, for #8): fields `name` (req), `short_name`, `description`, `factors` (terms: the variables deliberately varied, same vocabulary as statement `variable`), `design` (terms, optional); `global_identifier` inherited. People / publications / protocols as relations. `part_of` widened to session -> study, study -> dataset, study -> study (nesting allowed; transitive lookup in one NDI helper). JH: six flat studies under the dataset. | DECIDED 2026-09-30 (jess approved the fields); BUILT, SIGNED (jess, `schemas/V_eta_study_plan.md`) and MERGED (did-schema PR #78) |
| 12 | 2026-09-30 | **Studies (from the eLife paper, 10.7554/eLife.103191, Materials and methods):** foragingConcentration is TWO studies -- single-density multi-patch (tableOfContents `grid` days) and large single-patch (`single` days); foragingMini = small single-patch (9 mm arena, 1 worm, 8 fps, head/tail tracked); foragingMatching = multi-density multi-patch (no peptone, 2 h); ecoli = bacterial patch density estimation (OP50-GFP, Zeiss Axio Zoom.V16). Settled from the data (2026-09-30): **foragingSensory** = the sensory-mutant study (N2 well-fed 13, PR811 osm-6 13, TU253 mec-4 12 plates; no food deprivation). **foragingMutants** = a broader mutant screen, 93 plates: cat-2, gcy-35, eat-2, npr-1, tax-4, tdc-1, tph-1, tbh-1, osm-6, mec-4, N2 well-fed, and N2 food-deprived (7 plates, the only ones with `starvedDuration > 0`); the paper's well-fed vs 3-h food-deprived analysis is its N2 subset, and most of its strains are not in the paper. | DECIDED |
| 13 | 2026-09-30 | **Organizations carry ROR identifiers**, looked up rather than left blank (this container cannot reach api.ror.org or ror.org pages; ids come from web search and must be confirmed before import). **The dataset has its own licence** (NDI Cloud page), not the paper's. | DECIDED |
| 14 | 2026-09-30 | **Instruments record their product through an `instance_of` relation** (directed_relation, instrument subject -> product), NOT a `subject.product_id` field: the relation lets the product be added after the instrument without rewriting either document. Built in did-schema PR #78 (`9febf40`). The unit's serial number is not built. | DECIDED; BUILT, SIGNED, MERGED (#78) |
| 15 | 2026-09-30 | **Labs and departments are organizations** (openMINDS `Organization`), linked upward by `suborganization_of` (e.g. Salk Molecular Neurobiology Laboratory -> Salk; UCSD Neurosciences Graduate Program -> UCSD), so people can be affiliated with the unit they belong to. | DECIDED |
| 16 | 2026-09-30 | **Dataset licence: CC-BY-4.0** (the NDI Cloud dataset's own licence, confirmed by jess; the paper's is separate). | DECIDED |
| 17 | 2026-09-30 | **`strain.product_id` should become a relation** (strain -> product, a new term such as `distributed_as`; a strain is not a *unit* of a product, so not `instance_of`), for the same late-addition reason as instruments. `chemical.product_id` and `formulation.product_id` stay fields: there the product is part of what the document is. NOT BUILT: it changes an existing field (#73 audit 2 D9) that migrators and `did2.build` see, and JH does not need it (its strains carry WormBase ids). A did-schema proposal to raise when convenient. | DECIDED (direction); build deferred |
| 18 | 2026-09-30 | **Author roles and award recipients are recorded.** `directed_relation.roles` (14 CRediT roles + `corresponding author`) on each `has_author` edge; `awarded_to` (funding -> person/org) for each grant's recipients. Built in did-schema PR #78. | DECIDED; BUILT, SIGNED, MERGED (#78) |
| 19 | 2026-09-30 | **Dataset required fields:** `accessibility` = free access; `ethics_assessment` = not required (C. elegans and E. coli). | DECIDED |
| 20 | 2026-09-30 | **Shared entities live at the dataset level** (the dataset's own database): people, organizations, funding, publication, studies, software, products, strains and instruments are created once and referred to by id from each day's session. | DECIDED |
| 21 | 2026-09-30 | **Session directories are a separate output tree** (e.g. `haley_V2/<study>/<day>/`), for C. elegans and E. coli alike: the raw data is never written to, and sessions refer back to the raw files (the did2 backend has no file store yet, so the files stay where they are either way). E. coli could not do otherwise: all its images share one folder. | DECIDED |
| 22 | 2026-09-30 | **`session.description`** holds a day's free text: the notebook entry, the conditions, and notes (tableOfContents). Built, signed and merged: did-schema PR #79. | DECIDED; BUILT, SIGNED, MERGED (#79) |
| 23 | 2026-09-30 | **E. coli: one session per experiment** (`expNum`, 5 in `bacteria.mat`), not per imaging day. | DECIDED |
| 24 | 2026-09-30 | **Session naming.** `local_identifier` is the stable, spaceless handle (e.g. `foragingConcentration_0001`); `session.name` is the display name (e.g. `Foraging concentration, experiment 1 (1 Feb 2022)`). Spaceless is a convention `import_V2` follows, not schema-enforced: nothing checks `pattern` yet, and migrated subjects already carry spaces in `local_identifier`. Built, signed and merged: did-schema PR #79. Follow-up (not done): the session migrator passes a v1 `base.name` through untouched; it could move a non-empty one into `session.name`. | DECIDED; BUILT, SIGNED, MERGED (#79) |
| 25 | 2026-09-30 | **Creating a V2 session**: `ndi.setup.V2.createSession` writes `.ndi/V_eta.sqlite` with the V2 `session` document (+ `part_of` study relations) and the `reference.txt` / `unique_reference.txt` files, then opens it with the unchanged `ndi.session.dir` (which can open but not create a did2 session). | BUILT |
| 26 | 2026-09-30 | **Stage 3 builds the session list from the source's own day index.** C. elegans: one session per `tableOfContents.xlsx` row (local_identifier `<folder>_<experimentNumber>`, e.g. `foragingConcentration_0001`); foragingConcentration rows go to the grid or single study by the first word of `conditions`. E. coli: one per `expNum`, dated by its earliest `metaData.acquisitionTime`. `description` carries the notebook, conditions, worm range, inclusion and notes; the worm range is carried as written and checked against the worms at stage 5. Sessions are only written with `'Write', true`, under `OutputRoot` (default `<DATAPARENTDIR>/haley_V2/<folder>/<local_identifier>`). | BUILT |
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

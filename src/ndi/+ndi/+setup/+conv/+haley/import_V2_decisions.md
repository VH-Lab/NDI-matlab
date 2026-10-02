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
       2  metadata       people, organizations, funding, publication,
                         strains, products, instruments   (BUILT)
    B. per study (E. coli FIRST), tables loaded once + named corrections;
       per day:
       3  session        the studies (#50), then one session per day,
                         `part_of` its study
       4  subjects       cultivation (L4) plates, behaviour plates, patches, worms
       5  acquisition    camera / microscope system, one epoch per video or
                         image, clocks + syncgraph
       6  relations      patch part_of plate; worm contained_in its assay
                         plate and its acclimation plate, each with when (#52)
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

REVISED 2026-10-01 (jess): subjects now come BEFORE acquisition. The epochs-first
rule is about STATEMENTS (every statement needs a time reference); subjects are
entities and need none, and creating them first lets each recording name its plate
and each probe map name a real subject document.

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
| 27 | 2026-10-01 | **Recordings.** A plate has up to two: a short LAWN clip (`lawnFileName`, before the worms go in) and the BEHAVIOUR video (`videoFileName`). The table names `.avi` files; disk holds same-stem `.mp4` conversions, so files are matched by stem and the original name is recorded. WormLab `.csv` files (`wormLabFileName`) are not on disk. Mutants plate 1 (3 Nov 2023 07:35:52) has 0 frames and no file; Mini `camera` 0 means not recorded (6 rows). Both get no epoch and are reported. | DECIDED (from the data) |
| 28 | 2026-10-01 | **One acquisition system per camera** (`camera1`, `camera2`; one microscope for E. coli): each camera has its own clock. | DECIDED |
| 29 | 2026-10-01 | **The `software` documents naming NDI classes** (`ndi.daq.system.image`, the navigator, `ndi.daq.reader.image.ndr`) **live in each session**: `daqsystem_load` rebuilds objects from the session's own database (`+vintage/objectClass.m` searches the session; `session.m` `database_search` is scoped to the session id), and a session opened alone has no link to its dataset. Decision 20's shared software (StreamPix, WormLab, MATLAB) stays at the dataset level. | DECIDED |
| 30 | 2026-10-01 | **Lawn clips get a full extent**: the import opens each clip to read its frame count and rate (option B), with MATLAB's native `VideoReader` (no NANSEN). Behaviour videos take theirs from `experimentInfo`. | DECIDED |
| 31 | 2026-10-01 | **Probe maps** (`.epochprobemap.ndi`, one per epoch: the camera as probe, the plate's `local_identifier` as subject) are written into the session folder, never the raw data. | DECIDED |
| 33 | 2026-10-01 | **Acquisition systems are per session.** NDI rebuilds them only from the session's own database. The physical camera is the dataset-level instrument subject (stage 2, `instance_of` its product); each recording links the two: `instrument_id` = the camera subject, `acquisition_channels_id` -> that session's `acquisition_system`. #73 removed `epoch.instrument_id` on purpose ("the rig is recorded where it is always right -- on each recording statement"), so an epoch needs no edge to its system. | DECIDED |
| 34 | 2026-10-01 | **Each recording's file is an `opaque_body`** (`format` `video/mp4` or `image/tiff`: bytes laid out by their own format), owned by the recording statement, with `filename`, `size_bytes`, `content_hash` + `hash_algorithm`. At import it is NOT held: its file member `body_data_0` is recorded BY LOCATION in `files.file_info.locations` (the absolute path, `location_type` 'file', `ingest` 0) -- the record `ndi.document/add_file` already writes, which V2 allows unchanged (no schema change). Ingestion later takes the bytes in AS THEY ARE (never decoded: NDI's image ingester writes every frame uncompressed, ~11 GB for one 2 MB video); only the location changes. | DECIDED; BUILT |
| 35 | 2026-10-01 | **An epoch may carry its UTC extent** as an `absolute_time_reference` (today `epoch.time_reference_id` names only `relative_time_reference`, a side effect of keying the #52 family on `value.clock`). For the #52 rule the absolute member is the `utc` one. Built in did-schema PR #80 (with `session.time_reference_id`), signed and merged. | DECIDED; BUILT, MERGED (#80) |
| 36 | 2026-10-01 | **A native NDR video reader** (MATLAB `VideoReader`, no NANSEN) is built before stage 4 writes anything, so `acquisition_reader.reader_string` names it from the start. | DECIDED; IN PROGRESS |
| 37 | 2026-10-01 | **`local_identifier` prefixes.** Unique within the DATASET (the schema's rule for `subject` and `session`; `ndi.dataset` search spans every session), and plate/worm numbers restart per source folder, so every identifier starts with the folder name without `foraging`, lower-cased (`ndi.setup.conv.haley.idPrefix`): `concentration`, `matching`, `mini`, `mutants`, `sensory`, `ecoli`. Sessions follow (`concentration_0001`; was `foragingConcentration_0001`). Numbers are four digits everywhere. | DECIDED |
| 38 | 2026-10-01 | **Subjects, per session:** behaviour plates (`concentration_plate0011`, one per distinct `plateNum`; a plate filmed twice -- an hourly continuation or a restart after a glitch -- is ONE subject with two epochs), patches (`concentration_plate0011_patch0007`, one per row of `lawnCenters`, in `closestLawnID` order), worms (`concentration_worm0451`; `wormNum` is unique within a folder and the same across a plate's videos). | DECIDED |
| 39 | 2026-10-01 | **Growth (cultivation) plates are subjects**, one per (strain, pick time) in a session, numbered within the session by pick time then strain: `mutants_0001_growth0001`. The source has no id for them; the strain and pick time are DATA (assertion, manipulation time), not built into the name, so correcting either never renames a subject. | DECIDED |
| 40 | 2026-10-01 | **E. coli plates and patches.** `rectangle` template: 12 patches in a 3 x 4 grid, numbered row by row. `none` template: one large patch when seeded (`OD600` 1, 200 uL, 20 mm; plate 103's 20 uL at `OD600` 0 is a patch of LB alone, relative density 0 -- the eLife paper, Methods: "A '0' density solution was prepared with just LB"), or, with `lawnVolume` 0, a blank plate with no patch. Which detected patch in which image is which grid slot is a later calculation (registering the images); until then `lawnAnalysis` rows are measurements of the plate. | DECIDED |
| 41 | 2026-10-01 | **Mutants plate 1, 3 Nov 2023:** video 1 (07:35:52) is a failed start (0 frames, no file); 07:42:14 is its restart. | DECIDED (from the data) |
| 42 | 2026-10-01 | **Names and identifiers follow the eLife paper**, for a dataset that stands with it. The filmed plate is an ASSAY plate, the plate L4s are picked onto the day before is an ACCLIMATION plate (Methods: "Acclimation plates contained one large 200 µl patch [...]"). Identifiers are camelCase within a part, `_` between parts: `concentration_assayPlate0011`, `concentration_assayPlate0011_patch0007`, `mutants_0001_acclimationPlate0001`, `concentration_worm0451`, `ecoli_plate0042`. Subjects gain a display `name` (did-schema PR #80, `subject.name`): "Assay Plate 0011", "Patch 0007 on Assay Plate 0011", "Acclimation Plate 0001", "Worm 0451", "Plate 0042"; instruments `camera1` / `camera2` / `axiozoom1` / `spectramax1` are named "Camera 1", "Camera 2", "Axio Zoom.V16", "SpectraMax Plus 384". Names need not be unique and carry no study. | DECIDED |
| 43 | 2026-10-01 | **E. coli scope.** All 126 plates are subjects, analysed or not: the 33 unanalysed seeded plates are the low-density conditions (OD600 0, 0.05, 0.1) whose signal the paper says "could not be detected", and the blank plates (25, 26, 61, 90) and plate 103 (LB alone) are the "matched controls" the images were normalised against. All 1,575 image files are recordings: the 1,521 in `lawnAnalysis` plus 54 shared but unanalysed (`doImport` took only `lawnAnalysis`). The 2,150 `metaData` images with no file (brightfield, backgrounds, the 3,000 ms set of experiments 1-4, experiment 5's exposure sweep) are not recordings; each kept image notes its exposure and its background and brightfield `imageNum`. | DECIDED |
| 44 | 2026-10-01 | **Two camera-2 files on 6 May 2022** (`2022-05-06_15-09-24_2.mp4`, `2022-05-06_15-14-47_2.mp4`, concentration_0016) contain no plate: no epoch; the listing keeps reporting them. | DECIDED |
| 45 | 2026-10-01 | **Writing a session** (`'Write', true`, one or more sessions picked with `'Sessions'`): the session, its subjects, acquisition systems, epochs and recordings go into its V2 database in one transaction (`ndi.setup.conv.haley.sessionDocuments` builds them, `ndi.setup.V2.makeSessions` writes them). The session folder holds only `.ndi/`. The session's own `time_reference_id` is its UTC extent: the first recording's start to the last recording's end. | BUILT |
| 46 | 2026-10-01 | ~~One folder per epoch holding a hard link and a probe map~~ (dropped with the hard links, #32). The `epoch` document's `local_identifier` IS NDI's epoch id: the navigator reads it from there (#51). Each camera's `epoch_file_pattern` names its recordings' file names (`.*_1\.mp4`, `.*_2\.mp4`; the microscope `.*\.tiff`), and the navigator keeps only the bodies whose `filename` matches. | REVISED by #51 |
| 47 | 2026-10-01 | **The recording's `opaque_body` at import:** `format`, `filename`, `size_bytes`, `file_modified` (UTC), `content_hash` + `hash_algorithm` MD5 (`'Checksums'`, default true), and the file's location (#34). `description` names the file as the source table does (the `.avi`). The statement's `datum_type` (required when the value is in a body): a video's from VideoReader's `VideoFormat` (RGB24 / Grayscale -> `uint8`; RGB48 / Mono16 -> `uint16`; with `ReadVideos` false, `uint8` is assumed without opening the file), a TIFF's from its header; an unreadable file is skipped and reported. | BUILT |
| 48 | 2026-10-01 | **Times.** An epoch carries its UTC extent (`absolute_time_reference`, source time zone America/Los_Angeles) and, for a video, its `dev_local_time` extent from 0 (`relative_time_reference`, referent the session document). The recording statement points at a reference to the EPOCH (video: `dev_local_time` 0 to its duration; image: `during`) and at the epoch's UTC reference. A lawn clip's duration is known only when `ReadVideos` is true. | BUILT |
| 49 | 2026-10-01 | **Provisional, to check:** the recording statement's `variable` is the bare name `image intensity` (no ontology term yet); probe types (carried as the statement `method`, #51) are `brightfield-imaging` (cameras) and `wide-field-imaging` (microscope; the E. coli images are fluorescence); `acquisition_channels` carry no channels (the schema binds only ai/ao/di/do). | PROVISIONAL |
| 32 | 2026-10-01 | **How NDI finds the raw recordings** when the session folder is separate from the raw data. ~~Hard links in the session folder~~ (dropped 2026-10-01: macOS refused them -- `ln: Operation not permitted` from MATLAB, even within one disk -- and they made every Mac user change a security setting). Now NDI reads a recording through its documents: decision #51. | DECIDED; REVISED by #51 |
| 50 | 2026-10-01 | **The study documents are minted in stage 3**, beside the sessions they group (each spec study's `source_folder` / `source_condition` already assigns days to it), instead of in stage 2. Still dataset-level documents built from the spec, `part_of` the dataset: `ndi.setup.V2.datasetMetadata` takes `'Studies'` "exclude" (stage 2) / "only" (stage 3, with the run's one `DatasetId`). | DECIDED (user, 2026-10-01); BUILT |
| 51 | 2026-10-01 | **NDI finds a recording through its documents** (the long-term design of #34, built instead of hard links). `ndi.file.navigator.bodies`, named by each acquisition system's `epoch_file_pattern` (software `ndi.file.navigator.bodies`), builds the system's epochs from the database: acquisition_system <- acquisition_channels <- recording statement <- opaque_body. Epoch files = each body's file at the location it records (the V2 database backend now opens a file recorded by location and not ingested, `ndi.database.fun.externalFileLocation`; anything else still errors); epoch id = the `epoch` document's `local_identifier`; probe map = the system's name, the statement's `method` as the probe type, and the statement's subject (the plate's document id). It scans no folder and writes nothing: no links, no probe-map files, no hidden epoch-id files. A recording whose file is missing on this computer is left out with a warning. The location is an absolute path: moving the raw data means updating the locations (as for any NDI document whose file is not ingested); uploading to NDI Cloud rewrites them. | BUILT |
| 52 | 2026-10-01 | **Stage 6, relations** (`ndi.setup.conv.haley.relationDocuments`), all `directed_relation`, child -> parent. A **patch `part_of` its plate** (assay or E. coli plate; BFO:0000050; no time -- it holds for the plate's whole life). A **worm `contained_in` each plate it was on, in turn** (RO:0001018 "contained in": located in the space another material entity encloses -- a worm on the agar of a closed dish; RO's "located in" is RO:0001025): its acclimation plate from the pick (`growthTimePicked`), its food deprivation plate (#53) from the move to it (`starvedTime`), its assay plate from the transfer T. Each window ends when the next one starts; the assay window ends when filming ends. **T is not recorded.** The eLife paper (Methods, pp. 22-23): single-density assays moved the worms by agar plug through "an empty NGM plate" to the condition plate, after the condition plate's 1 h at room temperature; multi-density assays moved them by eyelash pick "immediately prior to the assay plate being placed on the imaging setup", recording starting "once the droplet evaporated". It measures "the duration of time since transfer (i.e., the time elapsed in the experiment)" (p. 29), and the source's own `wormGrowth` / `lawnGrowth` run to `timeRecord`. So T = the plate's first behaviour video start, marked approximate (the assay window's start and the end of the window before it). **Where the worms went on before the 'contrast' (lawn) video, T is the lawn clip's start instead** (if within an hour before recording). Which plates: from the gap between each plate's lawn clip and its first behaviour video, per study and day (lawn first: hours in early Concentration, 6-10 min later; worms first: 0.1-1.5 min), confirmed by eye in the videos 2026-10-02 -- Concentration lawn first throughout; Mini worms first throughout; Matching days 1-3 (to 2023-04-04) lawn first except `2023-04-04_16-10-14_2`, days 4-5 worms first; Mutants and Sensory worms first. (`lawnRegistration` is a registration-fit score and `arenaOffset` the arena's position in the frame -- neither records the order; the analysis code, shreklab/Haley-et-al-2024.) Transfer methods: agar plug through an empty NGM plate (Concentration, Mini); eyelash pick into an S-Complete droplet (Matching, Mutants, Sensory). All of it is data in the spec's `transfer_protocol` (rules + named exceptions), applied by `ndi.setup.conv.haley.transferTime`. **Precision** (user, 2026-10-02): video times are exact; the pick time and T are approximate (the start flag); a window's duration is approximate whenever either of its ends is -- an `absolute_time_reference` is start + duration, so an approximate start cannot carry an exact end, and the exact end of filming is stated by the epochs' own references. `starvedTime`: exact for now (to confirm). One time reference per (plate, assay plate), shared by its worms (all moved together). No time where the source has none (an unfilmed plate, a missing pick time). Plates are not related to each other. The brief empty-NGM transfer plate is not a subject. | DECIDED (user, 2026-10-01: relation terms); T: DECIDED (user, 2026-10-02); BUILT **Ends (2026-10-02, needs did-schema CHANGE 6):** each window also records its `end`, with that end's own precision: the end of filming is exact, and an end at the next window's start (a transfer T) is approximate. So the assay window reads start ≈ T, end exact. **Order corrections (2026-10-02, from the lawn-clip-to-recording gap over 541 plates, checked by Jess in the videos):** Matching day 1 (2023-02-24) was worms first (days 2-3 lawn first); Concentration 2022-09-02 08:48:41 (both cameras) was worms first -- the contrast video was taken late, 2.6 s before recording. Both are in the spec's `transfer_protocol` (a dated rule and two exceptions). |
| 53 | 2026-10-01 | **Food Deprivation Plates** (the paper's "3 hr of food deprivation"; Mutants and Sensory, `starvedTime` / `starvedDuration`): food-deprived worms were moved from their acclimation plate to an unseeded plate before the assay, so that plate is a subject, one per (session, strain, `starvedTime`), numbered within the session by that time then strain: `mutants_0001_foodDeprivationPlate0001`, "Food Deprivation Plate 0001" (name chosen to match the paper's "food-deprived"; it does not name the plate, and its "empty NGM plate" is the brief transfer plate). `subjectList` gains columns `deprivation` and `worms_placed` (was `pick`). | DECIDED (user, 2026-10-01); BUILT |
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

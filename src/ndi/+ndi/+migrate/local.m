function result = local(path, options)
%LOCAL Migrate a local NDI dataset/session to V_eta on disk.
%
%   RESULT = ndi.migrate.local(PATH) migrates the on-disk did_v1
%   database under PATH/.ndi to the V_eta wire format (the only
%   TargetVersion) by reading every document
%   body via the did2 v1 readers, running did2.convert.v1_to_v2 per
%   body plus the V_eta second pass, and writing the surviving docs
%   into PATH/.ndi/<TargetVersion>.sqlite via did2.database.sqlitedb.
%
%   The function acquires an exclusive lock at PATH/.ndi/.migrate.lock
%   for the duration of the run, so concurrent migrations of the same
%   dataset fail fast instead of corrupting each other.
%
%   STATUS of the 2026-08-10 edit (V_eta second-pass step (7),
%   did2.convert.resolveSessionAnchors): WRITTEN WITHOUT MATLAB and NOT
%   EXECUTED. The pass itself has never been run anywhere. It is wired in its
%   OWN try/catch like every sibling, so a failure leaves the time references
%   in pass-1 form and the rest of the migration proceeds.
%
%   STATUS of the SECOND 2026-08-10 edit (V_eta second-pass step (4b),
%   did2.convert.resolveDatasetEntities): WRITTEN WITHOUT MATLAB AND NOT
%   EXECUTED -- there is no MATLAB in the container this was written in, so
%   nothing below has been run, here or anywhere. What it fixes is a
%   GATE/PRODUCTION DIVERGENCE, not a bug in the pass: all three DID-side
%   call sites (did2.unittest.helpers.runCorpusDiscovery:79,
%   testCorpusPRED:93, testFixtureCorpus:279) have always run this pass, and
%   this file never did, so every green corpus run has been green on a
%   `dataset` dedup + membership prune that the real migration path did not
%   perform. Wired in its OWN try/catch like every sibling, so a failure
%   leaves the dataset entity layer in pass-1 form (duplicate `dataset`
%   entities sharing one base.id, and `migrated_session_membership` edges
%   whose member session is in another database) and the rest of the
%   migration proceeds -- which is exactly today's state.
%
%   STATUS of the SECOND 2026-08-11 edit (V_eta second-pass step (7d),
%   did2.convert.foldGenericFiles): WRITTEN IN A CONTAINER WITH NEITHER MATLAB
%   NOR OCTAVE -- `command -v matlab octave octave-cli` returns nothing -- so
%   it has NOT been executed here, and this file is not covered by the DID
%   corpus gate either. did2.unittest.testBatchPassWiring prints, REPORT-ONLY,
%   whether this call site names every batch post-pass; that print is the only
%   thing anywhere that compares this wiring against the DID one.
%
%   THIS FILE IS NOT READ-ONLY, and an earlier session recorded that it was.
%   Corrected in DID-matlab `b9bce5b`; the gap was not someone else's.
%
%   STATUS of the 2026-08-11 edit (V_eta second-pass steps (7b) and (7c),
%   did2.convert.resolveResponseParameters and
%   did2.convert.resolveLawnPlateSubjects): WRITTEN IN A CONTAINER WITH NO
%   MATLAB AND NO OCTAVE, so NOT ONE LINE OF IT HAS BEEN EXECUTED, here or
%   anywhere. Same shape as the two edits above and found the same way, but by
%   an instrument this time rather than by accident: did2.unittest.
%   testBatchPassWiring now ASSERTS the cross-repo matrix against a checked-in
%   divergence table, and these two were the rows with no reason to be in it.
%   Both are wired in their OWN try/catch like every sibling, so a failure
%   leaves the affected documents in pass-1 form.
%
%   THE MEASUREMENT THAT PROMPTED IT, so the next reader does not have to
%   re-take it. BEFORE this edit: this file called 13 passes (10
%   ndi.migrate.internal.* + 3 did2.convert batch passes), each DID-side call
%   site called 6, and they OVERLAPPED IN 3 -- epochMint,
%   resolveSessionAnchors, resolveDatasetEntities. Ten divergent rows is
%   enough noise to hide an eleventh, which is precisely how
%   resolveDatasetEntities came to sit unwired. AFTER it: 15 here, 6 there,
%   overlapping in 5. ONE DID-side pass remains unrun here on purpose --
%   did2.convert.resolveDeferredBaths, which
%   ndi.migrate.internal.stimulusBathToBath supersedes in that file's own
%   words ("the LIVE-session counterpart of the coarse
%   did2.convert.resolveDeferredBaths.makeBathVeta", :157).
%
%   Options (name-value):
%     DryRun           (1,1 logical, default false) - report what
%                      would change without writing the V_eta
%                      database, the quarantine sidecar, or the
%                      backup directory. The result struct still
%                      carries the migrated documents in-memory and
%                      a populated references report so the caller
%                      can preview the outcome.
%     Backup           (1,1 logical, default true)  - copy the
%                      entire .ndi directory to PATH/.v1-backup
%                      before touching any files. No-op if the
%                      backup directory already exists.
%     ContinueOnError  (1,1 logical, default true)  - quarantine
%                      per-document failures and keep going. When
%                      false, the function raises after the pass
%                      if any document failed.
%     Verbose          (1,1 logical, default false) - print the
%                      end-of-run summary to stdout.
%     Validate         (1,1 logical, default true)  - validate each
%                      migrated document against its V_eta schema
%                      during conversion and again on insert into
%                      the V_eta database. Tests with no schema
%                      cache available may pass false; production
%                      callers should leave this true.
%     SchemaCache      ([] or a did2.schema.cache handle, default
%                      []) - override the shared schema cache. Used
%                      by tests; production callers should rely on
%                      ndi.schemas.init having set the active cache.
%     TargetVersion    (1,:) char, default 'V_eta') - migration
%                      target wire format, and 'V_eta' is the only value
%                      accepted; any other is an argument error. The
%                      option is kept so a caller can
%                      name the target it means. 'V_eta' (Brainstorm J)
%                      routes split-eligible classes through the
%                      +migrators_j migrators (1 -> N) and runs a second
%                      pass using the open body set: it resolves
%                      session-context-dependent deferrals (e.g.
%                      stimulus_bath -> dose_manipulation) and promotes
%                      attributed anatomical loci to Path-S part-subjects
%                      (a part-`subject` + `term_assertion` + `part_of`
%                      relation, retargeting the co-anchored manipulation).
%                      Writes <TargetVersion>.sqlite. The 'V_epsilon' and
%                      'V_zeta' targets were removed with did-schema #88,
%                      which deleted schemas/V_alpha .. V_zeta (OPEN_WORK
%                      #128); asking for either is an argument error.
%
%   RESULT is a struct with fields:
%       path         - the input PATH (char).
%       source       - struct describing the v1 source that was
%                      read: `kind` ('sqlite', 'dumbjsondb', or
%                      'none' when the function consumed the
%                      existing V_eta.sqlite instead) and `path`
%                      (char).
%       destination  - absolute path of the V_eta.sqlite file
%                      this run wrote (or would write, when DryRun
%                      is true).
%       alreadyMigrated - logical; true when V_eta.sqlite
%                      already existed and the run did a fast
%                      idempotent pass (read it, re-validate).
%       dryRun       - logical mirror of the DryRun option.
%       backup       - struct with `enabled` (the option value),
%                      `path` (target directory), and `created`
%                      (logical, true iff this run wrote it).
%       summary      - the `summary` field returned by
%                      did2.convert.v1_to_v2 (`total`,
%                      `migrated_count`, `quarantine_count`,
%                      `by_class`).
%       quarantine   - struct array of per-doc failures (see
%                      did2.convert.v1_to_v2).
%       quarantineFile - absolute path to the on-disk quarantine
%                      sidecar, '' when nothing was written.
%       references   - report from did2.validate.references over
%                      the migrated documents.
%       secondPass   - (V_eta) one report per second-pass step, including
%                      softwareDedupAfterPassOne / softwareDedup (the two
%                      software merges) and dimensionTerms (the census of
%                      dimensions written whose term has no node).
%
%   SoftwareDedupAfterPassOne (V_eta; default true): merge the duplicate
%   software / operating-system / interpreter entities right after pass 1
%   as well as at the end (Decided by Jess Haley, 2026-10-22 [software dedup
%   after pass one], did-schema V_eta_go_forward_class_audit.md), so every
%   later step carries the deduplicated set. False runs the end-of-run merge
%   alone; it exists so a test can show the final document set is the same
%   either way (TestSoftwareDedupAfterPassOne).
%
%   Idempotency:
%       Re-running on a dataset that already has a V_eta.sqlite
%       under .ndi is a fast no-op modulo validation: the function
%       loads every document from the existing V_eta.sqlite,
%       re-runs did2.convert.v1_to_v2 (which short-circuits bodies
%       already at V_eta), and re-validates references. Nothing is
%       written when DryRun is true OR the file is
%       byte-equivalent to what would have been produced. To force
%       a full re-migration, delete PATH/.ndi/V_eta.sqlite first.
%
%   Errors:
%       NDI:migrate:badPath         - PATH is not a directory.
%       NDI:migrate:noNdiDir        - PATH/.ndi is missing; not
%                                     an NDI session/dataset root.
%       NDI:migrate:noV1Source      - .ndi exists but contains no
%                                     recognised v1 store and no
%                                     V_eta.sqlite.
%       NDI:migrate:locked          - another migration is in
%                                     flight (or left a stale lock).
%       NDI:migrate:hadQuarantine   - ContinueOnError=false and at
%                                     least one document failed.
%
%   See also: did2.convert.v1_to_v2, did2.convert.fromV1Database,
%             did2.validate.references, did2.database.sqlitedb.

    arguments
        path (1,:) char
        options.DryRun (1,1) logical = false
        options.Backup (1,1) logical = true
        options.ContinueOnError (1,1) logical = true
        options.Verbose (1,1) logical = false
        options.Validate (1,1) logical = true
        options.SchemaCache = []
        options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'V_eta', 'did_v2'})} = 'V_eta'
        options.SoftwareDedupAfterPassOne (1,1) logical = true
    end

    % [schema set renamed did_v2] (Jess Haley, 2026-10-25), step 1 "accept
    % both names": 'did_v2' is the same set as 'V_eta'. Until DID-matlab and
    % did-schema take the new name, it is passed on (and names the database
    % file) as 'V_eta'.
    if strcmp(options.TargetVersion, 'did_v2')
        options.TargetVersion = 'V_eta';
    end

    if ~isfolder(path)
        error('NDI:migrate:badPath', ...
            'Path "%s" is not a directory.', path);
    end

    ndiDir = fullfile(path, '.ndi');
    if ~isfolder(ndiDir)
        error('NDI:migrate:noNdiDir', ...
            ['"%s" has no .ndi directory; not an NDI ' ...
             'session/dataset root.'], path);
    end

    % STEP MARKS (instrumentation only; nothing below depends on them). After
    % each top-level step one "[migrate step]" line gives the step's wall
    % time, the time since this function started, the process RSS (Linux
    % only: VmRSS / VmHWM from /proc/self/status) and the current document
    % count. The Soph runner was lost inside this function with nothing
    % printed for the span (NDI-matlab Soph runs 39667921479 .. 39731147165);
    % these lines say which step it reached and how much memory it held.
    tStart = tic;
    tStep = tStart;

    lockFile = fullfile(ndiDir, '.migrate.lock');
    lockHandle = acquireLock(lockFile);
    lockCleanup = onCleanup(@() releaseLock(lockHandle));

    % A document whose v1 source states no creation time carries the time the
    % migration ran ([no invented values], Jess Haley, 2026-10-25): one time
    % for the whole pipeline, pinned here so every DID pass and NDI's second
    % pass write the same one, and released when this returns.
    if isempty(did2.convert.migrationTime('get'))
        did2.convert.migrationTime('pin');
        unpinMigrationTime = onCleanup(@() did2.convert.migrationTime('unpin'));
    end

    dstPath = fullfile(ndiDir, [options.TargetVersion '.sqlite']);
    quarantineFile = fullfile(ndiDir, 'migrate_quarantine.json');
    backupDir = fullfile(path, '.v1-backup');

    alreadyMigrated = isfile(dstPath);
    backupCreated = false;
    if alreadyMigrated
        [bodies, srcInfo] = readBodiesFromTarget(dstPath);
    else
        [srcKind, srcPath] = detectV1Source(ndiDir);
        srcInfo = struct('kind', srcKind, 'path', srcPath);
        if strcmp(srcKind, 'sqlite')
            bodies = did2.convert.readers.sqliteV1(srcPath);
        elseif strcmp(srcKind, 'dumbjsondb')
            bodies = did2.convert.readers.dumbJsonV1(srcPath);
        else
            error('NDI:migrate:noV1Source', ...
                ['No recognised v1 database (did-sqlite.sqlite or ' ...
                 'Object_id_*_v*.json) and no %s.sqlite found ' ...
                 'under "%s".'], options.TargetVersion, ndiDir);
        end
        if options.Backup && ~options.DryRun && ~isfolder(backupDir)
            copyBackup(ndiDir, backupDir);
            backupCreated = true;
        end
    end
    tStep = migrateStepMark(sprintf('read v1 bodies (%d)', numel(bodies)), ...
        tStart, tStep, []);

    % The converter args. The target is always named, never left to
    % did2.convert.v1_to_v2's default.
    v2args = {'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'Verbose', false, ...
        'TargetVersion', options.TargetVersion};
    % Migrated recordings link their epoch files as data bodies (Jess Haley,
    % 2026-10-21, did-schema V_eta_recording_observation_plan.md): one
    % observation per element per epoch, its epoch files as opaque_bodies by
    % location. did2.convert.resolveEpochProbemap builds them from the cached
    % `epochfiles_ingested` documents; a session never ingested has none, so
    % the file navigators supply the same facts as TRANSIENT bodies (converted
    % with the rest so epochMint mints their epochs, removed after the
    % probemap pass). See ndi.migrate.internal.navigatorEpochFiles.
    navigatorEpochReport = [];
    convertInput = bodies;
    if strcmp(options.TargetVersion, 'V_eta') && ~alreadyMigrated
        try
            [navBodies, navigatorEpochReport] = ...
                ndi.migrate.internal.navigatorEpochFiles(path, bodies);
            convertInput = [bodies(:)', navBodies];
        catch ME
            warning('NDI:migrate:navigatorEpochFilesFailed', ...
                ['Reading the file navigators failed (%s); epochs with no ' ...
                 'epochfiles cache get no recording observation.'], ME.message);
        end
    end
    tStep = migrateStepMark(sprintf('navigatorEpochFiles (%d input bodies)', ...
        numel(convertInput)), tStart, tStep, []);
    convertResult = did2.convert.v1_to_v2(convertInput, v2args{:});
    tStep = migrateStepMark('pass 1 v1_to_v2', tStart, tStep, convertResult);
    % Pass 1's record of the v1 documents no migrator changed, kept here
    % before any later step can touch convertResult (see the final v1 stamp
    % below, [passthrough stays v1: how]).
    passOneRecord = [];
    if isfield(convertResult, 'passthrough')
        passOneRecord = convertResult.passthrough;
    end
    % and what each source became (its pass-1 output ids), for the final
    % sweep of [dependents of a carried document carry] below
    passOneSourceOutputs = struct('input_index', {}, 'id', {}, 'output_ids', {});
    if isfield(convertResult, 'source_outputs') && isstruct(convertResult.source_outputs)
        passOneSourceOutputs = convertResult.source_outputs;
    end
    printMigrationNoteCounts(convertResult);

    % --- software dedup, right after pass 1 ----------------------------------
    % Decided by Jess Haley, 2026-10-22 [software dedup after pass one]
    % (did-schema V_eta_go_forward_class_audit.md): pass 1 mints one software /
    % operating-system / interpreter entity per consuming document (Soph: 665k
    % documents before the end-of-run merge, 224k after; 14.4 GB RSS plus 5 GB
    % swap on a 16 GB runner), so every second-pass step used to carry and
    % copy the duplicates. They are merged HERE, and the end-of-run merge (6)
    % still runs, for the software entities later steps mint (the clock
    % alignment rule class, bodies the deferral pass re-folds). The merge is
    % idempotent on a merged set; TestSoftwareDedupAfterPassOne shows the final
    % document set is the same with and without this step.
    softwareDedupEarlyReport = [];
    if strcmp(options.TargetVersion, 'V_eta') && options.SoftwareDedupAfterPassOne
        try
            [convertResult, softwareDedupEarlyReport] = ...
                resolveSoftwareDedup(convertResult);
        catch ME
            warning('NDI:migrate:softwareDedupFailed', ...
                ['Software dedup after pass 1 failed (%s); the end-of-run ' ...
                 'merge still runs.'], ME.message);
        end
        tStep = migrateStepMark('resolveSoftwareDedup(after pass 1)', ...
            tStart, tStep, convertResult);
    end

    % --- second pass: context-dependent (session-aware) deferrals ----------
    % Some V_eta classes cannot be migrated from a single document alone
    % (e.g. stimulus_bath -> dose_manipulation needs the stimulator element's subject and
    % epoch). The per-document converter defers those with reason
    % did2:convert:needsSessionContext; resolve them here, where the whole
    % body set (the session/element graph) is in hand, then fold the
    % assembled bodies back through v1_to_v2 (which short-circuits them as
    % already-target) so they are padded/validated on the same footing.
    %
    % Sub-passes that are INSTRUMENTS as well as builders return a report and
    % it is carried onto RESULT.secondPass, denominator included, whether or
    % not they changed anything -- a count with no denominator is not evidence.
    % Empty means "did not run" (a non-V_eta target, or the sub-pass threw).
    ensembleReport = [];
    % [pipeline defects are not carries] (Jess Haley, 2026-10-26, did-schema
    % V_eta_go_forward_class_audit.md): a second-pass step that throws is a
    % DEFECT, reported in RESULT.secondPassErrors apart from the carries
    stepErrors = struct('step', {}, 'message', {});
    bathAnchors = [];   % resolveDeferred -> resolveEpochAnchorFold (did-schema #88)
    % resolveStimulusPresentations -> resolveEpochAnchorFold ([presentation
    % anchored to its epoch], Jess Haley, 2026-10-27)
    presentationAnchors = [];
    strainReport = [];
    subjectStrainReport = [];
    openmindsCitationsReport = [];
    datasetEntitiesReport = [];
    epochMintReport = [];
    epochAnchorReport = [];
    recordingAttributionReport = [];
    sessionAnchorReport = [];
    epochProbemapReport = [];
    responseParametersReport = [];
    genericFileFoldReport = [];
    validIntervalReport = [];
    clockAlignmentReport = [];
    softwareDedupReport = [];
    dimensionTermReport = [];   % [] = not measured
    ontologyRowReport = [];
    ontologyLabelReport = [];
    stimulusSequenceReport = [];
    sliceTetanusReport = [];
    regionSitesReport = [];
    regionLocatedReport = [];
    epochSeriesBodiesReport = [];
    if strcmp(options.TargetVersion, 'V_eta')
        % V_eta's second pass has the kinds of work enumerated below, all
        % needing the whole migrated body set (the corpus-wide session/element
        % graph).
        %
        % (This line used to say "eight kinds of work" while the list beneath
        % it had thirteen entries -- a hand-kept count sitting beside the thing
        % it counts, drifting one further every time an entry was added, and
        % always in the direction of less work than is really here. The count
        % is DELETED rather than corrected: the list is its own denominator.
        % did2.unittest.testBatchPassWiring is the instrument that now compares
        % this file's CALLS against the DID-side call sites.)
        %   (1) DEFERRALS: some J migrators still defer a document that needs
        %       session context -- stimulus_bath (-> dose_manipulation, D8
        %       retired the bath family). Resolve them the same way the older
        %       targets do (assembleDeferred), just at TargetVersion V_eta.
        %   (1b) ONTOLOGY TABLE ROWS ARE COUNTED, NOT RESOLVED: Decided by
        %       Jess Haley, 2026-10-30 [table rows carried as v1] (did-schema
        %       V_eta_go_forward_class_audit.md): the generic migration
        %       carries every v1 `ontologyTableRow` whole as v1; it resolves
        %       no subject and fans out no statements, because a row does not
        %       state which entity each column is about. Pass 1 carries every
        %       row (carry-026). This step only counts the rows and how many
        %       the migrated set still holds as a table row. See
        %       ndi.migrate.internal.ontologyRowsCarried.
        %   (1c) ONTOLOGY LABEL SUBJECTS: an `ontologyLabel` names the document
        %       it labels (`document_id`), never a subject, so pass 1 passes it
        %       through (~7,007 documents in JH). Here the referent is followed
        %       one hop -- imageStack -> image_observation -> subject_id -- and
        %       the label becomes a `term_observation` about that subject with
        %       `derived_from_1` still naming the labelled statement, id
        %       PRESERVED. The E. coli half of the JH corpus has no subject to
        %       inherit (doImport.m:789,811,827 set `document_id` only); those
        %       are COUNTED and left passing through, pending a team call.
        %       See ndi.migrate.internal.ontologyLabelSubjects.
        %   (2) PATH-S: an attributed anatomical locus is promoted to a
        %       part-subject. Run AFTER the deferrals so a manipulation the
        %       deferral emits can be a Path-S retarget candidate.
        %   (3) ENSEMBLE MEMBERSHIP: each `ensemble` map document becomes
        %       `member_of` edges (neuron-subject -> ensemble group-subject,
        %       EPOCH-SCOPED, carrying column order in `order`) plus
        %       `derived_from` provenance for the combined-binary cache.
        %       Adds only; drops nothing (the verify-before-delete gate has not
        %       run). See ndi.migrate.internal.ensembleMembership.
        %
        %       ORDER: MOVED to after (7)/epochMint, FOR A REAL REASON, and it
        %       is the same reason (7e) states. The signed model requires the
        %       edges to be epoch-scoped -- the recorded neuron set changes
        %       epoch to epoch, so an unscoped roster flattens a per-epoch
        %       fact -- and the `epoch` documents those edges point at exist
        %       only after epochMint. Run before it, this pass could emit
        %       nothing but unscoped edges, which is what it did.
        %
        %       AN EPOCH THAT DOES NOT RESOLVE still gets its edge, UNSCOPED,
        %       counted in its own field. Membership is preserved; only the
        %       per-epoch fact is missing, and it is never missing silently.
        %   (4) STRAIN ASSEMBLY: the unattached `openminds` Strain documents
        %       become `strain` entities (ids preserved), consuming their
        %       Species / GeneticStrainType fragments. See
        %       ndi.migrate.internal.strainAssembly.
        %   (4a) OPENMINDS CITATION GRAPH (TEAM DECISION 2026-08-11, "Do B"):
        %       the OTHER thing that lands in the bare `openminds` class. Where
        %       (4) assembles the Haley strain family, this assembles the
        %       dataset CITATION graph the metadata app writes -- Dataset ->
        %       DatasetVersion -> Person / Affiliation / Organization / ORCID /
        %       ContactInformation / Funding / Contribution / DOI /
        %       WebResource / License -- into the same six entity classes
        %       `metadata_editor` emits, ids preserved wherever the model
        %       allows. Lives DID-side (did2.convert.resolveOpenmindsCitations)
        %       beside its siblings, so the corpus discovery harness runs the
        %       same code this does.
        %
        %       IT IS ADDITIVE, NOT A REPLACEMENT. The graph holds only a DOI
        %       for a related publication -- no title, no PMID, no PMCID;
        %       ndi.database.metadata_app.fun.resolveRelatedPublication
        %       recovers those over the NETWORK -- while the editor blob
        %       carries all four. Neither store dominates and 0 of 6 corpora
        %       carry both, so the `metadata_editor` route stays exactly as it
        %       is and this pass fabricates nothing to close the gap.
        %
        %       ORDER: after (4) and BEFORE (4b), which is the order all three
        %       DID call sites use. Before (4b) is load-bearing: that pass
        %       keeps the RICHEST `dataset` entity per id, and the entity
        %       minted here is keyed on the same dataset id as the
        %       `dataset_remote` stubs, so it must exist when the ranking runs.
        %       It commutes with (4): a citation component is disjoint from a
        %       strain component (this pass touches only components holding a
        %       DatasetVersion, and withholds any that plans a subject-side
        %       openMINDS type), and consumption is all-or-none per connected
        %       component so neither pass can strand the other's edges.
        %   (4b) DATASET ENTITY LAYER: dedup the `dataset` entities and prune
        %       the unresolvable `session -part_of-> dataset` edges. FOUR
        %       dataset-level v1 sources (metadata_editor / dataset_remote /
        %       session_in_a_dataset / dataset_session_info) each mint a
        %       `dataset` entity keyed on the SAME dataset id, so a dataset with
        %       several of them ends up with several entities sharing ONE
        %       base.id; and the membership edge is emitted best-effort, so a
        %       LINKED member session (documents in a separate database, not
        %       this batch) leaves the edge's child dangling. Keep the richest
        %       entity per id, drop the dangling edges. Lives DID-side
        %       (did2.convert.resolveDatasetEntities) beside epochMint and
        %       resolveSessionAnchors, so the corpus discovery harness runs the
        %       same code this does.
        %
        %       WHY IT IS ONLY BEING WIRED NOW, stated plainly: it was NEVER
        %       wired here. All three DID-side call sites have run it since it
        %       was written; this file has not, so the corpus gate and this
        %       production path were structurally different pipelines and every
        %       green run was green on work production skipped. The absence was
        %       flagged by did2.unittest.testBatchPassWiring, which prints the
        %       four-pass x four-site matrix, and its own header refused to call
        %       the absence a finding ("THAT IS AN ABSENCE, NOT A FINDING").
        %       So it was CHECKED, not assumed: the whole +migrate tree (16 .m
        %       files) never names the `dataset` or `session` class, in any
        %       spelling; `migrated_session_membership` -- the base.name
        %       sentinel the prune keys on (jEntityRelation.m:3, written by
        %       jMembershipBodies.m:15-16) -- has ZERO occurrences in NDI-matlab
        %       in ANY file type, on this branch and on origin/main; and the
        %       only NDI-side code that touches session_in_a_dataset /
        %       dataset_session_info (ndi.dataset.repairDatasetSessionInfo,
        %       ndi.dataset.dir, +cloud/+sync) operates on LIVE did_v1
        %       documents in a live session object and does something else
        %       entirely -- it breaks a nested aggregate into per-session
        %       documents. It does not, and cannot, dedup a V_eta `dataset`
        %       entity: that class does not exist in did_v1. So there is no
        %       equivalent under another name, and this is NOT the deliberate
        %       omission that did2.convert.resolveDeferredBaths is (that one is
        %       superseded by a precise replacement which says so in its own
        %       words -- ndi.migrate.internal.stimulusBathToBath, the comment
        %       beginning "This is the LIVE-session counterpart of the coarse
        %       did2.convert.resolveDeferredBaths.makeBathVeta").
        %
        %       ORDER: after (4), before (5). NO DEPENDENCY FORCES IT, and that
        %       is said rather than dressed up. It must land between the
        %       deferrals and (5) to keep the relative order the three DID call
        %       sites use, and within that gap the position is a judgement:
        %       the prune decides an edge's fate from an index of the ids
        %       PRESENT, so it should see the most complete document set it can,
        %       and every sub-pass here that ADDS documents runs before this
        %       point. Nothing today makes that load-bearing -- no sub-pass in
        %       this block mints or removes a `session` or a `dataset` document
        %       (the classes they mint are bath, dose, dose_manipulation,
        %       pharmacological_manipulation, time_reference,
        %       epoch_bounded_reference, subject_manipulation, visual_grating,
        %       timed_sequence_manipulation (this read
        %       `visual_grating_manipulation` until 2026-08-17, when the
        %       presentation pass was repointed at the decomposition; the
        %       claim the paragraph makes is unaffected either way),
        %       sampled_body, data_body, term,
        %       term_observation, subject_observation, strain,
        %       directed_relation, entity, epoch, relative_reference), and
        %       (5)/(7) index `session` documents by an exact class-name match
        %       (epochMint.m:282, resolveSessionAnchors.m:206) so a duplicate
        %       `dataset` entity cannot pollute either index whichever way round
        %       they run. Dropping a duplicate cannot dangle an inbound edge
        %       either, because the duplicates SHARE the surviving id.
        %       See ndi.migrate.internal -- deliberately NOT there: the pass is
        %       DID-side so the gate and production run the same code.
        %   (4c) SUBJECT-ATTACHED STRAIN ASSEMBLY (#78): the OTHER half of the
        %       strain family, and the half with the volume in it. Where (4)
        %       assembles the handful of UNATTACHED `openminds` Strain
        %       documents, this one handles `openminds_subject` -- the Strain
        %       objects the four SubjectInformationCreators build per table
        %       row. Pass 1 migrates each 1->1 into a `term_assertion` and
        %       drops the `openminds_#` links
        %       (openminds_subject.m:52 `body.depends_on =
        %       jCarrySubject(preBody, {'subject_id'})`, an ASSIGNMENT), so
        %       after pass 1 the pedigree, the genetic strain type and the
        %       species child are unreachable from the migrated set. This pass
        %       mints one DEDUPLICATED `strain` entity per distinct strain,
        %       puts `strain_id` back on the assertion, wires
        %       `background_strain_#`, moves the `genetic strain type`
        %       assertion onto the strain and drops the duplicate `species`
        %       assertion the Strain's own Species child produces -- the four
        %       "Migration consequences" of the signed model
        %       (V_eta_openminds_family_record.md Part 6, TEAM-SIGN-OFF jess
        %       2026-08-05).
        %       See ndi.migrate.internal.subjectStrainAssembly.
        %
        %       IDS ARE NOT PRESERVED HERE and that is FORCED, not chosen --
        %       the assertion already carries the source id (pass 1 keeps
        %       `base` verbatim), and dedup collapses hundreds of documents to
        %       one entity so at most one id could survive anyway. Safe here
        %       and NOT safe for (4): the only place a strain document's id is
        %       captured into ordinary data is `bacteriaStrain`
        %       (haley/doImport.m:164,734), and the `strainDoc` there is the
        %       return of the BARE call at :87/:706 -- (4)'s documents, not
        %       these. Checked before it was written, not assumed.
        %
        %       ORDER: after (4b), before (5). NO DEPENDENCY FORCES IT and that
        %       is said rather than dressed up. It commutes with (4), (4a) and
        %       (4b): (4) reads only the bare `openminds` class and this one
        %       only ever touches a v1 body whose MIGRATED counterpart is a
        %       `term_assertion`, so neither can see the other's documents;
        %       (4a) touches the citation graph, (4b) the `dataset` layer, and
        %       neither reads or writes a `term_assertion` or a `strain`. It
        %       is placed after (4b) rather than beside (4) so the relative
        %       order of the two DID-side passes -- which is pinned to the
        %       three DID call sites -- is not disturbed by an NDI-only
        %       insertion.
        %
        %       IT NEEDS THE did_v1 BODIES, which is what makes it NDI-side
        %       (the same contract fact as imagedEntitySubjects: every DID-side
        %       pass is f(result,
        %       options) and `result` never carries the bodies).
        %   (5) EPOCH MINT (#60): one `epoch` entity per distinct
        %       (base.session_id, epoch-id string). The KEY IS THE PAIR --
        %       an `epochid.epochid` string is reused across sessions (142 of
        %       corpus B's 149 distinct ids), so keying on the string alone
        %       would fuse epochs from different sessions. Lives DID-side
        %       (did2.convert.epochMint) beside resolveDatasetEntities, so the
        %       corpus discovery harness runs the same code this does.
        %   (5b) EPOCH ANCHOR FOLD: the `epoch_bounded_reference` documents
        %       step (1) minted become `relative_reference`, base.id PRESERVED,
        %       anchored to the `epoch` document step (5) just created for the
        %       SAME (base.session_id, epoch-id string) PAIR.
        %
        %       WHY IT EXISTS AT ALL, stated plainly because it is a gap this
        %       pipeline carried silently: stimulusBathToBath is the ONLY site
        %       in either repo that mints an `epoch_bounded_reference` DOCUMENT,
        %       and did2.convert.resolveSessionAnchors -- the pass that collapses
        %       the retiring reference family -- matches exactly two class names,
        %       `session_relative_reference` and `session_bounded_reference`
        %       (resolveSessionAnchors.m, the two `strcmp(anchorClass{k}, 'session_...')`
        %       lines). So a class the signed
        %       time-reference decision RETIRES
        %       (V_eta_time_reference_model_plan.md, TEAM-SIGN-OFF
        %       [time_reference] 2026-08-08, migration table line 195) was being
        %       minted, fully populated, and carried into migrated output with
        %       nothing to consume it. It was invisible to the DID corpus gate
        %       because that gate runs the coarse
        %       did2.convert.resolveDeferredBaths instead, which NDI
        %       deliberately substitutes this assembler for
        %       (stimulusBathToBath, "the LIVE-session counterpart of the coarse
        %       did2.convert.resolveDeferredBaths.makeBathVeta") -- two
        %       pipelines emitting different
        %       classes for one concept, and nothing comparing them.
        %
        %       ORDER: immediately after (5), and here the dependency IS real
        %       rather than a judgement -- it consumes
        %       `convertResult.epoch_mint.epoch_index`, which does not exist
        %       until (5) has run. It reads that index rather than re-deriving
        %       the mapping: the key is the PAIR (an `epochid.epochid` string is
        %       reused across sessions), and a second implementation of a key
        %       whose failure mode is a silent merge is not worth having.
        %       Lives NDI-side because the class it folds is minted NDI-side;
        %       the DID gate has nothing to fold.
        %       See ndi.migrate.internal.epochAnchorFold.
        %   (7b) RESPONSE PARAMETER FOLD (#61, second half): inline the five
        %       stimulus-response run knobs from
        %       `stimulus_response_scalar_parameters_basic` onto the leaf and
        %       REMOVE the edge, because subject_interaction.json says a
        %       statement carries the inline `method_parameters` field OR the
        %       edge, NEVER BOTH (team, 2026-08-09). Deletes nothing: the
        %       parameters documents stay put and the pass instead MEASURES
        %       what the verify-before-delete gate needs
        %       (`parameters_documents_unreferenced_after`). Lives DID-side
        %       (did2.convert.resolveResponseParameters) beside epochMint,
        %       resolveSessionAnchors and resolveDatasetEntities, so the corpus
        %       discovery harness runs the same code this does.
        %   (7c) LAWN / PLATE SUBJECTS and (7c2) IMAGED-ENTITY SUBJECTS are
        %       GONE from the generic stage: Decided by Jess Haley, 2026-10-26
        %       [Haley logic leaves the generic migration], [dataset-specific
        %       logic leaves the generic migration] and [dataset audit batch 1
        %       and 2] (5) (did-schema V_eta_go_forward_class_audit.md). The
        %       Haley dataset's V2 shape comes from its V2 re-import; what the
        %       generic stage cannot place is carried as v1.
        %  (7d) GENERIC FILE FOLD (team decision, 2026-08-11): a did_v1
        %       `generic_file` becomes a `term_observation` (base.id
        %       PRESERVED) whose `variable` is the SIBLING ontologyLabel's
        %       `ontologyNode`, plus an `opaque_body` carrying the filename,
        %       the format CURIE, the MD5 in `content_hash` and the attached
        %       bytes' manifest. Pass 1 cannot do it and the reason is not
        %       incidental: the `variable` lives in a DIFFERENT DOCUMENT, and
        %       `subject_statement.variable` is mustBeNonEmpty, so a
        %       single-document migrator could only emit a document that
        %       quarantines. Lives DID-side (did2.convert.foldGenericFiles)
        %       beside its four siblings, so the corpus discovery harness runs
        %       the same code this does.
        %
        %       WHY IT IS SAFE TO RUN IN PRODUCTION WHERE NO CORPUS EXERCISES
        %       IT: all six gate corpora hold ZERO `generic_file` documents
        %       (run 31327383671), so this path is UNTESTED ON REAL DATA and
        %       the fixture corpus is the only thing that runs it. The pass is
        %       built to refuse rather than guess -- no label, two labels, an
        %       empty node, no document_id, or a referent absent from the
        %       batch each leave the document exactly as pass 1 produced it --
        %       and the catch below downgrades any throw to that same state.
        %
        %       ORDER: after (7c) and before (6), the same relative order the
        %       three DID call sites use. It commutes with everything above:
        %       it reads only `generic_file` and `ontology_label` documents,
        %       which no other sub-pass in this block writes, and it removes
        %       nothing any of them points at (the statement keeps the source
        %       id). (6) still runs LAST; this pass mints no `software`.
        %  (7e) VALID INTERVAL DECOMPOSE (team decision, 2026-08-11): a
        %       did_v1 `valid_interval` document holds an ARRAY of intervals,
        %       each with a start, an end and two independent time anchors.
        %       Each interval becomes ONE `validity_observation` -- a BOOLEAN
        %       statement about the element-subject named by `element_id`
        %       (elements are promoted to subjects with ids PRESERVED) --
        %       plus the `relative_reference` it is anchored to (start = t0,
        %       duration = t1 - t0). Pass 1 cannot do it: the anchor names an
        %       epoch by STRING, `relative_reference.relative_to` is REQUIRED
        %       and points at the epoch DOCUMENT, and those ids exist only
        %       after (7). Lives DID-side
        %       (did2.convert.resolveValidIntervals) beside its five siblings.
        %
        %       ORDER: after (7) FOR A REAL REASON, not for symmetry. It reads
        %       the `epoch` documents epochMint appends; run before them it
        %       refuses every interval and changes nothing.
        %
        %       IT ADDS AND NEVER REMOVES, so it cannot lose anything it
        %       misreads: the `valid_interval` document stays, validating
        %       against its own tombstone. `sources_fully_decomposed` measures
        %       the deletion gate rather than pre-empting it.
        %
        %       WHY IT IS SAFE WHERE NO CORPUS EXERCISES IT: all six gate
        %       corpora hold ZERO `valid_interval` documents (run
        %       31327383671), so this path is UNTESTED ON REAL DATA. AND THAT
        %       ZERO IS ALSO THE POINT OF THE DESIGN -- `ndi.app.markgarbage`
        %       is OPT-IN, so no document means the whole epoch is good data,
        %       and a dataset without markgarbage must migrate to ZERO
        %       validity statements rather than to "every epoch unknown".
        %       Nothing is minted for an element with no source document.
        %  (7f) THE OPEN SUB-QUESTION (7e) DELIBERATELY DOES NOT ANSWER:
        %       `loadvalidinterval` inherits a derived element's validity from
        %       its `underlying_element` (markgarbage.m:146-155), a QUERY-TIME
        %       rule. Whether V_eta re-derives that through `derived_from` or
        %       MATERIALISES copies is a TEAM call. (7e) forecloses neither --
        %       it writes the statement against the element the source named,
        %       leaves `derived_from_#` empty, and REPORTS
        %       `inheritance_candidates` so the decision has a size attached.
        %   (6) SOFTWARE DEDUP (#25), run TWICE: right after pass 1 (Decided
        %       by Jess Haley, 2026-10-22 [software dedup after pass one]; see
        %       above) and again here, LAST. Pass 1 mints one `software` entity per
        %       consuming document, because a single-document migrator cannot
        %       know another document already minted the same program. Merge
        %       them on (session_id, name, version) and retarget every inbound
        %       edge BY TARGET ID -- one of the seven edges that must_refer to
        %       `software` is called `reader_id`, not `software_id`. Runs LAST
        %       so it also sees any software minted by a body the deferral pass
        %       re-folded through v1_to_v2.
        %       See ndi.migrate.internal.softwareDedup.
        %   (7) SESSION ANCHOR FOLD (#65): `session_relative_reference`
        %       (107,308 documents) + `session_bounded_reference` (20,411)
        %       become `relative_reference` with base.id PRESERVED, anchored to
        %       the SESSION DOCUMENT. Pass 1 cannot do it: a migrator holds
        %       `base.session_id`, while the REQUIRED `relative_to` edge needs
        %       the session document's `base.id` -- two independently minted
        %       strings (+ndi/document.m:57-58 vs +ndi/session.m:215), so the
        %       mapping is a corpus-wide index. Lives DID-side
        %       (did2.convert.resolveSessionAnchors) beside epochMint, so the
        %       corpus discovery harness runs the same code this does.
        %
        %       ORDER: immediately after (5), matching runCorpusDiscovery,
        %       testCorpusPRED and testFixtureCorpus exactly. Stated plainly --
        %       NO DEPENDENCY FORCES IT. Both (5) and (7) index `session`
        %       documents by (base.session_id -> base.id); neither writes what
        %       the other reads; and no sub-pass in this block removes a
        %       `session` document, so (7)'s new edge cannot be orphaned by a
        %       later step whatever the order (softwareDedup removes only
        %       duplicate `software` entities). The order is pinned so the DID
        %       corpus gate and this production path cannot silently diverge.
        % Each step is independent; a failure leaves the affected documents in
        % their pass-1 form.
        %
        % ONE body resolver for the two steps that read it (resolveDeferred and
        % resolveStimulusPresentations). It indexes every decoded v1 body, so
        % building it twice held two whole-corpus indexes at once on Soph. It
        % is a pure function of `bodies` (which nothing here reassigns) and its
        % lookups only read, so the second step gets the same answers from
        % the first one's resolver; it builds its own only if this one failed.
        % Cleared after its last reader, so the index is not carried through
        % the rest of the second pass.
        resolver = [];
        try
            resolver = ndi.migrate.internal.bodyResolver(bodies);
            [convertResult, bathAnchors] = resolveDeferred(convertResult, resolver, options);
        catch ME
            stepErrors(end+1) = struct('step', 'deferredResolveFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:deferredResolveFailed', ...
                ['Second-pass resolution of session-context deferrals ' ...
                 'failed (%s); leaving them quarantined.'], ME.message);
        end
        tStep = migrateStepMark('resolveDeferred', tStart, tStep, convertResult);
        % [table rows carried as v1] (Jess Haley, 2026-10-30): every row is
        % carried by pass 1; this step counts them and changes nothing.
        try
            ontologyRowReport = countOntologyRows(convertResult, bodies);
        catch ME
            stepErrors(end+1) = struct('step', 'ontologyRowCountFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:ontologyRowCountFailed', ...
                ['Second-pass ontology_table_row count failed (%s); the ' ...
                 'rows are not counted (nothing was changed).'], ME.message);
        end
        tStep = migrateStepMark('countOntologyRows', tStart, tStep, convertResult);
        try
            [convertResult, ontologyLabelReport] = ...
                resolveOntologyLabelSubjects(convertResult, options);
        catch ME
            stepErrors(end+1) = struct('step', 'ontologyLabelSubjectsFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:ontologyLabelSubjectsFailed', ...
                ['Second-pass ontology_label subject resolution failed ' ...
                 '(%s); leaving the labels as passthrough.'], ME.message);
        end
        tStep = migrateStepMark('resolveOntologyLabelSubjects', tStart, tStep, convertResult);
        try
            [convertResult, stimulusSequenceReport, presentationAnchors] = ...
                resolveStimulusPresentations(convertResult, bodies, options, resolver, ndiDir);
        catch ME
            stepErrors(end+1) = struct('step', 'presentationResolveFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:presentationResolveFailed', ...
                ['Second-pass stimulus_presentation decomposition failed ' ...
                 '(%s); leaving presentations as passthrough.'], ME.message);
        end
        clear resolver;   % its last reader is above
        tStep = migrateStepMark('resolveStimulusPresentations', tStart, tStep, convertResult);
        try
            [convertResult, regionSitesReport] = ...
                resolvePathS(convertResult, options, 'sites');
        catch ME
            stepErrors(end+1) = struct('step', 'pathSFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:pathSFailed', ...
                ['Second-pass Path-S promotion failed (%s); leaving ' ...
                 'anatomical loci located-by-default.'], ME.message);
        end
        tStep = migrateStepMark('resolvePathS(sites)', tStart, tStep, convertResult);
        try
            [convertResult, strainReport] = ...
                resolveStrainAssembly(convertResult, options);
        catch ME
            stepErrors(end+1) = struct('step', 'strainAssemblyFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:strainAssemblyFailed', ...
                ['Second-pass strain assembly failed (%s); leaving the ' ...
                 'openminds Strain documents as passthrough.'], ME.message);
        end
        tStep = migrateStepMark('resolveStrainAssembly', tStart, tStep, convertResult);
        try
            [convertResult, openmindsCitationsReport] = ...
                did2.convert.resolveOpenmindsCitations( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'openmindsCitationsFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:openmindsCitationsFailed', ...
                ['Second-pass openMINDS citation assembly failed (%s); ' ...
                 'leaving the `openminds` documents as passthroughs, which ' ...
                 'is the state they are in without this pass.'], ME.message);
        end
        tStep = migrateStepMark('resolveOpenmindsCitations', tStart, tStep, convertResult);
        try
            [convertResult, datasetEntitiesReport] = ...
                resolveDatasetEntitiesPass(convertResult, options);
        catch ME
            stepErrors(end+1) = struct('step', 'datasetEntitiesFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:datasetEntitiesFailed', ...
                ['Second-pass dataset entity resolution failed (%s); leaving ' ...
                 'the duplicate `dataset` entities and the unresolvable ' ...
                 '`migrated_session_membership` edges in place.'], ME.message);
        end
        tStep = migrateStepMark('resolveDatasetEntities', tStart, tStep, convertResult);
        try
            [convertResult, subjectStrainReport] = ...
                resolveSubjectStrainAssembly(convertResult, bodies, options);
        catch ME
            stepErrors(end+1) = struct('step', 'subjectStrainAssemblyFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:subjectStrainAssemblyFailed', ...
                ['Second-pass subject-attached strain assembly failed (%s); ' ...
                 'leaving every openMINDS strain assertion exactly as pass 1 ' ...
                 'emitted it -- no `strain` entity, no `strain_id`, no ' ...
                 'pedigree, and both the genetic-strain-type and the ' ...
                 'duplicate species assertions still on the subject. That is ' ...
                 'the state production is in without this pass, so a failure ' ...
                 'here loses the go-forward representation and no fact.'], ...
                ME.message);
        end
        tStep = migrateStepMark('resolveSubjectStrainAssembly', tStart, tStep, convertResult);
        try
            [convertResult, epochMintReport] = did2.convert.epochMint( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'epochMintFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:epochMintFailed', ...
                ['Second-pass epoch mint failed (%s); leaving the epoch ' ...
                 'association as the did_v1 `epochid` string.'], ME.message);
        end
        tStep = migrateStepMark('epochMint', tStart, tStep, convertResult);
        try
            [convertResult, ensembleReport] = resolveEnsembleMembership( ...
                convertResult, epochMintReport, options);
        catch ME
            stepErrors(end+1) = struct('step', 'ensembleMembershipFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:ensembleMembershipFailed', ...
                ['Second-pass ensemble membership failed (%s); leaving the ' ...
                 'ensemble map documents as passthrough.'], ME.message);
        end
        tStep = migrateStepMark('resolveEnsembleMembership', tStart, tStep, convertResult);
        try
            % the bath anchors and, [presentation anchored to its epoch]
            % (Jess Haley, 2026-10-27), each presentation manipulation's
            % session anchor: one fold re-points both at the minted epoch
            [convertResult, epochAnchorReport] = ...
                resolveEpochAnchorFold(convertResult, epochMintReport, options, ...
                    [anchorRows(bathAnchors), anchorRows(presentationAnchors)]);
            stimulusSequenceReport = tallyPresentationAnchors( ...
                stimulusSequenceReport, presentationAnchors, epochAnchorReport);
            if isstruct(stimulusSequenceReport) ...
                    && isstruct(stimulusSequenceReport.epoch_anchor) ...
                    && stimulusSequenceReport.epoch_anchor.anchors_left_on_session > 0
                % [epoch-less presentations carry] (Jess Haley, 2026-10-27):
                % every presentation decomposed was predicted foldable, so one
                % the fold refused is a defect of the prediction, not a carry
                stepErrors(end+1) = struct('step', 'presentationEpochAnchorMissed', ...
                    'message', sprintf(['%d presentation manipulation(s) were ' ...
                    'predicted to anchor to their epoch and stayed on the ' ...
                    'session'], stimulusSequenceReport.epoch_anchor.anchors_left_on_session)); %#ok<AGROW>
            end
        catch ME
            stepErrors(end+1) = struct('step', 'epochAnchorFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:epochAnchorFoldFailed', ...
                ['Second-pass epoch anchor fold failed (%s); leaving the ' ...
                 'stimulator anchors as pass-1 epoch_bounded_reference ' ...
                 'documents.'], ME.message);
        end
        tStep = migrateStepMark('resolveEpochAnchorFold', tStart, tStep, convertResult);
        try
            [convertResult, recordingAttributionReport] = ...
                resolveRecordingAttribution(convertResult, options);
        catch ME
            stepErrors(end+1) = struct('step', 'recordingAttributionFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:recordingAttributionFailed', ...
                ['Second-pass raw-recording attribution failed (%s); leaving ' ...
                 'probe-attributed observations as pass-1 emitted them.'], ...
                ME.message);
        end
        tStep = migrateStepMark('resolveRecordingAttribution', tStart, tStep, convertResult);
        try
            [convertResult, sessionAnchorReport] = ...
                did2.convert.resolveSessionAnchors( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'sessionAnchorFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:sessionAnchorFoldFailed', ...
                ['Second-pass session anchor fold failed (%s); leaving the ' ...
                 'time references as pass-1 session_relative_reference / ' ...
                 'session_bounded_reference documents.'], ME.message);
        end
        tStep = migrateStepMark('resolveSessionAnchors', tStart, tStep, convertResult);
        try
            % THE SAME FUNCTION the three DID-side call sites run, in the same
            % order (after epochMint + resolveSessionAnchors) so the two
            % pipelines stay one. #66 increment 1: decompose each ingested
            % epoch's `epochprobemap` into epoch-scoped `<modality>_observation`
            % documents (one per probe row, anchored to the minted `epoch`),
            % retiring #30's coarse session-scoped observation for a probe when
            % exactly one names it. ORDER: after epochMint (the anchor is an
            % `epoch` DOCUMENT minted there) and after resolveSessionAnchors (so
            % the #30 observations it retires have their anchors already folded).
            % IT ADDS AND NEVER REMOVES SOURCES: `epochfiles_ingested` keeps its
            % probemap (increment 3 renames it), so a failure here leaves the
            % dataset exactly as this pass found it.
            [convertResult, epochProbemapReport] = ...
                did2.convert.resolveEpochProbemap( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'epochProbemapFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:epochProbemapFoldFailed', ...
                ['Second-pass epochprobemap decompose failed (%s); leaving ' ...
                 'every `epochfiles_ingested` document with its serialized ' ...
                 'probemap and #30''s session-scoped observations in place, ' ...
                 'which is the state without this pass.'], ME.message);
        end
        tStep = migrateStepMark('resolveEpochProbemap', tStart, tStep, convertResult);
        % UNCONDITIONALLY, whether or not the pass above ran: the transient
        % navigator epochs are not v1 documents (nor ingestion manifests) and
        % must never be written.
        if isstruct(navigatorEpochReport) && ~isempty(navigatorEpochReport.transient_ids)
            keepIdx = true(1, numel(convertResult.migrated));
            for k = 1:numel(convertResult.migrated)
                keepIdx(k) = ~any(strcmp(char(convertResult.migrated{k}.get('base.id')), ...
                    navigatorEpochReport.transient_ids));
            end
            navigatorEpochReport.transient_removed = sum(~keepIdx);
            convertResult.migrated = convertResult.migrated(keepIdx);
            convertResult.summary = recountSummary(convertResult);
        end
        tStep = migrateStepMark('removeTransientNavigatorEpochs', tStart, tStep, convertResult);
        % the files that ARE on this computer get their size and MD5, as a
        % native V2 recording body does; an absent one stays as recorded
        try
            [convertResult, lffReport] = fillLocatedFileFacts(convertResult, options);
            if isstruct(navigatorEpochReport)
                navigatorEpochReport.located_file_facts = lffReport;
            end
        catch ME
            stepErrors(end+1) = struct('step', 'locatedFileFactsFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:locatedFileFactsFailed', ...
                'Filling size/MD5 of located files failed (%s).', ME.message);
        end
        tStep = migrateStepMark('fillLocatedFileFacts', tStart, tStep, convertResult);
        try
            % F1 (Decided by Jess Haley, 2026-10-22 [epoch dissolution before
            % merge]; TEAM-SIGN-OFF [epoch] 2026-08-17 Q3): the second pass
            % describes each spike train's .vhsb (the opaque_body
            % did2.convert.resolveEpochProbemap carried as attached) as a
            % sampled_body with complete extents, when the bytes are on this
            % computer. AFTER resolveEpochProbemap (it makes those bodies).
            % A document-only corpus has no bytes: nothing changes, counted.
            [convertResult, epochSeriesBodiesReport] = ...
                describeEpochSeriesBodies(convertResult, ndiDir, options);
        catch ME
            stepErrors(end+1) = struct('step', 'epochSeriesBodiesFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:epochSeriesBodiesFailed', ...
                ['Describing the spike-train bodies failed (%s); they stay ' ...
                 'opaque_body documents carried as attached, which is the ' ...
                 'state without this step.'], ME.message);
        end
        tStep = migrateStepMark('describeEpochSeriesBodies', tStart, tStep, convertResult);
        try
            % AFTER the epochprobemap fold (it re-attributes that pass's
            % per-epoch statements) and after epochMint (its epoch index is
            % the tetanus window's referent). Dabrowska slices: decided by
            % Jess Haley 2026-10-21; see ndi.migrate.internal.sliceTetanus.
            [convertResult, sliceTetanusReport] = resolveSliceTetanus( ...
                convertResult, bodies, epochMintReport, options);
        catch ME
            stepErrors(end+1) = struct('step', 'sliceTetanusFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:sliceTetanusFailed', ...
                ['Second-pass slice / tetanus fold failed (%s); leaving the ' ...
                 'bath and recording statements on the animal, the per-animal ' ...
                 'tetanus treatment and the before/after approach documents ' ...
                 'as they were, which is the state without this pass.'], ...
                ME.message);
        end
        tStep = migrateStepMark('resolveSliceTetanus', tStart, tStep, convertResult);
        try
            % A statement about an anatomical region targets that region's part
            % entity (Jess Haley, 2026-10-21; see
            % ndi.migrate.internal.pathSPromotion). AFTER the epochprobemap
            % fold (it makes the recording observations whose probe is
            % located) and AFTER sliceTetanus (it matches slice statements by
            % the animal they are about, and a statement it moved onto a slice
            % is not moved again). Finds the parts the 'sites' pass made, so
            % an injection into a region and a recording from it share one.
            [convertResult, regionLocatedReport] = ...
                resolvePathS(convertResult, options, 'located');
        catch ME
            stepErrors(end+1) = struct('step', 'regionLocatedFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:regionLocatedFailed', ...
                ['Second-pass region-part retarget of located-instrument ' ...
                 'statements failed (%s); leaving them on the subject, which ' ...
                 'is the state without this pass.'], ME.message);
        end
        tStep = migrateStepMark('resolvePathS(located)', tStart, tStep, convertResult);
        try
            [convertResult, responseParametersReport] = ...
                did2.convert.resolveResponseParameters( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'responseParametersFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:responseParametersFoldFailed', ...
                ['Second-pass stimulus-response parameter fold failed (%s); ' ...
                 'leaving the run knobs in their own ' ...
                 '`stimulus_response_scalar_parameters_basic` documents with ' ...
                 'the leaf still carrying the edge.'], ME.message);
        end
        tStep = migrateStepMark('resolveResponseParameters', tStart, tStep, convertResult);
        try
            [convertResult, genericFileFoldReport] = ...
                did2.convert.foldGenericFiles( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'genericFileFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:genericFileFoldFailed', ...
                ['Second-pass generic_file fold failed (%s); leaving every ' ...
                 '`generic_file` document as a passthrough, which is the ' ...
                 'state it is in without this pass.'], ME.message);
        end
        tStep = migrateStepMark('foldGenericFiles', tStart, tStep, convertResult);
        try
            % TEAM DECISION 2026-08-11: `valid_interval` becomes a
            % boolean-valued `subject_statement`. One `validity_observation`
            % per interval (the element-subject as `subject_id`, the v1 array
            % position as `sequence`) plus the `relative_reference` it is
            % anchored to. THE SAME FUNCTION the three DID-side call sites run,
            % in the same order, which is what keeps the two pipelines one.
            %
            % ORDER: after did2.convert.epochMint, and that dependence is REAL
            % rather than conventional -- the anchor is an `epoch` DOCUMENT and
            % those are minted there. Run earlier it would refuse every interval
            % with `refused_no_epoch_document` and change nothing.
            %
            % IT ADDS AND NEVER REMOVES. The `valid_interval` document stays,
            % validating against its own tombstone, so a failure here leaves the
            % dataset exactly as this pass found it -- which is the state
            % production is in today.
            [convertResult, validIntervalReport] = ...
                did2.convert.resolveValidIntervals( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'validIntervalDecomposeFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:validIntervalDecomposeFailed', ...
                ['Second-pass valid_interval decompose failed (%s); leaving ' ...
                 'every `valid_interval` document as a passthrough, which is ' ...
                 'the state it is in without this pass. NOTE what this does ' ...
                 'NOT mean: absence of a validity statement still means the ' ...
                 'data is VALID (ndi.app.markgarbage is opt-in), so a failure ' ...
                 'here loses the go-forward representation, not the meaning.'], ...
                ME.message);
        end
        tStep = migrateStepMark('resolveValidIntervals', tStart, tStep, convertResult);
        try
            % #57 syncgraph half: un-gate syncgraph -> clock_alignment_policy by
            % supplying the session-document id a single-document migrator cannot
            % resolve. BEFORE resolveSoftwareDedup, ON PURPOSE: this pass emits a
            % `software` entity for the syncgraph's rule class, and running it
            % after the dedup would leave that entity un-deduplicated. base.id is
            % preserved on the policy, so a failure here leaves every syncgraph a
            % pass-1 passthrough -- the state production is in today.
            [convertResult, clockAlignmentReport] = ...
                did2.convert.resolveClockAlignment( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            stepErrors(end+1) = struct('step', 'clockAlignmentFoldFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:clockAlignmentFoldFailed', ...
                ['Second-pass clock-alignment fold failed (%s); leaving every ' ...
                 '`syncgraph` document as a passthrough, which is the state it ' ...
                 'is in without this pass.'], ME.message);
        end
        tStep = migrateStepMark('resolveClockAlignment', tStart, tStep, convertResult);
        try
            [convertResult, softwareDedupReport] = ...
                resolveSoftwareDedup(convertResult);
        catch ME
            stepErrors(end+1) = struct('step', 'softwareDedupFailed', 'message', ME.message); %#ok<AGROW>
            warning('NDI:migrate:softwareDedupFailed', ...
                ['Second-pass software dedup failed (%s); leaving one ' ...
                 '`software` entity per consuming document.'], ME.message);
        end
        tStep = migrateStepMark('resolveSoftwareDedup', tStart, tStep, convertResult);

        % THE DIMENSION-TERM CENSUS (Decided by Jess Haley, 2026-10-22
        % [covariate details], 5.4 "B"): a dimension's term is bound
        % `preferred`, so every migration counts the dimensions it wrote whose
        % term has no node, against the dimensions written. An instrument only.
        try
            dimensionTermReport = ndi.migrate.internal.dimensionTermCensus( ...
                convertResult.migrated);
            fprintf(['[migrate step]   dimensions written: %d (on %d of %d ' ...
                'documents); term with no node: %d\n'], ...
                dimensionTermReport.dimensions_written, ...
                dimensionTermReport.documents_with_dimensions, ...
                dimensionTermReport.documents_inspected, ...
                dimensionTermReport.dimensions_without_node);
        catch ME
            warning('NDI:migrate:dimensionTermCensusFailed', ...
                'The dimension-term census failed (%s); not measured.', ME.message);
        end
    end

    % --- the final v1 stamp: a document no step changed stays v1 -------------
    % Decided by Jess Haley, 2026-10-24 [passthrough stays v1] and
    % [passthrough stays v1: how], and 2026-10-25 [document stamps]
    % (did-schema V_eta_go_forward_class_audit.md): a v1 document the
    % migration carries through unchanged stays a v1 document, judged after
    % the WHOLE pipeline -- here, after pass 1, the DID batch passes and the
    % second pass, all of which received it as they did before. Each document
    % still identical to the body pass 1 emitted for it is replaced by its v1
    % SOURCE body stamped 'did_v1'; did2.database.sqlitedb stores it without
    % V_eta validation and counts it. Before settleIngestedFiles, which then
    % points its files at the bytes v1 ingested, as for every document.
    carriedAsV1Report = struct('not_measured', ...
        'did2.convert.v1_to_v2 returned no passthrough record');
    carriedAsV1 = NaN;
    if isstruct(passOneRecord) && iscell(convertResult.migrated)
        % [carry register] (Jess Haley, 2026-10-26): the documents NDI's
        % second pass declined, each with the carry register row its reason
        % cites, so the stamp counts second-pass carries by row
        secondPassRows = secondPassCarryRows({stimulusSequenceReport, ...
            strainReport, ontologyLabelReport, ensembleReport});
        [convertResult.migrated, carriedAsV1Report] = ...
            ndi.migrate.internal.carryUnchangedAsV1(convertResult.migrated, ...
            passOneRecord, bodies, secondPassRows);
        carriedAsV1 = carriedAsV1Report.carried_as_v1;
        fprintf(['[migrate step]   carried as v1 (did_v1): %d of %d documents ' ...
            '(%d passed through pass 1; %d changed later, %d absent at the end)\n'], ...
            carriedAsV1Report.carried_as_v1, carriedAsV1Report.documents_inspected, ...
            carriedAsV1Report.passed_through_pass_one, ...
            carriedAsV1Report.changed_after_pass_one, carriedAsV1Report.absent_at_end);
        fprintf(['[migrate step]   carried as v1 by a second-pass reason: %d of %d ' ...
            'carried (%d with no second-pass row: pass-1 carries and passthrough ' ...
            'classes)\n'], carriedAsV1Report.carried_with_second_pass_row, ...
            carriedAsV1Report.carried_as_v1, ...
            carriedAsV1Report.carried_without_second_pass_row);
        if ~isempty(carriedAsV1Report.carried_by_row)
            parts = arrayfun(@(e) sprintf('%s %d', e.row, e.count), ...
                carriedAsV1Report.carried_by_row, 'UniformOutput', false);
            fprintf('[migrate step]     second-pass carries, by carry register row: %s\n', ...
                strjoin(parts, ', '));
        end
        tabs = {'carried', carriedAsV1Report.carried_by_class; ...
                'changed later', carriedAsV1Report.changed_by_class; ...
                'absent at the end', carriedAsV1Report.absent_by_class};
        for t = 1:size(tabs, 1)
            tbl = tabs{t, 2};
            if isempty(tbl), continue; end
            shown = tbl(1:min(8, numel(tbl)));
            parts = arrayfun(@(e) sprintf('%s %d', e.class_name, e.count), ...
                shown, 'UniformOutput', false);
            fprintf('[migrate step]     %s, by class (%d class(es)): %s\n', ...
                tabs{t, 1}, numel(tbl), strjoin(parts, ', '));
        end
    end
    tStep = migrateStepMark('carryUnchangedAsV1', tStart, tStep, convertResult);

    % --- the final sweep: dependents of a final carry carry too --------------
    % Decided by Jess Haley, 2026-10-26 [dependents of a carried document
    % carry] and 2026-10-27 [handed-on documents do not carry dependents]
    % (did-schema V_eta_go_forward_class_audit.md): a document whose edge
    % names a document carried as v1 is carried too, down the chain
    % (carry-064); only a document that stays v1 at the end of both passes
    % counts, so this runs after the final v1 stamp, on the final carries.
    carriedDependentsReport = struct('not_measured', ...
        'did2.convert.v1_to_v2 returned no passthrough record');
    if isstruct(passOneRecord) && iscell(convertResult.migrated)
        [convertResult.migrated, carriedDependentsReport] = ...
            ndi.migrate.internal.carryFinalDependents(convertResult.migrated, ...
            bodies, passOneSourceOutputs);
        fprintf(['[migrate step]   final carry sweep: %d document(s) inspected ' ...
            '(%d not v1, %d edge(s)); %d final carries at the start; carried ' ...
            '(carry-064): %d; pass-1 outputs dropped: %d, kept (still named): %d; ' ...
            'naming a carry with no source (left): %d; session_id edges to a ' ...
            'carry (not followed): %d; %d round(s)\n'], ...
            carriedDependentsReport.documents_inspected, ...
            carriedDependentsReport.v2_documents_inspected, ...
            carriedDependentsReport.edges_examined, ...
            carriedDependentsReport.carried_at_start, ...
            carriedDependentsReport.carried_by_sweep, ...
            carriedDependentsReport.outputs_dropped, ...
            carriedDependentsReport.outputs_kept_referenced, ...
            carriedDependentsReport.left_no_source, ...
            carriedDependentsReport.session_edges_to_v1, ...
            carriedDependentsReport.rounds);
    end
    tStep = migrateStepMark('carryFinalDependents', tStart, tStep, convertResult);

    % --- ingested files: point them at the bytes v1 already ingested --------
    % A v1 document still records each file as it was when first added
    % (`ingest` 1 from a path that is usually gone); the legacy backend copied
    % the bytes to <.ndi>/files/<uid> at the time. did2.database.sqlitedb
    % ingests on add and refuses the whole batch when a source is missing
    % (did2:database:ingestSourceMissing), so without this the migration
    % writes nothing for any session whose documents carry files.
    ingestedFilesReport = struct();
    if ~alreadyMigrated && iscell(convertResult.migrated) && ~isempty(convertResult.migrated)
        [convertResult.migrated, ingestedFilesReport] = ...
            ndi.migrate.internal.settleIngestedFiles(convertResult.migrated, ndiDir);
    end
    tStep = migrateStepMark('settleIngestedFiles', tStart, tStep, convertResult);

    wroteDst = false;
    wroteQuarantineFile = '';
    if ~options.DryRun && ~alreadyMigrated
        if isfile(dstPath)
            delete(dstPath);
        end
        db = did2.database.sqlitedb(dstPath, ...
            'SchemaCache', options.SchemaCache);
        dbCleanup = onCleanup(@() db.close());
        if ~isempty(convertResult.migrated)
            % A repeated id would surface as mksqlite's bare "UNIQUE constraint
            % failed: documents.id" (B and Dab, runs 39684114775 and
            % 39668356521), which names neither the id nor the pass that
            % minted it. Say both before writing anything.
            assertUniqueIds(convertResult.migrated);
            db.add(convertResult.migrated, 'Validate', options.Validate);
        end
        clear dbCleanup;
        wroteDst = true;

        if ~isempty(convertResult.quarantine)
            writeQuarantineFile(quarantineFile, convertResult.quarantine);
            wroteQuarantineFile = quarantineFile;
        elseif isfile(quarantineFile)
            delete(quarantineFile);
        end
    end
    tStep = migrateStepMark('write destination', tStart, tStep, convertResult);

    refReport = did2.validate.references(convertResult.migrated);
    migrateStepMark('validate references', tStart, tStep, convertResult);

    result = struct();
    result.path = path;
    result.source = srcInfo;
    result.destination = dstPath;
    result.alreadyMigrated = alreadyMigrated;
    result.dryRun = options.DryRun;
    result.wroteDestination = wroteDst;
    result.backup = struct( ...
        'enabled', options.Backup, ...
        'path',    backupDir, ...
        'created', backupCreated);
    result.summary = convertResult.summary;
    % of the documents written, how many are v1 documents ('did_v1'), carried
    % unchanged by the final v1 stamp (NaN: not measured)
    result.summary.carried_as_v1 = carriedAsV1;
    result.carriedAsV1 = carriedAsV1Report;
    % the final sweep's carries (carry-064), apart from carried_as_v1 above
    result.carriedDependents = carriedDependentsReport;
    % [pipeline defects are not carries] (Jess Haley, 2026-10-26): the
    % documents left as v1 because of the pipeline, not the data, reported
    % as ERRORS apart from the carries: a second-pass step that threw, and
    % a re-fold whose output quarantined (the document is then reverted).
    result.secondPassErrors = secondPassErrorReport(stepErrors, ...
        ontologyLabelReport, ensembleReport);
    if result.secondPassErrors.total > 0
        fprintf(['[migrate step]   SECOND-PASS ERRORS (defects, not carries): %d ' ...
            '(%d step(s) threw; re-folds quarantined: %d label(s), ' ...
            '%d ensemble map(s))\n'], result.secondPassErrors.total, ...
            result.secondPassErrors.steps_failed, ...
            result.secondPassErrors.refold_quarantined.ontology_label, ...
            result.secondPassErrors.refold_quarantined.ensemble);
        for e = 1:numel(stepErrors)
            fprintf('[migrate step]     %s: %s\n', stepErrors(e).step, stepErrors(e).message);
        end
    else
        fprintf(['[migrate step]   second-pass errors (defects, not carries): 0 ' ...
            '(no step threw; no re-fold quarantined)\n']);
    end
    result.quarantine = convertResult.quarantine;
    result.quarantineFile = wroteQuarantineFile;
    result.references = refReport;
    result.ingestedFiles = ingestedFilesReport;
    result.secondPass = struct( ...
        'ensembleMembership',  ensembleReport, ...
        'strainAssembly',      strainReport, ...
        'subjectStrainAssembly', subjectStrainReport, ...
        'ontologyRowsCarried', ontologyRowReport, ...
        'ontologyLabelSubjects', ontologyLabelReport, ...
        'stimulusSequence',    stimulusSequenceReport, ...
        'openmindsCitations',  openmindsCitationsReport, ...
        'datasetEntities',     datasetEntitiesReport, ...
        'epochMint',           epochMintReport, ...
        'epochAnchorFold',     epochAnchorReport, ...
        'recordingAttribution', recordingAttributionReport, ...
        'sessionAnchorFold',   sessionAnchorReport, ...
        'epochProbemapFold',   epochProbemapReport, ...
        'navigatorEpochFiles', navigatorEpochReport, ...
        'responseParametersFold', responseParametersReport, ...
        'genericFileFold',     genericFileFoldReport, ...
        'validIntervalDecompose', validIntervalReport, ...
        'clockAlignmentFold',  clockAlignmentReport, ...
        'softwareDedupAfterPassOne', softwareDedupEarlyReport, ...
        'softwareDedup',       softwareDedupReport, ...
        'dimensionTerms',      dimensionTermReport, ...
        'sliceTetanus',        sliceTetanusReport, ...
        'regionPartsSites',    regionSitesReport, ...
        'regionPartsLocated',  regionLocatedReport, ...
        'epochSeriesBodies',   epochSeriesBodiesReport);

    if options.Verbose
        printSummary(result);
    end

    if ~options.ContinueOnError && ~isempty(convertResult.quarantine)
        error('NDI:migrate:hadQuarantine', ...
            ['Migration of "%s" quarantined %d document(s); ' ...
             'ContinueOnError was false.'], ...
             path, numel(convertResult.quarantine));
    end
end

% ---- instrumentation: one line per top-level step --------------------------

function tNext = migrateStepMark(label, tStart, tStep, convertResult)
%MIGRATESTEPMARK Print one "[migrate step]" line and start the next step clock.
%   The line carries the step's own wall time, the time since
%   ndi.migrate.local started, the process memory and, when CONVERTRESULT is a
%   converter result, its migrated and quarantined counts. Memory is read from
%   /proc/self/status (VmRSS = resident now, VmHWM = peak resident); where that
%   file does not exist (not Linux) the memory field is left out, so a missing
%   figure is visibly absent rather than printed as 0. Changes nothing.
    mem = '';
    try
        if isfile('/proc/self/status')
            txt = fileread('/proc/self/status');
            rss = regexp(txt, 'VmRSS:\s*(\d+)\s*kB', 'tokens', 'once');
            hwm = regexp(txt, 'VmHWM:\s*(\d+)\s*kB', 'tokens', 'once');
            if ~isempty(rss)
                mem = sprintf('  VmRSS %.0f MB', str2double(rss{1}) / 1024);
            end
            if ~isempty(hwm)
                mem = sprintf('%s  VmHWM %.0f MB', mem, str2double(hwm{1}) / 1024);
            end
        end
    catch
        mem = '';
    end
    docs = '';
    if isstruct(convertResult) && isfield(convertResult, 'migrated')
        nQ = 0;
        if isfield(convertResult, 'quarantine'); nQ = numel(convertResult.quarantine); end
        docs = sprintf('  documents %d  quarantined %d', ...
            numel(convertResult.migrated), nQ);
    end
    fprintf('[migrate step] %-40s step %9.1f s  elapsed %9.1f s%s%s\n', ...
        label, toc(tStep), toc(tStart), mem, docs);
    tNext = tic;
end

function printMigrationNoteCounts(convertResult)
%PRINTMIGRATIONNOTECOUNTS Pass 1's migration-note counts, one line per kind.
%   did2.convert.reportNote's notes ride on summary.migration_notes; their
%   number is part of what pass 1 holds in memory, so it is printed beside the
%   step marks. A summary with no such field prints that it has none.
    if ~isfield(convertResult, 'summary') || ~isstruct(convertResult.summary) ...
            || ~isfield(convertResult.summary, 'migration_notes')
        fprintf('[migrate step]   pass-1 migration notes: no migration_notes field\n');
        return;
    end
    notes = convertResult.summary.migration_notes;
    if ~isstruct(notes) || isempty(fieldnames(notes))
        fprintf('[migrate step]   pass-1 migration notes: 0 kinds\n');
        return;
    end
    kinds = fieldnames(notes);
    for k = 1:numel(kinds)
        n = notes.(kinds{k});
        kept = NaN;
        if isfield(n, 'ids'); kept = numel(n.ids); end
        fprintf('[migrate step]   pass-1 migration notes: %-28s %d note(s), %d id(s) held\n', ...
            kinds{k}, n.count, kept);
    end
end

% ---- second pass: session-context-dependent deferrals ---------------------

function [convertResult, bathAnchors] = resolveDeferred(convertResult, resolver, options)
%RESOLVEDEFERRED Assemble the deferrals that need the session/element graph.
%   The per-document converter quarantines context-dependent classes with
%   reason did2:convert:needsSessionContext rather than emitting a partial
%   (a manipulation must be emitted complete). Here -- with every body in
%   hand via RESOLVER -- we re-assemble each such document, then fold the
%   assembled bodies back through v1_to_v2 at the same TargetVersion. Because
%   the assembled bodies are tagged schema_version == TargetVersion, v1_to_v2
%   short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate; it
%   does not re-migrate. Successfully assembled+validated docs move from
%   quarantine into migrated; anything that cannot be assembled or fails
%   validation stays quarantined with a reason.
%
%   BATHANCHORS (did-schema #88) is the struct array of the bath time anchors
%   minted "during the session", each with the stimulator's epoch string and
%   clock, for resolveEpochAnchorFold to re-point at the epoch entity once
%   did2.convert.epochMint has minted it. [] when none.
    bathAnchors = [];
    q = convertResult.quarantine;
    if isempty(q)
        return;
    end
    keep = true(1, numel(q));
    assembled = {};
    for k = 1:numel(q)
        if ~isDeferredForContext(q(k))
            continue;
        end
        try
            v1Body = jsondecode(q(k).original_body);
            [bodies, anchorInfo] = assembleDeferred(q(k).class_name, v1Body, ...
                resolver, options.TargetVersion);
            assembled = [assembled, bodies]; %#ok<AGROW>
            if ~isempty(anchorInfo)
                if isempty(bathAnchors)
                    bathAnchors = anchorInfo;
                else
                    bathAnchors(end+1) = anchorInfo; %#ok<AGROW>
                end
            end
            keep(k) = false;   % resolved -> drop the original deferral
        catch
            % leave it quarantined with its original (deferral) reason
        end
    end
    if isempty(assembled)
        return;
    end
    sub = did2.convert.v1_to_v2(assembled, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [q(keep), sub.quarantine];
    convertResult.summary = recountSummary(convertResult);
end

function tf = isDeferredForContext(qEntry)
% A quarantine entry is a session-context deferral we can re-assemble here.
% Match on class_name FIRST -- the authoritative signal, since assembleDeferred
% dispatches on it -- so detection stays correct even when a migrator rephrases
% its deferral message. (The migrators_j stimulus_bath deferral, for instance,
% says "require the session/element graph" and carries neither the
% needsSessionContext identifier nor the "NDI layer" phrase in its message.)
% This mirrors did2.convert.resolveDeferredBaths.isDeferredBath, the coarse
% corpus counterpart. The reason-string match is kept as a defensive fallback.
    tf = false;
    if isfield(qEntry, 'class_name') ...
            && any(strcmp(qEntry.class_name, deferredAssemblerClasses()))
        tf = true;
        return;
    end
    if ~isfield(qEntry, 'reason') || ~ischar(qEntry.reason)
        return;
    end
    tf = contains(qEntry.reason, 'needsSessionContext') ...
        || contains(qEntry.reason, 'NDI layer');
end

function classes = deferredAssemblerClasses()
% The v1 classes assembleDeferred knows how to re-assemble with the
% session/element graph. Keep in sync with assembleDeferred's switch.
    classes = {'stimulus_bath'};
end

function [bodies, anchorInfo] = assembleDeferred(className, v1Body, resolver, targetVersion)
% Dispatch a deferred v1 body to its session-aware assembler. Returns a cell
% array of target-version bodies (so a 1 -> N assembly fits). Add new
% context-dependent classes here as their assemblers land.
    switch className
        case 'stimulus_bath'
            [bathBody, timeRefBody, extraBodies, anchorInfo] = ...
                ndi.migrate.internal.stimulusBathToBath(v1Body, resolver, ...
                    targetVersion);
            % timeRefBody is [] when V_eta declines to anchor (no epoch string,
            % or a 'no_time' clock -- NO TIMES => NO REFERENCE). Passing an
            % empty body on would quarantine it, which is exactly the hollow
            % document the refusal exists to avoid, so it is dropped here and
            % the manipulation simply carries no time_reference_1 (an OPTIONAL
            % dependency).
            if isempty(timeRefBody)
                bodies = {bathBody};
            else
                bodies = {timeRefBody, bathBody};
            end
            % did-schema #88: the bath's formulation and its chemicals
            bodies = [bodies, extraBodies];
        otherwise
            error('NDI:migrate:noAssembler', ...
                'No session-aware assembler for deferred class "%s".', ...
                className);
    end
end

function summary = recountSummary(convertResult)
% Recompute the summary after the second pass folds assembled documents in.
% `total` keeps its original meaning (count of source bodies read); only the
% migrated/quarantine counts and the by_class table shift.
    summary = convertResult.summary;
    summary.migrated_count = numel(convertResult.migrated);
    summary.quarantine_count = numel(convertResult.quarantine);
    byClass = struct();
    for k = 1:numel(convertResult.migrated)
        name = convertResult.migrated{k}.className();
        fieldName = matlab.lang.makeValidName(name);
        if isfield(byClass, fieldName)
            byClass.(fieldName) = byClass.(fieldName) + 1;
        else
            byClass.(fieldName) = 1;
        end
    end
    summary.by_class = byClass;
end

function [convertResult, report] = resolvePathS(convertResult, options, mode)
%RESOLVEPATHS V_eta second pass: a statement about an anatomical region of a
%   subject targets that region's part entity (one per subject and region,
%   type tissue, `part_of` the subject; Jess Haley, 2026-10-21, replacing D3's
%   located-by-default). MODE 'sites': a pass-1 site observation co-anchored
%   with a manipulation becomes the part (+ its kind assertion + `part_of`)
%   and the manipulation moves onto it. MODE 'located': a statement whose
%   instrument carries a location (probe_location), or a label naming an
%   UBERON region, moves onto the part. See ndi.migrate.internal.pathSPromotion.
%
%   The minted parts are folded through v1_to_v2 FIRST; if any of them
%   quarantines, NOTHING moves (the batch is left exactly as it was found and
%   the count is reported), so no statement can be left pointing at a part
%   that was not written.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, minted, changed, report] = ...
        ndi.migrate.internal.pathSPromotion(structs, 'Mode', mode);
    report.minted_folded = 0;
    report.minted_quarantined = 0;
    report.reverted = false;
    if ~changed
        printRegionParts(report);
        return;
    end
    % fold the minted part entity / kind assertion / part_of bodies through
    % v1_to_v2: they are tagged schema_version 'did_v2', so the converter
    % short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate
    % rather than re-migrating -- the same footing the deferred-resolution pass
    % uses.
    sub = struct('migrated', {{}}, 'quarantine', struct([]));
    if ~isempty(minted)
        sub = did2.convert.v1_to_v2(minted, ...
            'Validate', options.Validate, ...
            'SchemaCache', options.SchemaCache, ...
            'TargetVersion', options.TargetVersion, ...
            'Verbose', false);
        report.minted_folded = numel(sub.migrated);
        report.minted_quarantined = numel(sub.quarantine);
    end
    if report.minted_quarantined > 0
        report.reverted = true;
        printRegionParts(report);
        warning('NDI:migrate:regionPartQuarantined', ...
            ['%d minted region-part document(s) did not validate; no statement ' ...
             'was moved onto a part (%s pass).'], report.minted_quarantined, mode);
        return;
    end
    % rewrap the surviving (possibly retargeted) bodies
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = [keptDocs, sub.migrated];
    convertResult.summary = recountSummary(convertResult);
    printRegionParts(report);
end

function printRegionParts(r)
%PRINTREGIONPARTS The region-part pass's own census, denominator first.
    if isempty(r); return; end
    fprintf(['REGION PARTS (%s)\n' ...
        '  DENOMINATOR: %d migrated document(s); %d part(s) already in the batch\n' ...
        '  site observations %d: promoted %d, not co-anchored %d, unanchored %d; ' ...
        'laterality folded %d; groups with several areas %d, several sides %d\n' ...
        '  located instruments (probes inspected) %d: one area %d, area + laterality %d, ' ...
        'laterality only %d, several areas %d, several sides %d, no region %d\n' ...
        '  statements with a located instrument %d; laterality folded %d; ' ...
        'onto a region part of a slice %d\n' ...
        '  labels %d (anatomical %d, retargeted %d)\n' ...
        '  site conditions %d: retargeted %d, not UBERON %d\n' ...
        '  retargeted: observations %d, manipulations %d; parts minted %d ' ...
        '(on slices %d, with a laterality assertion %d; folded %d, quarantined %d, reverted %d)\n' ...
        '  anatomy terms inspected %d: UBERON %d, non-UBERON %d (kept as written)\n' ...
        '  left: instrument has several areas %d, several sides %d, no region %d; ' ...
        'side without region %d; about a region part %d, a tissue part of nothing %d, ' ...
        'a device %d, an element %d, another entity type %d; subject not in batch %d, ' ...
        'not an entity %d, no subject %d\n'], ...
        r.mode, r.documents_read, r.parts_found_existing, ...
        r.site_observations_seen, r.site_observations_promoted, ...
        r.site_observations_not_co_anchored, r.site_observations_unanchored, ...
        r.sites_laterality_folded, r.sites_several_areas, r.sites_several_sides, ...
        r.located_instruments, r.instruments_one_area, ...
        r.instruments_area_with_laterality, r.instruments_laterality_only, ...
        r.instruments_several_areas, r.instruments_several_sides, ...
        r.instruments_no_region, r.statements_with_located_instrument, ...
        r.laterality_folded, r.statements_retargeted_onto_slice_parts, ...
        r.label_observations_seen, r.label_observations_anatomical, ...
        r.label_observations_retargeted, ...
        r.site_conditions_seen, r.site_conditions_retargeted, ...
        r.site_conditions_not_uberon, r.observations_retargeted, ...
        r.manipulations_retargeted, r.parts_minted, r.parts_minted_on_slices, ...
        r.laterality_assertions_minted, r.minted_folded, ...
        r.minted_quarantined, double(r.reverted), ...
        r.anatomy_terms_inspected, r.anatomy_terms_uberon, r.anatomy_terms_non_uberon, ...
        r.left_instrument_has_several_areas, r.left_instrument_has_several_sides, ...
        r.left_instrument_has_no_region, r.left_side_without_region, ...
        r.left_about_a_region_part, r.left_about_a_tissue_part_of_nothing, ...
        r.left_about_a_device, r.left_about_an_element, ...
        r.left_about_another_entity_type, r.left_subject_not_in_batch, ...
        r.left_subject_not_an_entity, r.left_no_subject);
    for k = 1:numel(r.anatomy_non_uberon)
        t = r.anatomy_non_uberon(k);
        fprintf('    non-UBERON anatomy term %d x  node "%s"  name "%s"\n', ...
            t.count, t.node, t.name);
    end
end

function [convertResult, report] = resolveEnsembleMembership(convertResult, ...
    epochMintReport, options)
%RESOLVEENSEMBLEMEMBERSHIP V_eta second pass: turn each `ensemble` map document
%   into `member_of` edges (each neuron-subject -> the ensemble group-subject,
%   carrying its column order) plus `derived_from` provenance recording that the
%   combined marked-point-process binary is a REBUILDABLE CACHE of those same
%   neurons. The neuron ids are `depends_on` edges on the map document
%   (`neuron_id_1..n`, written in column order by
%   +ndi/+element/ensemble.m:274-276), so no file bytes are read -- but the
%   neuron ids must RESOLVE to migrated subjects, which only the whole body set
%   can answer, hence a second pass.
%
%   THIS PASS ONLY ADDS. The map document, the `acquisition_epoch` and its
%   binary are all left in place: dropping them is gated on a corpus
%   verify-before-delete that has not run. The pass MEASURES that gate and
%   reports its denominator first; NOTHING here deletes anything and no option
%   enables deletion.
%
%   THE GATE IS `REPORT.verify_before_delete_clear`, AND IT IS NOT
%   `neuron_edges_stranded`. This docstring named that field until it was
%   corrected: it asks whether the neuron SUBJECT is in the migrated set, and
%   migrators_j.element turns an element into a bare `subject` carrying NO
%   data, so every subject can be present, that counter can read 0, and the
%   per-neuron trains can be absent entirely. The train fields --
%   REPORT.neuron_trains_present_this_epoch / _other_epoch_only /
%   _missing_entirely, REPORT.neurons_missing_train_ids -- ask the data
%   question, mirroring NDI's own readtimeseries lookup
%   (+ndi/+element/timeseries.m:56-70).
%
%   ORDER: AFTER did2.convert.epochMint, FOR A REAL REASON -- the same reason
%   sub-pass (7e) states. The signed model requires the `member_of` edges to be
%   EPOCH-SCOPED, because the recorded neuron set changes epoch to epoch; an
%   unscoped roster silently flattens a per-epoch fact. The epoch DOCUMENT ids
%   those edges point at exist only after epochMint runs, so this pass placed
%   before it can only emit unscoped edges. It used to run before it.
%
%   The resolver below is built from epochMint's OWN index rows, keyed on the
%   PAIR (base.session_id, epoch string) exactly as epochAnchorFold keys them
%   -- never on the string alone, because epochMint measured `epochid.epochid`
%   REUSED ACROSS SESSIONS in 142 of corpus B's 149 distinct ids, and grouping
%   on the string would fuse epochs from different animals.
%
%   WHEN AN EPOCH DOES NOT RESOLVE the edge is still emitted, UNSCOPED, and
%   counted in its own named field -- membership is preserved (dropping it
%   would lose the roster outright) while the per-epoch fact is not. The three
%   reasons are counted separately (REPORT.maps_unscoped_no_resolver /
%   _no_epoch_string / _epoch_unresolved) because they have different remedies.
%
%   See ndi.migrate.internal.ensembleMembership for what is deliberately not
%   built yet: the `sampled_body` cache document carrying the T6 `is_cache`
%   marker. THIS SENTENCE SAID "neither of which exists in the built schema
%   set". HALF STALE, corrected 2026-08-17 -- `sampled_body` exists and is
%   emitted by four production migrators through
%   `+migrators_j/private/jSampledBody.m`; `is_cache` is declared by 0 of the
%   247 json files under DID-schema `schemas/V_eta/`, and THAT is the blocker.
%   Without the marker the cache is indistinguishable from the primary
%   per-neuron data, which is the one thing the signed model guarantees. See
%   item 3 of the assembler's header for the evidence and for the owning
%   `statement` the body would also need.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    % Index epochMint's own rows by the PAIR. Built here rather than inside the
    % assembler so the assembler stays pure struct logic with no knowledge of
    % epochMint's report shape -- the same split epochAnchorFold uses.
    epochIndex = struct('session_id', {}, 'local_identifier', {}, ...
                        'epoch_document_id', {});
    if isstruct(epochMintReport) && isfield(epochMintReport, 'epoch_index')
        epochIndex = epochMintReport.epoch_index;
    end
    epochByPair = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for k = 1:numel(epochIndex)
        sid = charOrEmpty(epochIndex(k), 'session_id');
        lid = charOrEmpty(epochIndex(k), 'local_identifier');
        did_ = charOrEmpty(epochIndex(k), 'epoch_document_id');
        if isempty(sid) || isempty(lid) || isempty(did_)
            continue;   % half a key names no epoch
        end
        key = [sid '|' lid];
        if ~isKey(epochByPair, key)
            epochByPair(key) = did_;
        end
    end
    % '' for anything that does not resolve -- the assembler then emits the
    % edge UNSCOPED and counts it, and never emits an empty `epoch_id`.
    resolver = @(epochStr, sessionId) lookupEpochDoc(epochByPair, epochStr, sessionId);

    [kept, minted, report] = ndi.migrate.internal.ensembleMembership( ...
        structs, 'EpochDocumentIdFor', resolver);
    report.epoch_index_rows       = numel(epochIndex);
    report.epoch_index_pairs_usable = double(epochByPair.Count);
    if ~report.changed
        return;
    end
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = keptDocs;
    % The minted relations are tagged schema_version 'did_v2', so v1_to_v2
    % short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate --
    % the same footing the deferred-resolution and Path-S passes use.
    sub = did2.convert.v1_to_v2(minted, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    if ~isempty(sub.quarantine) && ~isempty(report.dissolved_map_ids)
        % D2: a map dissolves INTO its edges. An edge that did not validate
        % means the map's content is not all said elsewhere, so no map
        % dissolves in this batch; counted, and the quarantine stays loud.
        convertResult.migrated = docs;
        report.ensemble_maps_kept_edges_quarantined = report.ensemble_maps_dissolved;
        report.ensemble_maps_dissolved = 0;
        report.dissolved_map_ids = {};
        report.combined_bytes_dropped = 0;
        report.dropped_carrier_ids = {};
    end
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    convertResult.summary = recountSummary(convertResult);
end

function e = secondPassErrorReport(stepErrors, labelReport, ensembleReport)
%SECONDPASSERRORREPORT The second pass's DEFECTS, apart from its carries
%   ([pipeline defects are not carries], Jess Haley, 2026-10-26): the steps
%   that threw (STEPERRORS, {step, message}) and the re-folds whose output
%   quarantined, so the source document was reverted (labels, ensemble maps;
%   table rows are no longer re-folded, [table rows carried as v1]). A count
%   is NaN when its step did not report (not measured); TOTAL sums the
%   measured counts.
e = struct();
e.steps_failed = numel(stepErrors);
e.steps = stepErrors;
e.refold_quarantined = struct( ...
    'ontology_label',     fieldOr(labelReport, 'refold_quarantined'), ...
    'ensemble',           fieldOr(ensembleReport, 'ensemble_maps_kept_edges_quarantined', 0));
q = struct2cell(e.refold_quarantined);
q = [q{:}];
e.total = e.steps_failed + sum(q(~isnan(q)));
end

function v = fieldOr(r, name, absentValue)
% R.(NAME) when R is a report holding it; else ABSENTVALUE when R reported
% (the field is set only when the event happened), or NaN when R is [].
if nargin < 3
    absentValue = NaN;
end
v = NaN;
if isstruct(r) && isscalar(r)
    v = absentValue;
    if isfield(r, name) && isnumeric(r.(name)) && isscalar(r.(name))
        v = double(r.(name));
    end
end
end

function rows = secondPassCarryRows(reports)
%SECONDPASSCARRYROWS The {id, row} records of every document a second-pass
%   step left as v1 (each step's REPORT.carry_rows), concatenated. A step that
%   did not run (its report is []) contributes none. [carry register], Jess
%   Haley, 2026-10-26 (did-schema V_eta_go_forward_class_audit.md).
%   A record may name a `dependency` (the document whose carry would make
%   this one a dependent, [dependents of a carried document carry]); it is ''
%   when the step names none.
rows = struct('id', {}, 'row', {}, 'dependency', {});
for k = 1:numel(reports)
    r = reports{k};
    if isstruct(r) && isscalar(r) && isfield(r, 'carry_rows') && isstruct(r.carry_rows) ...
            && isfield(r.carry_rows, 'id') && isfield(r.carry_rows, 'row')
        add = reshape(r.carry_rows, 1, []);
        if isempty(add)
            continue;
        end
        if isfield(add, 'dependency')
            dep = {add.dependency};
        else
            dep = repmat({''}, 1, numel(add));
        end
        rows = [rows, reshape(struct('id', {add.id}, 'row', {add.row}, ...
            'dependency', dep), 1, [])]; %#ok<AGROW>
    end
end
end

function report = countOntologyRows(convertResult, bodies)
%COUNTONTOLOGYROWS V_eta second pass: count the v1 `ontologyTableRow`
%   documents and how many of them the migrated set still carries as a table
%   row. It changes nothing.
%
%   Decided by Jess Haley, 2026-10-30 [table rows carried as v1] (did-schema
%   V_eta_go_forward_class_audit.md): the generic migration carries every v1
%   `ontologyTableRow` whole as v1; it resolves no subject and fans out no
%   statements. This replaces the step that resolved a row's subject and
%   re-folded the row through did2.convert.v1_to_v2. The count is kept so the
%   rows still have a denominator in the log
%   (ndi.migrate.internal.ontologyRowsCarried).
    docs = convertResult.migrated;
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    report = ndi.migrate.internal.ontologyRowsCarried(decodeBodies(bodies), structs);
end

function [convertResult, report] = resolveSliceTetanus(convertResult, bodies, ...
    epochMintReport, options)
%RESOLVESLICETETANUS V_eta second pass: Dabrowska brain slices as entities,
%   one optogenetic-tetanus manipulation per recording run on a relative
%   window, the before/after approach labels dropped once they rebuild from
%   it, and a recording day filed under the wrong animal given its own.
%
%   ndi.migrate.internal.sliceTetanus plans (pure struct logic). This function
%   folds the MINTED bodies through did2.convert.v1_to_v2 (validated; a
%   quarantine there is a real one and is kept, visible), then applies the
%   edge moves and removals only where every document they point at survived.
%   The moved documents keep their base.id, so nothing pointing at them breaks.
    report = [];
    if ~strcmp(options.TargetVersion, 'V_eta')
        return;
    end
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    epochIndex = struct('session_id', {}, 'local_identifier', {}, ...
                        'epoch_document_id', {});
    if isstruct(epochMintReport) && isfield(epochMintReport, 'epoch_index')
        epochIndex = epochMintReport.epoch_index;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [plan, report] = ndi.migrate.internal.sliceTetanus( ...
        decodeBodies(bodies), structs, epochIndex);
    report.minted_folded = 0;
    report.minted_quarantined = 0;
    report.folded = false;
    if ~report.changed
        printSliceTetanus(report);
        return;
    end

    minted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    if ~isempty(plan.minted)
        sub = did2.convert.v1_to_v2(plan.minted, ...
            'Validate',      options.Validate, ...
            'SchemaCache',   options.SchemaCache, ...
            'TargetVersion', options.TargetVersion, ...
            'Verbose',       false);
        report.minted_folded = numel(sub.migrated);
        report.minted_quarantined = numel(sub.quarantine);
        convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
        for k = 1:numel(sub.migrated)
            minted(sub.migrated{k}.get('base.id')) = true;
        end
        convertResult.migrated = [convertResult.migrated, sub.migrated];
    end

    % Apply a move only when its new target was minted; drop a document only
    % when nothing minted failed (a failed mint keeps what it would replace).
    replacedById = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(plan.replaced)
        s = plan.replaced{k};
        if movedTargetMinted(s, minted)
            replacedById(s.base.id) = s;
        end
    end
    removed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    if report.minted_quarantined == 0
        for k = 1:numel(plan.removed)
            removed(plan.removed{k}) = true;
        end
    end
    out = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        id = d.get('base.id');
        if isKey(removed, id)
            continue;
        end
        if isKey(replacedById, id)
            d = did2.document(replacedById(id));
        end
        out{end+1} = d; %#ok<AGROW>
    end
    report.reattributions_applied = double(replacedById.Count);
    report.removals_applied = double(removed.Count);
    convertResult.migrated = out;
    convertResult.summary = recountSummary(convertResult);
    report.folded = true;
    printSliceTetanus(report);
end

function tf = movedTargetMinted(s, minted)
% The moved edge -- `entity_id` on a statement, `parent_id` on a relation
% (did-schema #88; `subject_id` / `parent` before) -- always names a minted
% slice; the move stands only if that slice was folded.
    edges = {'entity_id', 'subject_id'};
    if strcmp(s.document_class.class_name, 'directed_relation')
        edges = {'parent_id', 'parent'};
    end
    tf = false;
    for k = 1:numel(s.depends_on)
        if any(strcmp(s.depends_on(k).name, edges))
            v = '';
            if isfield(s.depends_on(k), 'value'); v = s.depends_on(k).value;
            elseif isfield(s.depends_on(k), 'document_id'); v = s.depends_on(k).document_id; end
            tf = ischar(v) && isKey(minted, v);
            return;
        end
    end
end

function printSliceTetanus(r)
%PRINTSLICETETANUS The pass's own census, denominators first, in the log.
    if isempty(r); return; end
    fprintf(['SLICE / TETANUS (Dabrowska)\n' ...
        '  DENOMINATOR: %d v1 document(s), %d migrated document(s), %d epoch index entr(ies)\n' ...
        '  stimulators %d: slice baths %d, not a slice bath %d, animal mismatch %d\n' ...
        '  slices minted %d; new animals %d (epochs on a nested date %d); strain assertions copied %d\n' ...
        '  epoch-anchored statements examined %d: matched %d, unmatched %d\n' ...
        '  unanchored statements examined %d: matched %d, ambiguous %d\n' ...
        '  element observes-relations examined %d: matched %d, ambiguous %d\n' ...
        '  approach labels %d; runs examined %d; refused: not a clean switch %d, no epoch doc %d, no gap %d\n' ...
        '  tetanus manipulations %d (on a new animal %d): with target region %d, without %d; ' ...
        'with parameters %d, without %d\n' ...
        '  labels rebuilt %d/%d (not rebuilt %d); approach documents removed %d\n' ...
        '  treatment manipulations found %d: superseded %d, kept (no run) %d; part-subjects superseded %d\n' ...
        '  minted %d (folded %d, quarantined %d); re-attributed %d; removed %d; removals withheld %d\n'], ...
        r.v1_documents_read, r.migrated_documents_read, r.epoch_index_entries, ...
        r.stimulators, r.slice_bath_stimulators, r.stimulators_not_a_slice_bath, ...
        r.stimulators_animal_mismatch, r.slices, r.new_animals, ...
        r.epochs_on_a_nested_date, r.new_animal_strain_assertions_copied, ...
        r.epoch_statements_examined, r.epoch_statements_matched, r.epoch_statements_unmatched, ...
        r.unanchored_statements_examined, r.unanchored_statements_matched, ...
        r.unanchored_statements_ambiguous, r.element_relations_examined, ...
        r.element_relations_matched, r.element_relations_ambiguous, ...
        r.approach_labels, r.runs_examined, r.runs_refused_not_a_clean_switch, ...
        r.runs_refused_no_epoch_document, r.runs_refused_no_gap, ...
        r.tetanus_manipulations, r.tetanus_on_new_animal, r.tetanus_with_target_region, ...
        r.tetanus_without_target_region, r.tetanus_with_parameters, r.tetanus_without_parameters, ...
        r.labels_rebuilt, r.approach_labels, r.labels_not_rebuilt, r.approach_labels_removed, ...
        r.treatment_manipulations_found, r.treatment_manipulations_superseded, ...
        r.treatment_manipulations_kept_no_run, r.treatment_part_subjects_superseded, ...
        r.documents_minted, r.minted_folded, r.minted_quarantined, ...
        r.documents_reattributed, r.documents_removed, r.removals_withheld_still_referenced);
    cls = fieldnames(r.reattributed_by_class);
    for k = 1:numel(cls)
        fprintf('    re-attributed %-28s %d\n', cls{k}, r.reattributed_by_class.(cls{k}));
    end
end

function [convertResult, report] = resolveRecordingAttribution(convertResult, options)
%RESOLVERECORDINGATTRIBUTION V_eta second pass: a raw recording is an
%   observation OF THE SPECIMEN, taken WITH the probe (T7) -- for every emitter,
%   not just the one that could see the specimen in its own document.
%
%   ndi.migrate.internal.recordingAttribution does the RESOLUTION (pure struct
%   logic, no converter, no schema, no database) and returns a plan carrying a
%   ready V_eta body per re-attributable observation. This function does the
%   REPLACEMENT, ONE AT A TIME and REVERTIBLY, through did2.convert.v1_to_v2 --
%   the same footing epochAnchorFold, resolveOntologyLabelSubjects and Path-S
%   use, and for the same reason: a re-fold that QUARANTINES must not replace a
%   document that validated. Trading a clean document for a gating quarantine is
%   the `epochfiles_ingested` regression (2,484 documents) all over again.
%
%   THE base.id IS PRESERVED, so every `derived_from` / `time_reference_#` edge
%   pointing at the observation keeps resolving across the replacement. Only the
%   subject and instrument edges move.
%
%   WHY IT RUNS AFTER epochAnchorFold: no data dependency, but the anchor fold
%   REPLACES documents too, and running after it means this pass reads the
%   settled set rather than bodies that are about to be superseded. Cheap
%   ordering, one fewer interaction to reason about.
%
%   STATUS: WRITTEN 2026-08-13 IN A CONTAINER WITH NO MATLAB. NOT EXECUTED HERE.
    report = [];
    if ~strcmp(options.TargetVersion, 'V_eta')
        return;     % `instrument_id` on an observation is a V_eta shape.
    end
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end

    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [plan, report] = ndi.migrate.internal.recordingAttribution(structs);

    % Initialised unconditionally, before the early return: a pass that plans
    % nothing must report the same fields as one that replaces everything.
    report.observations_reattributed = 0;
    report.reattribution_quarantined = 0;
    report.folded                    = false;
    fprintf(['RECORDING ATTRIBUTION\n' ...
        '  DENOMINATOR: %d migrated document(s); %d observation(s): %d donor(s), %d candidate(s)\n' ...
        '  attributed %d (via a recording-observation donor %d, via the element''s observes %d); ' ...
        'observes relations %d\n' ...
        '  refused: no donor %d, no subject %d, self reference %d, ambiguous probe %d, ' ...
        'ambiguous observes %d\n'], ...
        report.documents_inspected, report.observations, report.donors, ...
        report.candidates, report.attributed, ...
        report.attributed - report.attributed_via_observes, ...
        report.attributed_via_observes, report.observes_relations, ...
        report.refused_no_donor, report.refused_no_subject, ...
        report.refused_self_reference, report.refused_ambiguous_probe, ...
        report.refused_ambiguous_observes);
    if isempty(plan)
        return;
    end

    replacedIds = {};
    newDocs = {};
    for k = 1:numel(plan)
        try
            sub = did2.convert.v1_to_v2({plan(k).body}, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion, ...
                'Verbose',       false);
        catch
            report.reattribution_quarantined = ...
                report.reattribution_quarantined + 1;
            continue;   % REVERT: keep the pass-1 document
        end
        if ~isempty(sub.quarantine) || isempty(sub.migrated)
            report.reattribution_quarantined = ...
                report.reattribution_quarantined + 1;
            continue;   % REVERT
        end
        replacedIds{end+1} = plan(k).source_id; %#ok<AGROW>
        newDocs = [newDocs, sub.migrated]; %#ok<AGROW>
        report.observations_reattributed = ...
            report.observations_reattributed + 1;
    end

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the re-attributed document, same id
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.folded = true;
    report.changed = true;
end

function [convertResult, report] = resolveOntologyLabelSubjects(convertResult, options)
%RESOLVEONTOLOGYLABELSUBJECTS V_eta second pass: give each passed-through
%   `ontology_label` the subject it is about, as a `term_observation` whose
%   `derived_from_1` still names the document that was labelled.
%
%   ndi.migrate.internal.ontologyLabelSubjects does the RESOLUTION (pure struct
%   logic, no converter, no schema) and returns a plan carrying a ready V_eta
%   body per resolvable label. This function does the FOLD, one label at a time,
%   through did2.convert.v1_to_v2 at TargetVersion V_eta -- where the body is
%   tagged schema_version 'did_v2' and is therefore short-circuited
%   (isAlreadyTarget) to ensureClassBlocks + validate, the same footing Path-S
%   and ensembleMembership use for minted bodies.
%
%   THE LABEL'S id IS PRESERVED, so the replacement supersedes the passthrough
%   rather than joining it: two documents with one id is not a state this
%   database has a meaning for. The passthrough is removed only for labels whose
%   replacement actually came back out of the re-fold.
%
%   ONE AT A TIME, AND REVERTIBLE, ON PURPOSE: a re-fold that
%   QUARANTINES must not replace a passthrough that validated. Trading a
%   non-gating passthrough for a gating quarantine is the `epochfiles_ingested`
%   regression (2,484 documents) and the reverted distance_metadata endpoint
%   relation (a quarantine turned into 4,156 orphans).
%
%   WHAT IT WILL NOT DO: attribute the E. coli half. Three of the seven
%   `ndi.document('imageStack'...)` sites in +setup/+conv/+haley/doImport.m
%   (:789 :811 :827) set `document_id` only -- those images are of bacterial
%   patches on plates and the session has no subject -- so their labels resolve
%   to a referent with nothing to inherit. They are COUNTED
%   (`blocked_target_has_no_subject`, split by referent class) and left passing
%   through. Whether such a document ever gets a subject is a team modelling
%   call, not a migration operation.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [plan, report] = ndi.migrate.internal.ontologyLabelSubjects(structs);

    % Fold outcomes belong to the same instrument, so they are initialised
    % unconditionally -- a field that appears only on the success path is a
    % counter that cannot report a zero.
    report.labels_planned      = numel(plan);
    report.labels_replaced     = 0;
    report.refold_quarantined  = 0;
    report.changed             = false;
    if isempty(plan)
        return;
    end

    replacedIds = {};
    newDocs = {};
    for k = 1:numel(plan)
        try
            % the observation and its `derived_from` relation (did-schema
            % #88) fold together: either both land or the label stays
            sub = did2.convert.v1_to_v2([{plan(k).body}, plan(k).related], ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion, ...
                'Verbose',       false);
        catch
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT: keep the passthrough
        end
        if ~isempty(sub.quarantine) || isempty(sub.migrated)
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT
        end
        replacedIds{end+1} = plan(k).source_id; %#ok<AGROW>
        newDocs = [newDocs, sub.migrated]; %#ok<AGROW>
        report.labels_replaced = report.labels_replaced + 1;
    end

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if ndi.migrate.internal.isOntologyLabelClass(d.className()) ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the term_observation carrying its id
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.changed = true;
end

function [convertResult, report] = resolveStrainAssembly(convertResult, options)
%RESOLVESTRAINASSEMBLY V_eta second pass: assemble the unattached `openminds`
%   Strain documents into strain entities (did-schema #88: `entity`, type
%   `strain`) with their ids PRESERVED, turning the Species /
%   GeneticStrainType fragment documents they reference into assertions about
%   the strain and `backgroundStrain` into `derived_from` relations. A second
%   pass because those values live in OTHER documents, reachable only through
%   the `ndi://` / `openminds_#` links a single-document migrator cannot follow.
%
%   Id preservation is load-bearing rather than tidy: `ontologyTableRow`'s
%   `bacteriaStrain` column holds the strain document's id as a plain string
%   (haley/doImport.m:164,734), so nothing would flag a re-mint. No
%   `instance_of` is minted here: what is an instance of these strains is
%   minted by the pass that reads those rows.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, minted, report] = ndi.migrate.internal.strainAssembly(structs);
    if ~report.changed
        return;
    end
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = keptDocs;
    sub = did2.convert.v1_to_v2(minted, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, report] = resolveSubjectStrainAssembly(convertResult, bodies, options)
%RESOLVESUBJECTSTRAINASSEMBLY V_eta second pass (#78): the openminds_subject
%   half of the strain family -- one deduplicated strain entity per distinct
%   strain (did-schema #88), the subject an `instance_of` it in place of its
%   strain assertion, the pedigree as `derived_from` relations, the `genetic
%   strain type` assertion moved onto the strain, and the duplicate `species`
%   assertion dropped.
%
%   IT TAKES `bodies`, and that argument is why the pass is NDI-side rather
%   than a preference. Pass 1 keeps only `subject_id` on the emitted
%   `term_assertion` (did2.convert.migrators_j.openminds_subject:52), so the
%   `openminds_#` links, the `backgroundStrain` strings and the fragment
%   documents' contents are ALL unreachable from convertResult.migrated. Every
%   DID-side pass is f(result, options) and `result` carries migrated /
%   quarantine / summary and never the did_v1 bodies -- the same contract fact
%   imagedEntitySubjects is NDI-side for.
%
%   ndi.migrate.internal.subjectStrainAssembly does the whole decision (pure
%   struct logic, no converter, no schema). This wrapper does the two things
%   that need the converter: rewrap the survivors (whose edges changed) and
%   fold the minted `strain` bodies through did2.convert.v1_to_v2 at
%   TargetVersion V_eta, where they are tagged schema_version 'did_v2' and are
%   therefore short-circuited (isAlreadyTarget) to ensureClassBlocks +
%   validate, the same footing Path-S, ensembleMembership and (4) use.
%
%   REPORT is [] when the pass did not run (no documents, or no bodies to read
%   -- the already-migrated fast path hands back migrated bodies, in which case
%   the report's own `v1_openminds_subject_bodies` is 0 and says so). Otherwise
%   it carries its denominators first. REPORT.changed gates the rebuild.
%
%   A MINTED STRAIN THAT QUARANTINES DOES NOT UNDO THE RELATIONS, and that is
%   deliberate rather than overlooked: the strain ids are minted here, so a
%   quarantined strain leaves `instance_of` / `derived_from` relations naming a
%   document that is not in the migrated set -- an ORPHAN, which the gate at
%   the end of ndi.migrate.local
%   counts and which is exactly the loud failure wanted. The alternative,
%   silently dropping the edges, would leave a green run with the work
%   undone. did2.convert.v1_to_v2's quarantine list is carried onto
%   convertResult so the reason travels with it.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs) || isempty(bodies)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, minted, report] = ...
        ndi.migrate.internal.subjectStrainAssembly(bodies, structs);
    if ~report.changed
        return;
    end
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = keptDocs;
    if ~isempty(minted)
        sub = did2.convert.v1_to_v2(minted, ...
            'Validate',      options.Validate, ...
            'SchemaCache',   options.SchemaCache, ...
            'TargetVersion', options.TargetVersion, ...
            'Verbose',       false);
        convertResult.migrated = [convertResult.migrated, sub.migrated];
        convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    end
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, report] = resolveDatasetEntitiesPass(convertResult, options)
%RESOLVEDATASETENTITIESPASS V_eta second pass: finalize the dataset entity
%   layer -- ONE canonical `dataset` per dataset id, and no
%   `migrated_session_membership` edge pointing at a session that is not here.
%
%   STATUS: WIRED 2026-08-10, NEVER EXECUTED (no MATLAB in the container this
%   was written in). Read the divergence it closes in this file's header.
%
%   THE PASS ITSELF IS DID-SIDE and unchanged --
%   did2.convert.resolveDatasetEntities, the same function the three DID call
%   sites call. That is the point: a second implementation here would be the
%   divergence again, one layer down. This wrapper exists only to (a) put the
%   call in its own try/catch like every sibling and (b) MEASURE it, because
%   the DID pass returns no report and a pass with no report is the defect
%   this whole exercise is about -- work that looks done because nothing
%   measures it.
%
%   REPORT is [] when the pass did not run (no documents), and otherwise
%   carries its denominator FIRST (documents_inspected) followed by the
%   before/after census of the only two things the pass can change. Both sides
%   are counted here rather than inside the pass, so a zero drop is
%   distinguishable from a pass that read nothing: `dataset_entities_before`
%   equal to `distinct_dataset_ids` means there was nothing to dedup, while
%   both being 0 means this dataset has no dataset-level source documents at
%   all. Those are different facts and a single "dropped: 0" cannot tell them
%   apart.
%
%   NOTHING IS MINTED, so unlike the minting sub-passes there is no v1_to_v2
%   re-fold: the pass only removes documents, and the survivors were validated
%   on the way in. did2.convert.resolveDatasetEntities recounts
%   `result.summary` itself.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    before = datasetLayerCensus(docs);
    convertResult = did2.convert.resolveDatasetEntities(convertResult, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    after = datasetLayerCensus(convertResult.migrated);

    report = struct();
    report.documents_inspected        = before.documents;   % denominator first
    report.documents_kept             = after.documents;
    report.dataset_entities_before    = before.dataset_entities;
    report.distinct_dataset_ids       = before.distinct_dataset_ids;
    report.dataset_entities_after     = after.dataset_entities;
    report.membership_edges_before    = before.membership_edges;
    report.membership_edges_after     = after.membership_edges;
    report.duplicate_datasets_dropped = ...
        before.dataset_entities - after.dataset_entities;
    report.membership_edges_dropped   = ...
        before.membership_edges - after.membership_edges;
    report.changed = report.documents_kept ~= report.documents_inspected;
end

function c = datasetLayerCensus(docs)
%DATASETLAYERCENSUS The two things did2.convert.resolveDatasetEntities can
%   change, counted over a document set: `dataset` entities (with how many
%   DISTINCT ids they carry, which is what a clean layer would leave one each
%   of) and `migrated_session_membership` relations.
%
%   `migrated_session_membership` is a base.name SENTINEL, not a class --
%   the edge's class is `directed_relation` and the name is what
%   did2.convert.migrators_j.private.jEntityRelation stamps on it
%   (jEntityRelation.m:3,22) so this pass can find it. Matching on the class
%   alone would count every entity-layer edge in the batch.
    c = struct('documents', numel(docs), 'dataset_entities', 0, ...
        'distinct_dataset_ids', 0, 'membership_edges', 0);
    % did-schema #88: a dataset is an `entity` of type `dataset`, and a
    % session's membership is an `included_in` relation; the pre-#88 class
    % name and base.name sentinel are read too -- the same two tests
    % did2.convert.resolveDatasetEntities applies (isDatasetEntity,
    % isMembership), so the census counts what the pass acts on.
    seenIds = {};
    for k = 1:numel(docs)
        cls = docs{k}.className();
        isDataset = strcmp(cls, 'dataset');
        if ~isDataset && strcmp(cls, 'entity')
            t = [];
            try
                t = docs{k}.get('entity.type');
            catch
            end
            isDataset = ~isempty(t) && ndi.v2.vocabIs('entity_type', t, 'dataset');   % by node (L2)
        end
        isMembership = false;
        if strcmp(cls, 'directed_relation')
            isMembership = strcmp(safeDocGet(docs{k}, 'base.name'), ...
                'migrated_session_membership');
            if ~isMembership
                r = [];
                try
                    r = docs{k}.get('directed_relation.relation');
                catch
                end
                isMembership = ~isempty(r) && ndi.v2.vocabIs('relation', r, 'included_in');   % by node (L1)
            end
        end
        if isDataset
            c.dataset_entities = c.dataset_entities + 1;
            id = safeDocGet(docs{k}, 'base.id');
            if ~isempty(id) && ~any(strcmp(id, seenIds))
                seenIds{end+1} = id; %#ok<AGROW>
            end
        elseif isMembership
            c.membership_edges = c.membership_edges + 1;
        end
    end
    c.distinct_dataset_ids = numel(seenIds);
end

function v = safeDocGet(doc, path)
%SAFEDOCGET doc.get(PATH) as char, '' when the field is absent.
    v = '';
    try
        v = char(doc.get(path));
    catch
    end
end

function [convertResult, report] = resolveEpochAnchorFold(convertResult, ...
    epochMintReport, options, bathAnchors)
%RESOLVEEPOCHANCHORFOLD V_eta second pass: fold the pass-1
%   `epoch_bounded_reference` placeholders into the signed `relative_reference`,
%   anchored to the `epoch` documents did2.convert.epochMint just minted.
%
%   ndi.migrate.internal.epochAnchorFold does the RESOLUTION (pure struct logic,
%   no converter, no schema, no database) and returns a plan carrying a ready
%   V_eta body per foldable anchor. This function does the FOLD, ONE AT A TIME
%   and REVERTIBLY, through did2.convert.v1_to_v2 -- the same footing
%   resolveOntologyLabelSubjects, Path-S and ensembleMembership use, and for the
%   same reason: a re-fold that QUARANTINES must not replace a document that
%   validated. Trading a non-gating passthrough for a gating quarantine is the
%   `epochfiles_ingested` regression (2,484 documents) all over again.
%
%   THE base.id IS PRESERVED, so the `time_reference_1` edge the manipulation
%   carries keeps resolving to the same document across the fold. The
%   replacement supersedes the placeholder rather than joining it.
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB. NOT EXECUTED.
    report = [];
    if ~strcmp(options.TargetVersion, 'V_eta')
        return;     % `relative_reference` exists only in V_eta.
    end
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end

    % The index is epochMint's, not a re-derivation. If epochMint did not run,
    % or ran and minted nothing, the fold refuses everything and says so with a
    % denominator rather than silently doing nothing.
    epochIndex = struct('session_id', {}, 'local_identifier', {}, ...
                        'epoch_document_id', {});
    if isstruct(epochMintReport) && isfield(epochMintReport, 'epoch_index')
        epochIndex = epochMintReport.epoch_index;
    end

    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    if nargin < 4 || isempty(bathAnchors)
        bathAnchors = struct('anchor_id', {}, 'session_id', {}, ...
            'epoch_string', {}, 'epoch_clock', {});
    end
    [plan, report] = ndi.migrate.internal.epochAnchorFold(structs, epochIndex, ...
        bathAnchors);

    % Fold outcomes belong to the same instrument, so they are initialised
    % unconditionally -- a field that appears only on the success path is a
    % counter that cannot report a zero.
    report.anchors_refolded   = 0;
    report.refold_quarantined = 0;
    report.folded             = false;
    report.refolded_ids       = {};
    if isempty(plan)
        return;
    end

    replacedIds = {};
    newDocs = {};
    for k = 1:numel(plan)
        try
            sub = did2.convert.v1_to_v2({plan(k).body}, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion, ...
                'Verbose',       false);
        catch
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT: keep the pass-1 placeholder
        end
        if ~isempty(sub.quarantine) || isempty(sub.migrated)
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT
        end
        replacedIds{end+1} = plan(k).source_id; %#ok<AGROW>
        newDocs = [newDocs, sub.migrated]; %#ok<AGROW>
        report.anchors_refolded = report.anchors_refolded + 1;
    end
    report.refolded_ids = replacedIds;

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if any(strcmp(d.className(), {'epoch_bounded_reference', ...
                'relative_time_reference'})) ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the re-anchored reference carrying its id
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.folded = true;
end

function rows = anchorRows(a)
%ANCHORROWS An anchor list as the struct array epochAnchorFold reads ([] -> 0x0).
    rows = struct('anchor_id', {}, 'session_id', {}, 'epoch_string', {}, ...
        'epoch_clock', {});
    for k = 1:numel(a)
        rows(end+1) = struct('anchor_id', char(a(k).anchor_id), ...
            'session_id', char(a(k).session_id), ...
            'epoch_string', char(a(k).epoch_string), ...
            'epoch_clock', char(a(k).epoch_clock)); %#ok<AGROW>
    end
end

function report = tallyPresentationAnchors(report, presentationAnchors, foldReport)
% (the caller reports anchors_left_on_session > 0 as a defect: [epoch-less
% presentations carry] predicted each of them foldable)
%TALLYPRESENTATIONANCHORS After resolveEpochAnchorFold: how many presentation
%   anchors were re-pointed at their epoch, and how many stayed on their
%   session ([presentation anchored to its epoch], Jess Haley, 2026-10-27).
    if ~isstruct(report) || ~isfield(report, 'epoch_anchor') ...
            || ~isstruct(report.epoch_anchor)
        return;
    end
    refolded = {};
    if isstruct(foldReport) && isfield(foldReport, 'refolded_ids')
        refolded = foldReport.refolded_ids;
    end
    n = 0;
    for k = 1:numel(presentationAnchors)
        n = n + any(strcmp(presentationAnchors(k).anchor_id, refolded));
    end
    report.epoch_anchor.anchors_refolded = n;
    report.epoch_anchor.anchors_left_on_session = numel(presentationAnchors) - n;
end

function [convertResult, report] = resolveSoftwareDedup(convertResult)
%RESOLVESOFTWAREDEDUP V_eta second pass: merge the duplicate `software` entities
%   pass 1 could not avoid minting, and retarget the edges of the ones removed.
%
%   The signed model says the entity is "deduplicated by name+version"
%   (DID-schema V_eta_tenet_audit.md:10). A single-document migrator cannot do
%   that half -- it sees one source document and cannot know another already
%   minted the same program -- so every consuming document mints its own and
%   this pass merges them with the whole body set in hand, the same shape as
%   ndi.migrate.internal.pathSPromotion's find-or-create + edge retarget.
%
%   NOTHING IS MINTED here, so unlike the other sub-passes there is no
%   v1_to_v2 re-fold -- and therefore no OPTIONS argument, which is why this
%   signature is one shorter than its siblings'. Every surviving body was
%   already in convertResult and already validated; the bodies whose edges were
%   retargeted are simply rewrapped, exactly as resolvePathS rewraps its own
%   retargeted survivors.
%
%   REPORT is [] when the pass did not run (no documents), and otherwise
%   carries its denominators first -- documents_inspected and edges_examined --
%   so a zero merge count is distinguishable from a pass that read nothing.
%   See ndi.migrate.internal.softwareDedup for the merge key, the pinning rule
%   that protects id-preserved entities, and the cross-session merge it
%   MEASURES but deliberately does not perform.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, report] = ndi.migrate.internal.softwareDedup(structs);
    if ~report.changed
        return;
    end
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = keptDocs;
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, report, presentationAnchors] = resolveStimulusPresentations(convertResult, bodies, options, resolver, ndiDir)
%RESOLVESTIMULUSPRESENTATIONS V_eta second pass: DECOMPOSE each legacy
%   stimulus_presentation into the did-schema #88 stimulus shape -- one
%   standalone `method` document per distinct stimulus (a recipe:
%   {term, parameters}) plus ONE `manipulation` (value kind `item`) whose `item` value is the
%   playlist into them (V_eta_method_plan.md, TEAM-SIGN-OFF [method]
%   2026-10-21; `item` replaces `timed_sequence`, V_eta_study_plan.md).
%
%   The pass-1 converter passes stimulus_presentation through (the animal is
%   only knowable from the whole body set); here it is decomposed. The
%   manipulation PRESERVES the presentation's id, so every inbound reference
%   resolves to it. A presentation the guard refuses is left as v1 with its
%   reason; one with no resolvable animal becomes a standalone item.
%
%   SEVERAL ANIMALS (Jess Haley, 2026-10-21, stimulus plan decision 2): a
%   presentation whose response or epoch route resolves to several animals
%   becomes ONE manipulation of its session's COHORT with `distributive`
%   true. The cohort is minted here once per session -- a `group` entity
%   whose members (`member_of`) are the animals recorded in that session plus
%   any the presentations resolved to -- and reused by every presentation in
%   the session (ndi.migrate.internal.sessionCohort). Stimulator links that
%   lead to different animals are refused (decision 4).
%
%   NO SUBJECT (Jess Haley, 2026-10-21, "a"): a presentation with no
%   response, no element in its session-epoch and no animal behind its
%   stimulator becomes a standalone `item` (id preserved, no manipulation,
%   no subject claim) instead of staying v1. Counted as `standalone_items`.
%
%   TIME. Each manipulation is anchored "during the session" by
%   did2.convert.mintSessionDuring (the lightsheet decision, Jess 2026-10-14,
%   option A).
%
%   TRIAL TIMES (Decided by Jess Haley, 2026-10-22 [presentation times from
%   the file]). Each presentation's onsets and offsets are read from its v1
%   presentation_time.bin when the bytes are on this computer
%   (ndi.migrate.internal.v1AttachedFile: <NDIDIR>/files/<uid>, else the
%   recorded location), else from the deprecated inline block, else none; the
%   file stays attached to the V2 document. REPORT.timing counts each source
%   against the presentations folded.
%
%   CONTROL (Jess Haley, 2026-10-22, [control as covariate]): each v1
%   control_stimulus_ids is handed to its presentation's fold and becomes the
%   `control condition` covariate of the item value. [control pairing is a
%   calculation] (Jess Haley, 2026-10-26) amends it: the record itself becomes
%   a `calculation` (the per-trial pairing, id preserved, so inbound input_id
%   edges keep resolving) when the fold can place all of it, and otherwise
%   stays as it is and is carried as v1 (stimulusPresentationToItem, CONTROL
%   PAIRING). The report counts each, against control_records_read.
%   [second pass reads control stimuli from v1] (Jess Haley, 2026-10-27): the
%   records are read from the ORIGINAL v1 bodies
%   (ndi.migrate.internal.controlRecordsByPresentation; REPORT.control_v1),
%   not from pass 1's output, so DID-matlab can move the class to its raw-v1
%   path.
%
%   EPOCH ANCHOR. Decided by Jess Haley, 2026-10-27 [presentation anchored
%   to its epoch] (option a, no new field): the manipulation's time reference
%   is anchored to the entity of the epoch the presentation was in. The epoch
%   entities are minted after this pass (did2.convert.epochMint), so each
%   manipulation keeps its "during the session" anchor here and
%   PRESENTATIONANCHORS names it with the presentation's (session, epoch
%   string, clock) (ndi.migrate.internal.presentationEpochAnchors);
%   resolveEpochAnchorFold re-points it at the epoch, as it does a bath's.
%   REPORT.epoch_anchor counts them; one the fold refuses stays on its
%   session and is counted as anchors_left_on_session.
%
%   EPOCH-LESS PRESENTATIONS CARRY. Decided by Jess Haley, 2026-10-27
%   [epoch-less presentations carry]: a presentation whose manipulation the
%   epoch anchor fold would refuse -- no epoch is minted for its (session,
%   epoch string), or its stimulator's clock for the epoch is no_time,
%   inherited or unknown -- is carried whole as v1 with its register row,
%   not written anchored to the session. This pass runs before epochMint, so
%   it decides from ndi.migrate.internal.expectedEpochPairs (epochMint's own
%   rules over the batch less the presentations); ndi.migrate.local checks
%   the fold afterwards and reports a presentation it still refused as a
%   defect (secondPassErrors). REPORT.epoch_carried counts the carries by
%   reason. A presentation that names no epoch at all keeps its session
%   anchor (counted in REPORT.epoch_anchor.no_epoch_string).
%
%   `visual_grating`, `visual_grating_manipulation`, `timed_sequence` and
%   `timed_sequence_manipulation` are gone from #88; nothing here emits them.
    report = newStimulusSequenceReport();
    presentationAnchors = struct('anchor_id', {}, 'session_id', {}, ...
        'epoch_string', {}, 'epoch_clock', {});
    manipEpochs = struct('session_id', {}, 'epoch_string', {}, 'epoch_clock', {});
    % [epoch-less presentations carry]: the pairs epochMint will mint, from
    % the batch without the presentations this pass consumes
    batchStructs = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        % the presentations, and the ingested stimulus files that become
        % their bodies, are consumed before epochMint reads the batch
        if any(strcmp(d.className(), {'stimulus_presentation', ...
                'daqmetadatareader_epochdata_ingested'}))
            continue;
        end
        batchStructs{end+1} = d.toStruct(); %#ok<AGROW>
    end
    [expectedPairs, report.epoch_prediction] = ...
        ndi.migrate.internal.expectedEpochPairs(batchStructs);
    clear batchStructs;
    if nargin < 5
        ndiDir = '';
    end
    if nargin < 4 || isempty(resolver)
        % the caller's resolver (built from the same BODIES) when it has one
        resolver = ndi.migrate.internal.bodyResolver(bodies);
    end
    bodies = decodeBodies(bodies);
    report.bodies_read = numel(bodies);

    % THE HARTLEY HALF, BUILT ONCE FOR THE WHOLE SESSION (the basis is a
    % property of the session, shared by every presentation that plays it).
    [hartleyMethods, hartleyByPresentation, report.hartley] = ...
        ndi.migrate.internal.hartleyBasisGratings(bodies);

    % The session cohorts, minted lazily: one id per session, its members
    % accumulated over every distributive presentation in it.
    cohortIds = containers.Map('KeyType', 'char', 'ValueType', 'char');
    cohortMembers = containers.Map('KeyType', 'char', 'ValueType', 'any');
    cohortStamp = containers.Map('KeyType', 'char', 'ValueType', 'char');
    cohortIdFor = @(sid) cohortIdOf(cohortIds, sid);

    usedShared = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    % THE CONTROL RECORDS, by presentation. Decided by Jess Haley, 2026-10-22
    % [control as covariate] (did-schema V_eta_stimulus_response_model_plan.md):
    % a v1 control_stimulus_ids becomes the `control condition` covariate of
    % its presentation's item value and NO V2 document of its own; responses
    % then point at the presentation only (its id is stripped from their
    % input_id below). See ndi.migrate.internal.stimulusPresentationToItem.
    %
    % READ FROM v1. Decided by Jess Haley, 2026-10-27 [second pass reads
    % control stimuli from v1]: the records are the ORIGINAL v1 documents
    % (BODIES), not pass 1's output, so DID-matlab can move the class to its
    % raw-v1 path. Pass 1's output is consulted only for which ids it handed
    % on (a record it quarantined is not folded) and, below, to drop the
    % handed-on copy of each record converted (same id).
    handedOnIds = cell(1, numel(convertResult.migrated));
    for k = 1:numel(convertResult.migrated)
        handedOnIds{k} = char(convertResult.migrated{k}.get('base.id'));
    end
    [controlsByPresentation, report.control_v1] = ...
        ndi.migrate.internal.controlRecordsByPresentation(bodies, handedOnIds);
    report.control_records_read = report.control_v1.control_records_read;
    controlFolded = {};
    controlConverted = {};
    calcs = {};
    presentationKeys = struct('session_id', {}, 'epoch_id', {}, 'id', {});
    minted = {};
    manips = {};
    consumed = {};
    for k = 1:numel(bodies)
        b = bodies{k};
        if ~isPresentationBody(b)
            continue;
        end
        report.presentations_read = report.presentations_read + 1;
        presId = bodyBaseId(b);
        sequence = [];
        if ~isempty(presId) && isKey(hartleyByPresentation, presId)
            sequence = hartleyByPresentation(presId);
        end
        controls = {};
        if ~isempty(presId) && isKey(controlsByPresentation, presId)
            controls = controlsByPresentation(presId);
        end
        ptFile = '';
        ptStatus = '';
        if ~isempty(ndiDir)
            [ptFile, ptStatus] = ndi.migrate.internal.v1AttachedFile(b, ...
                'presentation_time.bin', ndiDir);
        end
        [manip, methods, rep, software, controlCalcs] = ...
            ndi.migrate.internal.stimulusPresentationToItem( ...
            b, resolver, sequence, 'CohortIdFor', cohortIdFor, ...
            'ControlRecords', controls, 'PresentationTimeFile', ptFile, ...
            'PresentationTimeFileStatus', ptStatus);
        epochClock = '';
        if ~isempty(manip) && ~rep.standalone && ~isempty(rep.epoch_id)
            % [epoch-less presentations carry] (Jess Haley, 2026-10-27): the
            % clock is the stimulator's for that epoch, read as the bath
            % assembler reads it; a manipulation the epoch anchor fold would
            % refuse is not written, and the presentation is carried as v1
            epochClock = resolver.epochClockOfElement( ...
                ndi.migrate.internal.etaShape.edge(b, 'stimulus_element_id'), ...
                char(rep.epoch_id));
            why = epochCarryReason(expectedPairs, char(ndi.v2.sessionIdOf(b)), ...
                char(rep.epoch_id), char(epochClock));
            if ~isempty(why)
                report.epoch_carried.(why) = report.epoch_carried.(why) + 1;
                report.epoch_carried.total = report.epoch_carried.total + 1;
                manip = [];
                % carry-register: carry-109
                rep.reason = ['[carry-109] its epoch cannot anchor the ' ...
                    'manipulation (' strrep(why, '_', ' ') '): epoch ''' ...
                    char(rep.epoch_id) ''', clock ''' char(epochClock) ''''];
            end
        end
        report = tallyStimulusKinds(report, rep, ~isempty(manip));
        if ~isempty(manip)
            report.timing = tallyTiming(report.timing, rep);
        end
        if ~isempty(manip) && ~isempty(controls)
            [report, controlFolded] = tallyControl(report, rep, controls, controlFolded);
        end
        if ~isempty(manip)
            % [flashed bar], [shape movie note], [Hartley without enumeration]
            report.flashed_bar_methods = report.flashed_bar_methods + rep.flashed_bars;
            report.uniform_field_methods_kept = ...
                report.uniform_field_methods_kept + rep.uniform_fields_kept;
            report.shape_movie_notes = report.shape_movie_notes + ...
                (rep.shape_movie_note && ~rep.standalone);
            report.hartley_without_enumeration = ...
                report.hartley_without_enumeration + rep.hartley_without_enumeration;
            report.notes_not_written_standalone = ...
                report.notes_not_written_standalone + rep.notes_not_written_standalone;
            % [presentation app is software] and [control pairing is a
            % calculation] (Jess Haley, 2026-10-26): software entities
            % (merged by resolveSoftwareDedup, which runs after this pass),
            % and one calculation per control record placed whole
            minted = [minted, software]; %#ok<AGROW>
            calcs = [calcs, controlCalcs]; %#ok<AGROW>
            controlConverted = [controlConverted, rep.control_converted_ids]; %#ok<AGROW>
            report.software_minted = report.software_minted + rep.software_minted;
            report.software_referenced = report.software_referenced + rep.software_referenced;
            report.software_unreferenced = report.software_unreferenced + ...
                rep.software_unreferenced;
            report.run_environment_written = report.run_environment_written + ...
                rep.run_environment_written;
            report.run_environment_unplaced = report.run_environment_unplaced + ...
                ~isempty(rep.run_environment_unplaced);
            report.control_records_converted = report.control_records_converted + ...
                rep.control_calculations;
            for c = 1:numel(rep.control_carried)
                % [carry register] (Jess Haley, 2026-10-26): every control
                % record carried, with the row its reason cites (uncapped)
                report.carry_rows(end+1) = struct( ...
                    'id', char(rep.control_carried{c}.id), ...
                    'row', ndi.migrate.internal.carryRowOf(rep.control_carried{c}.reason));
                if numel(report.control_carried) < 20
                    report.control_carried{end+1} = rep.control_carried{c};
                end
            end
        end
        if isfield(rep, 'several_animals') && rep.several_animals > 1
            report.several_animal_presentations = ...
                report.several_animal_presentations + 1;
        end
        if isempty(manip)
            report.presentations_refused = report.presentations_refused + 1;
            % carry-register: carry-080 (counts the unplaced refusals)
            if isfield(rep, 'unplaced_fields') && ~isempty(rep.unplaced_fields) ...
                    && strcmp(ndi.migrate.internal.carryRowOf(rep.reason), 'carry-080')
                % [generic stage is lossless] (Jess Haley, 2026-10-25): left
                % as it is, carried as v1 by the last step
                report.presentations_refused_unplaced = ...
                    report.presentations_refused_unplaced + 1;
            end
            report.refusals{end+1} = struct('id', presId, 'reason', rep.reason);
            % [carry register]: the refused presentation is carried as v1 by
            % the last step; its reason cites its row
            report.carry_rows(end+1) = struct('id', char(presId), ...
                'row', ndi.migrate.internal.carryRowOf(rep.reason));
            if rep.several_animals > 1
                report.several_animal_refused = report.several_animal_refused + 1;
            end
            continue;
        end
        if rep.standalone
            % No subject resolves (Jess Haley, 2026-10-21, "a"): a standalone
            % `item`, no manipulation, so no time-reference marker either.
            report.standalone_items = report.standalone_items + 1;
            report.standalone_ids{end+1} = presId;
            minted{end+1} = manip; %#ok<AGROW>
            for g = 1:numel(methods)
                minted{end+1} = methods{g}; %#ok<AGROW>
            end
            if ~isempty(sequence) && isstruct(sequence) && isfield(sequence, 'item_ids')
                for r = 1:numel(sequence.item_ids)
                    usedShared(char(sequence.item_ids{r})) = true;
                end
            end
            report.methods_minted = report.methods_minted + numel(methods);
            consumed{end+1} = presId; %#ok<AGROW>
            continue;
        end
        switch rep.animal_source
            case 'epoch'
                report.decomposed_via_epoch = report.decomposed_via_epoch + 1;
            case 'stimulator'
                report.decomposed_via_stimulator = ...
                    report.decomposed_via_stimulator + 1;
            otherwise
                report.decomposed_via_response = report.decomposed_via_response + 1;
        end
        if rep.distributive
            sid = ndi.v2.sessionIdOf(b);
            members = {};
            if isKey(cohortMembers, sid)
                members = cohortMembers(sid);
            else
                members = resolver.subjectsRecordedInSession(sid);
                cohortStamp(sid) = char(b.base.datestamp);
            end
            for a = 1:numel(rep.animals)
                if ~any(strcmp(members, rep.animals{a}))
                    members{end+1} = rep.animals{a}; %#ok<AGROW>
                end
            end
            cohortMembers(sid) = members;
            report.distributive_manipulations = report.distributive_manipulations + 1;
        end
        manips{end+1} = manip; %#ok<AGROW>
        presentationKeys(end+1) = struct('session_id', char(ndi.v2.sessionIdOf(b)), ...
            'epoch_id', char(rep.epoch_id), 'id', presId); %#ok<AGROW>
        % [presentation anchored to its epoch]: epochClock is the
        % stimulator's for that epoch, read above
        manipEpochs(end+1) = struct('session_id', char(ndi.v2.sessionIdOf(b)), ...
            'epoch_string', char(rep.epoch_id), 'epoch_clock', char(epochClock)); %#ok<AGROW>
        for g = 1:numel(methods)
            minted{end+1} = methods{g}; %#ok<AGROW>
        end
        if ~isempty(sequence) && isstruct(sequence) && isfield(sequence, 'item_ids')
            for r = 1:numel(sequence.item_ids)
                usedShared(char(sequence.item_ids{r})) = true;
            end
        end
        report.presentations_decomposed = report.presentations_decomposed + 1;
        report.methods_minted = report.methods_minted + numel(methods);
        report.items_declared = report.items_declared + ...
            max(numel(methods), rep.shared_refs);
        consumed{end+1} = presId; %#ok<AGROW>
    end
    % a control record whose presentation was not folded (refused, or not in
    % this set) stays as it is, counted
    % carry-register: carry-064 ([dependents of a carried document carry],
    %   Jess Haley, 2026-10-26: it points at a presentation carried as v1)
    presWithControls = controlsByPresentation.keys();
    for p = 1:numel(presWithControls)
        if any(strcmp(presWithControls{p}, consumed))
            continue;
        end
        held = controlsByPresentation(presWithControls{p});
        for h = 1:numel(held)
            report.carry_rows(end+1) = struct( ...
                'id', char(bodyBaseId(held{h})), ...
                'row', 'carry-064');
        end
    end
    report.control_presentation_not_folded = ...
        report.control_records_read - report.control_records_folded ...
        - report.control_unmappable - report.control_no_position_map ...
        - report.control_conflicting;

    if isempty(consumed)
        report.methods_minted = 0;
        % no presentation was decomposed, so no ingested stimulus file has
        % an owner: report each one left, with its row ([carry register])
        ingested = {};
        for k = 1:numel(convertResult.migrated)
            if strcmp(convertResult.migrated{k}.className(), ...
                    'daqmetadatareader_epochdata_ingested')
                ingested{end+1} = convertResult.migrated{k}.toStruct(); %#ok<AGROW>
            end
        end
        [~, ~, report.ingested_stimulus] = ...
            ndi.migrate.internal.ingestedStimulusBodies(ingested, presentationKeys, bodies);
        report.carry_rows = [report.carry_rows, report.ingested_stimulus.left_rows];
        return;
    end
    for g = 1:numel(hartleyMethods)
        if isKey(usedShared, hartleyMethods{g}.base.id)
            minted{end+1} = hartleyMethods{g}; %#ok<AGROW>
            report.shared_methods_minted = report.shared_methods_minted + 1;
        end
    end
    % the session cohorts, once each
    sids = cohortIds.keys();
    for c = 1:numel(sids)
        members = cohortMembers(sids{c});
        docs = ndi.migrate.internal.sessionCohort(cohortIds(sids{c}), sids{c}, ...
            members, cohortStamp(sids{c}));
        minted = [minted, docs]; %#ok<AGROW>
        report.cohorts_minted = report.cohorts_minted + 1;
        report.cohort_members = report.cohort_members + numel(members);
    end

    % [ingested stimulus file is a body of the presentation] (Jess Haley,
    % 2026-10-26): a v1 daqmetadatareader_epochdata_ingested becomes an
    % opaque_body of its epoch's presentation manipulation (session + epoch
    % id); with no single match it stays v1.
    ingested = {};
    for k = 1:numel(convertResult.migrated)
        if strcmp(convertResult.migrated{k}.className(), ...
                'daqmetadatareader_epochdata_ingested')
            ingested{end+1} = convertResult.migrated{k}.toStruct(); %#ok<AGROW>
        end
    end
    [ingestedBodies, ingestedConsumed, report.ingested_stimulus] = ...
        ndi.migrate.internal.ingestedStimulusBodies(ingested, presentationKeys, bodies);
    report.carry_rows = [report.carry_rows, report.ingested_stimulus.left_rows];
    minted = [minted, ingestedBodies];

    % drop the passthrough stimulus_presentation docs that were assembled away,
    % and collect the session documents the time references anchor to
    kept = {};
    sessionStructs = {};
    sessionClasses = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        cls = d.className();
        if strcmp(cls, 'daqmetadatareader_epochdata_ingested') ...
                && any(strcmp(d.get('base.id'), ingestedConsumed))
            continue;   % now its presentation's opaque_body (same id)
        end
        if strcmp(cls, 'stimulus_presentation') ...
                && any(strcmp(d.get('base.id'), consumed))
            continue;
        end
        if any(strcmp(d.get('base.id'), controlConverted))
            % replaced by its calculation (same id). By id, whatever class
            % pass 1 handed it on as ([second pass reads control stimuli
            % from v1]: the record itself is read from v1).
            continue;
        end
        if any(strcmp(cls, {'session', 'entity'}))
            sessionStructs{end+1} = d.toStruct(); %#ok<AGROW>
            sessionClasses{end+1} = cls; %#ok<AGROW>
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = kept;

    % "during the session" for every manipulation (the marker each carries)
    nS = numel(sessionStructs);
    marked = [manips, calcs];
    batch = [sessionStructs, marked];
    classes = [sessionClasses, repmat({'manipulation'}, 1, numel(manips)), ...
        repmat({'calculation'}, 1, numel(calcs))];
    [batch, refs, anchorReport] = did2.convert.mintSessionDuring(batch, classes, ...
        nS + (1:numel(marked)), struct('SchemaCache', options.SchemaCache));
    report.time_references = anchorReport;
    % [presentation anchored to its epoch]: name each manipulation's session
    % anchor with its epoch, for resolveEpochAnchorFold
    [presentationAnchors, report.epoch_anchor] = ...
        ndi.migrate.internal.presentationEpochAnchors( ...
        batch(nS + (1:numel(manips))), manipEpochs);
    minted = [batch(nS+1:end), refs, minted];

    % fold the minted documents through v1_to_v2: they are tagged
    % schema_version == TargetVersion, so the converter short-circuits them
    % (isAlreadyTarget) to ensureClassBlocks + validate.
    sub = did2.convert.v1_to_v2(minted, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    report.quarantined = numel(sub.quarantine);
    convertResult.summary = recountSummary(convertResult);
end

function t = newTimingCensus()
%NEWTIMINGCENSUS Where each folded presentation's trial times came from
%   ([presentation times from the file]); `presentations_folded` is the
%   denominator, and from_file + inline + frame_times + none equals it.
    t = struct( ...
        'presentations_folded',      0, ...
        'from_file',                 0, ...
        'inline',                    0, ...
        'frame_times',               0, ...
        'none',                      0, ...
        'file_declared',             0, ...
        'file_located',              0, ...
        'file_not_on_this_computer', 0, ...
        'file_unusable',             0, ...
        'file_unusable_reasons',     {{}}, ...
        'files_attached',            0);
end

function t = tallyTiming(t, rep)
    t.presentations_folded = t.presentations_folded + 1;
    switch rep.timing_source
        case 'presentation_time.bin'
            t.from_file = t.from_file + 1;
        case 'inline (deprecated writer form)'
            t.inline = t.inline + 1;
        case 'frameTimes (hartley_calc)'
            t.frame_times = t.frame_times + 1;
        otherwise
            t.none = t.none + 1;
    end
    st = rep.timing_file;
    if ~strcmp(st, 'not declared')
        t.file_declared = t.file_declared + 1;
    end
    if any(strcmp(st, {'read', 'not used: the dimension is frames'})) ...
            || strncmp(st, 'unreadable', 10) || ~isempty(regexp(st, 'entr\(ies\)', 'once')) ...
            || strcmp(st, 'an onset is not a finite number')
        t.file_located = t.file_located + 1;
    end
    if any(strcmp(st, {'not on this computer', 'declared, not located'}))
        t.file_not_on_this_computer = t.file_not_on_this_computer + 1;
    end
    if strncmp(st, 'unreadable', 10) || ~isempty(regexp(st, 'entr\(ies\)', 'once')) ...
            || strcmp(st, 'an onset is not a finite number')
        t.file_unusable = t.file_unusable + 1;
        if numel(t.file_unusable_reasons) < 5
            t.file_unusable_reasons{end+1} = st;
        end
    end
    t.files_attached = t.files_attached + (rep.files_attached > 0);
end

function [report, folded] = tallyControl(report, rep, controls, folded)
%TALLYCONTROL Count one folded presentation's control records ([control as
%   covariate]): folded into its covariate, or left as v1 with the reason.
    if rep.control_records_folded > 0
        report.control_records_folded = report.control_records_folded + ...
            rep.control_records_folded;
        report.presentations_with_control_covariate = ...
            report.presentations_with_control_covariate + 1;
        if rep.control_true == 0
            report.control_covariates_all_false = ...
                report.control_covariates_all_false + 1;
        end
        for c = 1:numel(controls)
            folded{end+1} = char(controls{c}.base.id); %#ok<AGROW>
        end
        return;
    end
    switch rep.control_unfolded_reason
        case 'no position map'
            report.control_no_position_map = report.control_no_position_map + numel(controls);
        case 'conflicting'
            report.control_conflicting = report.control_conflicting + numel(controls);
        otherwise
            report.control_unmappable = report.control_unmappable + numel(controls);
    end
end

function id = cohortIdOf(cohortIds, sessionId)
%COHORTIDOF The session's cohort id, minted the first time it is asked for.
%   containers.Map is a handle, so the caller's map holds every id issued.
    sessionId = char(sessionId);
    if ~isKey(cohortIds, sessionId)
        cohortIds(sessionId) = did.ido.unique_id(); %#ok<NASGU>
    end
    id = cohortIds(sessionId);
end

function [convertResult, rep] = describeEpochSeriesBodies(convertResult, ndiDir, options)
%DESCRIBEEPOCHSERIESBODIES ndi.migrate.internal.epochSeriesBodies over the
%   migrated set. Each group it changed (a body, its owners, and any body it
%   added) is re-validated TOGETHER through did2.convert.v1_to_v2; a group that
%   does not come back clean is REVERTED (left as it was, the added body
%   dropped) and counted.
    docs = convertResult.migrated;
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [structs, rep, added] = ndi.migrate.internal.epochSeriesBodies(structs, ndiDir);
    rep.reverted = 0;
    if isempty(rep.changed_groups)
        return;
    end
    idxById = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for k = 1:numel(structs)
        idxById(char(structs{k}.base.id)) = k;
    end
    addedById = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(added)
        addedById(char(added{k}.base.id)) = added{k};
    end
    appendDocs = {};
    for g = 1:numel(rep.changed_groups)
        ids = rep.changed_groups{g};
        grp = cell(1, numel(ids));
        for j = 1:numel(ids)
            if isKey(idxById, ids{j}); grp{j} = structs{idxById(ids{j})};
            else; grp{j} = addedById(ids{j}); end
        end
        try
            sub = did2.convert.v1_to_v2(grp, ...
                'Validate', options.Validate, 'SchemaCache', options.SchemaCache, ...
                'TargetVersion', options.TargetVersion, 'Verbose', false);
            if isempty(sub.quarantine) && numel(sub.migrated) == numel(ids)
                for j = 1:numel(sub.migrated)
                    sid = char(sub.migrated{j}.get('base.id'));
                    if isKey(idxById, sid)
                        docs{idxById(sid)} = sub.migrated{j};
                    else
                        appendDocs{end+1} = sub.migrated{j}; %#ok<AGROW>
                    end
                end
            else
                rep.reverted = rep.reverted + 1;
            end
        catch
            rep.reverted = rep.reverted + 1;
        end
    end
    convertResult.migrated = [docs, appendDocs];
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, rep] = fillLocatedFileFacts(convertResult, options)
%FILLLOCATEDFILEFACTS ndi.migrate.internal.locatedFileFacts over the migrated
%   set; each changed body is re-validated through did2.convert.v1_to_v2 and
%   REVERTED (left as it was) if it does not come back clean.
    docs = convertResult.migrated;
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [structs, rep] = ndi.migrate.internal.locatedFileFacts(structs);
    rep.reverted = 0;
    for k = 1:numel(docs)
        if ~any(strcmp(char(structs{k}.base.id), rep.changed_ids)); continue; end
        try
            sub = did2.convert.v1_to_v2({structs{k}}, ...
                'Validate', options.Validate, 'SchemaCache', options.SchemaCache, ...
                'TargetVersion', options.TargetVersion, 'Verbose', false);
            if isempty(sub.quarantine) && isscalar(sub.migrated)
                docs{k} = sub.migrated{1};
            else
                rep.reverted = rep.reverted + 1;
            end
        catch
            rep.reverted = rep.reverted + 1;
        end
    end
    convertResult.migrated = docs;
end

function out = decodeBodies(bodies)
% Normalise a body set to a cell of scalar structs: jsondecode any raw JSON
% char body (the first-run reader output); pass decoded structs through
% unchanged. Unparseable entries are dropped (not useful for assembly).
    out = {};
    for k = 1:numel(bodies)
        b = bodies{k};
        if ischar(b) || (isstring(b) && isscalar(b))
            try
                b = jsondecode(char(b));
            catch
                continue;
            end
        end
        if isstruct(b) && isscalar(b)
            out{end+1} = b; %#ok<AGROW>
        end
    end
end

function tf = isPresentationBody(b)
    tf = isstruct(b) && isfield(b, 'document_class') ...
        && isfield(b.document_class, 'class_name') ...
        && strcmp(b.document_class.class_name, 'stimulus_presentation');
end

function r = newStimulusSequenceReport()
%NEWSTIMULUSSEQUENCEREPORT Denominators first and unconditionally, so a pass
%   that did nothing and a pass that saw nothing print differently.
    r = struct( ...
        'bodies_read',                0, ...
        'presentations_read',         0, ...
        'presentations_decomposed',   0, ...
        'presentations_refused',      0, ...
        'presentations_refused_unplaced', 0, ...
        'methods_minted',             0, ...
        'shared_methods_minted',      0, ...
        'items_declared',             0, ...
        'decomposed_via_response',    0, ...
        'decomposed_via_epoch',       0, ...
        'decomposed_via_stimulator',  0, ...
        'several_animal_presentations', 0, ...
        'several_animal_refused',     0, ...
        'distributive_manipulations', 0, ...
        'standalone_items',           0, ...
        'standalone_ids',             {{}}, ...
        'cohorts_minted',             0, ...
        'cohort_members',             0, ...
        'quarantined',                0, ...
        'time_references',            [], ...
        'stimulus_kinds',             [], ...
        'presentations_by_kind',      struct('kinds', {}, 'decomposed', {}, 'refused', {}), ...
        'refusals',                   {{}}, ...
        'flashed_bar_methods',        0, ...
        'uniform_field_methods_kept', 0, ...
        'shape_movie_notes',          0, ...
        'hartley_without_enumeration', 0, ...
        'notes_not_written_standalone', 0, ...
        'epoch_anchor',               [], ...
        'epoch_prediction',           [], ...
        'epoch_carried',              struct('total', 0, ...
            'no_epoch_minted', 0, 'clock_no_time', 0, ...
            'clock_inherited', 0, 'clock_unknown', 0), ...
        'control_v1',                 [], ...
        'control_records_read',       0, ...
        'control_records_folded',     0, ...
        'control_presentation_not_folded', 0, ...
        'control_no_position_map',    0, ...
        'control_unmappable',         0, ...
        'control_conflicting',        0, ...
        'presentations_with_control_covariate', 0, ...
        'control_covariates_all_false', 0, ...
        'control_records_converted',  0, ...
        'control_carried',            {{}}, ...
        'carry_rows',                 struct('id', {}, 'row', {}), ...
        'software_minted',            0, ...
        'software_referenced',        0, ...
        'software_unreferenced',      0, ...
        'run_environment_written',    0, ...
        'run_environment_unplaced',   0, ...
        'timing',                     newTimingCensus(), ...
        'hartley',                    [], ...
        'ingested_stimulus',          []);
end

function why = epochCarryReason(expectedPairs, sessionId, epochString, clock)
%EPOCHCARRYREASON Why the epoch anchor fold would refuse this presentation's
%   manipulation ([epoch-less presentations carry]), '' when it would not.
%   The clock rules are ndi.migrate.internal.epochAnchorFold's clockTerm.
    why = '';
    switch clock
        case {'', 'utc', 'dev_local_time', 'dev_global_time', ...
                'exp_global_time', 'approx_utc', 'approx_dev_global_time', ...
                'approx_exp_global_time'}
        case 'no_time'
            why = 'clock_no_time';
            return;
        case 'inherited'
            why = 'clock_inherited';
            return;
        otherwise
            why = 'clock_unknown';
            return;
    end
    if isempty(sessionId) || ~isKey(expectedPairs, ...
            did2.convert.epochIndex.pairKey(sessionId, epochString))
        why = 'no_epoch_minted';
    end
end

function report = tallyStimulusKinds(report, rep, decomposed)
%TALLYSTIMULUSKINDS Add one presentation's per-kind stimulus counts to the
%   pass report: `stimulus_kinds` sums them over all presentations read, and
%   `presentations_by_kind` counts presentations by the SET of kinds they hold
%   (e.g. 'blank+grating', 'blank+stochasticgridstim'), split decomposed /
%   refused. A presentation whose report carries no `stimulus_kinds` is
%   counted under '(not classified)'.
    kindsKey = '(not classified)';
    if isfield(rep, 'stimulus_kinds') && isstruct(rep.stimulus_kinds)
        k = rep.stimulus_kinds;
        if isempty(report.stimulus_kinds)
            report.stimulus_kinds = k;
        else
            fns = fieldnames(k);
            for f = 1:numel(fns)
                report.stimulus_kinds.(fns{f}) = ...
                    report.stimulus_kinds.(fns{f}) + k.(fns{f});
            end
        end
        fns = fieldnames(k);
        held = fns(cellfun(@(n) k.(n) > 0, fns));
        if isempty(held)
            kindsKey = '(no stimuli)';
        else
            kindsKey = strjoin(sort(held(:)'), '+');
        end
    end
    rows = report.presentations_by_kind;
    hit = 0;
    for r = 1:numel(rows)
        if strcmp(rows(r).kinds, kindsKey); hit = r; break; end
    end
    if hit == 0
        rows(end+1) = struct('kinds', kindsKey, 'decomposed', 0, 'refused', 0);
        hit = numel(rows);
    end
    if decomposed
        rows(hit).decomposed = rows(hit).decomposed + 1;
    else
        rows(hit).refused = rows(hit).refused + 1;
    end
    report.presentations_by_kind = rows;
end

function id = bodyBaseId(b)
    id = '';
    if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
        id = b.base.id;
    end
end

% ---- v1 source detection ---------------------------------------------------

function [kind, srcPath] = detectV1Source(ndiDir)
    kind = 'none';
    srcPath = '';

    didSqlite = fullfile(ndiDir, 'did-sqlite.sqlite');
    if isfile(didSqlite)
        kind = 'sqlite';
        srcPath = didSqlite;
        return;
    end

    sqliteListing = dir(fullfile(ndiDir, '*.sqlite'));
    sqliteListing = sqliteListing(~[sqliteListing.isdir]);
    % a migration OUTPUT is never a v1 source
    sqliteListing = sqliteListing(~ismember(lower({sqliteListing.name}), ...
        {'v_eta.sqlite'}));
    if ~isempty(sqliteListing)
        kind = 'sqlite';
        srcPath = fullfile(ndiDir, sqliteListing(1).name);
        return;
    end

    dumbListing = dir(fullfile(ndiDir, 'Object_id_*_v*.json'));
    if ~isempty(dumbListing)
        kind = 'dumbjsondb';
        srcPath = ndiDir;
        return;
    end
    nested = {'.dumbjsondb', 'dumbjsondb'};
    for k = 1:numel(nested)
        cand = fullfile(ndiDir, nested{k});
        if isfolder(cand) && ~isempty(dir(fullfile(cand, 'Object_id_*_v*.json')))
            kind = 'dumbjsondb';
            srcPath = ndiDir;
            return;
        end
    end
end

% ---- read the target database's bodies (idempotent re-run path) ------------

function [bodies, srcInfo] = readBodiesFromTarget(dstPath)
    srcInfo = struct('kind', 'none', 'path', dstPath);
    db = did2.database.sqlitedb(dstPath);
    dbCleanup = onCleanup(@() db.close());
    ids = db.allIds();
    bodies = cell(numel(ids), 1);
    for k = 1:numel(ids)
        doc = db.get(ids{k});
        bodies{k} = doc.toStruct();
    end
end

% ---- backup ----------------------------------------------------------------

function copyBackup(ndiDir, backupDir)
    mkdir(backupDir);
    [ok, msg, msgid] = copyfile(fullfile(ndiDir, '*'), backupDir, 'f');
    if ~ok
        error('NDI:migrate:backupFailed', ...
            'Failed to copy "%s" to "%s": %s (%s)', ...
            ndiDir, backupDir, msg, msgid);
    end
end

% ---- lock helpers (atomic create via java.io.File) -------------------------

function handle = acquireLock(lockFile)
    f = java.io.File(lockFile);
    try
        created = f.createNewFile();
    catch err
        error('NDI:migrate:locked', ...
            'Failed to create lock "%s": %s', lockFile, err.message);
    end
    if ~created
        error('NDI:migrate:locked', ...
            ['Migration lock "%s" already exists. Another migration ' ...
             'may be running; delete the file if you are sure it is ' ...
             'stale.'], lockFile);
    end
    handle = char(lockFile);
end

function releaseLock(lockFile)
    try
        if isfile(lockFile)
            delete(lockFile);
        end
    catch
        % Best-effort release; never raise from cleanup.
    end
end

% ---- quarantine sidecar ----------------------------------------------------

function writeQuarantineFile(quarantineFile, quarantineStructArray)
    text = jsonencode(quarantineStructArray);
    fid = fopen(quarantineFile, 'w');
    if fid < 0
        error('NDI:migrate:quarantineWriteFailed', ...
            'Failed to open quarantine file "%s" for writing.', ...
            quarantineFile);
    end
    closer = onCleanup(@() fclose(fid));
    fwrite(fid, text, 'char');
end

% ---- summary printer -------------------------------------------------------

function printSummary(result)
    fprintf('ndi.migrate.local summary for "%s":\n', result.path);
    if result.alreadyMigrated
        [~, dstName, dstExt] = fileparts(result.destination);
        fprintf('  already-migrated fast pass (%s present).\n', [dstName dstExt]);
    else
        fprintf('  source:           %s (%s)\n', ...
            result.source.kind, result.source.path);
    end
    fprintf('  destination:      %s\n', result.destination);
    fprintf('  dry-run:          %d\n', result.dryRun);
    fprintf('  wrote destination:%d\n', result.wroteDestination);
    fprintf('  backup created:   %d (path: %s)\n', ...
        result.backup.created, result.backup.path);
    fprintf('  total docs:       %d\n', result.summary.total);
    fprintf('  migrated:         %d\n', result.summary.migrated_count);
    fprintf('  quarantined:      %d\n', result.summary.quarantine_count);
    if isfield(result.summary, 'carried_as_v1')
        fprintf('  carried as v1:    %d (stamped did_v1)\n', result.summary.carried_as_v1);
    end
    fprintf('  orphan refs:      %d (of %d edges)\n', ...
        result.references.orphan_count, result.references.edges_examined);
    % The ensemble verify-before-delete gate. It is a DATA-LOSS gate
    % (V_eta_ensemble_plan.md deferred task 4) and until this line it was
    % computed on every run and rendered by nothing -- stored at
    % result.secondPass.ensembleMembership and read by no printer, no
    % workflow and no digest in any of the three repositories.
    %
    % (This sentence used to continue "The other 14 second-pass reports are in
    % the same position". THE NUMBER IS DELETED RATHER THAN CORRECTED: it is a
    % hand-kept count sitting beside the thing it counts, it drifts one
    % further every time a sub-pass is added, and it drifts in the reassuring
    % direction -- fewer unrendered reports than there really are. The
    % `result.secondPass` struct built above is its own denominator, and the
    % standing fact is unchanged: MOST second-pass reports are still stored
    % and rendered by nothing. Two are rendered because they are sub-passes
    % that can LOSE A DOCUMENT: this one, the ensemble verify-before-delete
    % gate; and printSubjectStrainSummary below, which removes the moved
    % genetic-strain-type and duplicate species assertions.
    % printOntologyRowSummary below that renders the table-row count: since
    % [table rows carried as v1] (Jess Haley, 2026-10-30) that step drops
    % nothing, and it is printed so the carried rows have a denominator.)
    ensembleReport = [];
    if isfield(result, 'secondPass') && isstruct(result.secondPass) ...
            && isfield(result.secondPass, 'ensembleMembership')
        ensembleReport = result.secondPass.ensembleMembership;
    end
    gateLines = ndi.migrate.internal.ensembleGateReport(ensembleReport);
    for k = 1:numel(gateLines)
        fprintf('%s\n', gateLines{k});
    end
    printSubjectStrainSummary(result);
    printOntologyRowSummary(result);
end

function printSubjectStrainSummary(result)
%PRINTSUBJECTSTRAINSUMMARY Render the #78 subject-strain report.
%
%   RENDERED, not merely stored, because this pass REMOVES DOCUMENTS -- the
%   genetic-strain-type assertion and the duplicate species assertion. A pass
%   that deletes and is measured by nothing is the defect this whole exercise
%   is about (did2.convert.resolveSessionAnchors ran over 127,719 documents
%   called from nothing for a day, and nothing was missing from any log
%   because a pass that produces no output produces no missing output). The
%   note above this function says the other 13 reports are still in that
%   position; this one is claimed here for the same reason the ensemble gate
%   is -- it is the only other sub-pass that can lose a document.
    r = [];
    if isfield(result, 'secondPass') && isstruct(result.secondPass) ...
            && isfield(result.secondPass, 'subjectStrainAssembly')
        r = result.secondPass.subjectStrainAssembly;
    end
    fprintf('  subject-strain assembly (#78):\n');
    if isempty(r) || ~isstruct(r)
        % NOT "nothing to do". Three different things produce this and none of
        % them is a clean run: a non-V_eta target, an empty document set, or
        % the pass threw and its warning is above.
        fprintf(['    DID NOT RUN -- non-V_eta target, no documents, or the ' ...
                 'pass threw (see the warning above). This is NOT "nothing ' ...
                 'to assemble".\n']);
        return;
    end
    fprintf(['    DENOMINATOR: %d did_v1 body(ies) read, %d migrated ' ...
             'document(s) indexed (%d term_assertion, %d reference edge).\n'], ...
        r.v1_bodies_inspected, r.documents_inspected, ...
        r.term_assertions_indexed, r.reference_edges_indexed);
    fprintf(['    openMINDS: %d body(ies), %d openminds_subject, %d of them ' ...
             'Strain (%d Strain under another openminds class, untouched).\n'], ...
        r.v1_openminds_bodies, r.v1_openminds_subject_bodies, ...
        r.strain_docs_seen, r.strain_under_other_openminds_class);
    if r.strain_docs_seen == 0
        % The two zeroes that must never print the same. A batch with no
        % openminds_subject bodies at all and a batch full of them that
        % happens to carry no Strain are different facts.
        fprintf(['    NO STRAIN DOCUMENT IN REACH -- nothing to assemble. ' ...
                 'Read the openMINDS line above before reading this as ' ...
                 'clean: 0 of 0 and 0 of many are different results.\n']);
        return;
    end
    fprintf(['    strains: %d candidate(s) -> %d distinct (%d document(s) ' ...
             'collapsed), %d incomplete, %d not in the migrated set, ' ...
             '%d not a term_assertion.\n'], ...
        r.strains_candidate, r.distinct_strains, r.strain_docs_collapsed, ...
        r.strains_incomplete, r.strain_docs_not_in_migrated_set, ...
        r.strain_docs_not_a_term_assertion);
    fprintf(['    pedigree: %d reference(s) -> %d derived_from relation(s), ' ...
             '%d unresolved, %d cycle(s), ' ...
             '%d not corroborated by an openminds_# edge.\n'], ...
        r.background_refs_seen, r.background_edges, r.background_unresolved, ...
        r.pedigree_cycles, r.background_refs_not_in_openminds_edges);
    fprintf(['    instance_of: %d subject(s) made an instance of their strain ' ...
             '(their strain assertion replaced), %d strain assertion(s) with ' ...
             'no subject; %d assertion(s) minted about the strains.\n'], ...
        r.instance_of_minted, r.strain_assertions_without_subject, ...
        r.strain_assertions_minted);
    fprintf(['    moved onto the strain: %d of %d genetic-strain-type ' ...
             'assertion(s) removed; KEPT -- %d value not on the strain, ' ...
             '%d shared with an unassembled strain, %d wrong/absent subject, ' ...
             '%d of an ancestor strain, %d pinned by an inbound edge, ' ...
             '%d not a term assertion.\n'], ...
        r.gst_assertions_removed, r.gst_fragments_seen, ...
        r.gst_kept_value_not_on_strain, r.gst_kept_shared_with_unassembled, ...
        r.gst_kept_wrong_subject, r.gst_kept_not_the_subjects_strain, ...
        r.gst_kept_pinned, r.gst_kept_not_a_term_assertion);
    fprintf(['    species: %d fragment(s), %d duplicate group(s) in scope, ' ...
             '%d assertion(s) removed, %d pinned and kept.\n'], ...
        r.species_fragments_seen, r.species_duplicate_groups, ...
        r.species_assertions_removed, r.species_kept_pinned);
    fprintf(['    ancestor strain assertions on their subject %d: removed %d ' ...
             '(reachable through derived_from; Jess Haley 2026-10-21), kept ' ...
             'unreachable %d, kept pinned %d\n'], ...
        r.background_strain_assertions_on_subject, ...
        r.background_strain_assertions_removed, ...
        r.background_kept_unreachable, r.background_kept_pinned);
    fprintf(['    scope %s%s: %d entit(ies) a session-scoped key would leave ' ...
             'beyond a dataset-scoped one, across %d cross-session group(s); ' ...
             'merged this run %d (Jess Haley 2026-10-21: shared entities at ' ...
             'the dataset level)\n'], r.scope, ...
        ifDataset(r.dataset_id), r.cross_session_collapsible, ...
        r.cross_session_groups, r.cross_session_merged);
    fprintf(['    MEASURED, NOT ACTED ON: %d duplicate species group(s) this family ' ...
             'did not cause.\n'], r.duplicate_species_groups_out_of_scope);
end

function s = ifDataset(id)
s = '';
if ~isempty(id)
    s = [' ' id];
end
end

function printOntologyRowSummary(result)
%PRINTONTOLOGYROWSUMMARY Render the ontology table-row count.
%
%   [table rows carried as v1] (Jess Haley, 2026-10-30): every v1
%   `ontologyTableRow` is carried whole as v1 by pass 1; the second pass
%   resolves no subject and re-folds nothing. This prints the denominator and
%   how many rows the migrated set still holds as a table row.
    r = [];
    if isfield(result, 'secondPass') && isstruct(result.secondPass) ...
            && isfield(result.secondPass, 'ontologyRowsCarried')
        r = result.secondPass.ontologyRowsCarried;
    end
    fprintf('  ontology table rows ([table rows carried as v1]):\n');
    if isempty(r) || ~isstruct(r)
        % NOT "no rows": the count did not run (no V_eta second pass, or it
        % threw and its warning is above).
        fprintf(['    NOT MEASURED -- the count did not run (see any warning ' ...
                 'above). This is NOT "no rows".\n']);
        return;
    end
    fprintf(['    DENOMINATOR: %d did_v1 body(ies) read, %d migrated ' ...
             'document(s) read.\n'], ...
        reportNum(r, 'v1_bodies_inspected'), ...
        reportNum(r, 'documents_inspected'));
    fprintf(['    rows: %d did_v1 ontologyTableRow body(ies); %d still a ' ...
             'table row (carried); %d not found as a table row.\n'], ...
        reportNum(r, 'v1_ontology_rows'), ...
        reportNum(r, 'rows_carried'), ...
        reportNum(r, 'rows_not_carried'));
    if reportNum(r, 'rows_not_carried') > 0
        fprintf(['    *** %d row(s) are not carried as a table row; ' ...
                 '[table rows carried as v1] expects every row carried.\n'], ...
            reportNum(r, 'rows_not_carried'));
    end
end

function v = reportNum(r, name)
%REPORTNUM The named counter as a number, or -1 when the field is absent.
%
%   -1 rather than 0 ON PURPOSE. A report struct that predates a counter
%   would otherwise print a clean zero for a thing that was never measured,
%   which is the exact substitution this whole summary exists to prevent. A
%   -1 in the log is unmistakably "this build did not have that counter".
v = -1;
if isstruct(r) && isfield(r, name) && ~isempty(r.(name)) ...
        && (isnumeric(r.(name)) || islogical(r.(name)))
    v = double(r.(name));
end
end

function v = charOrEmpty(s, name)
%CHAROREMPTY The named field of S as char, or '' when absent or empty.
v = '';
if isstruct(s) && isscalar(s) && isfield(s, name) && ~isempty(s.(name))
    v = char(s.(name));
end
end

function docId = lookupEpochDoc(epochByPair, epochStr, sessionId)
%LOOKUPEPOCHDOC The `epoch` document id for (SESSIONID, EPOCHSTR), or ''.
%   THE KEY IS THE PAIR, NEVER THE STRING. epochMint measured
%   `epochid.epochid` reused across sessions in 142 of corpus B's 149 distinct
%   ids, so a string-only lookup would hand back an epoch from another
%   session's recording. Half a key is not a key: a missing session id
%   resolves to nothing rather than to a guess.
docId = '';
epochStr  = char(epochStr);
sessionId = char(sessionId);
if isempty(epochStr) || isempty(sessionId)
    return;
end
key = [sessionId '|' epochStr];
if isKey(epochByPair, key)
    docId = epochByPair(key);
end
end

function assertUniqueIds(docs)
%ASSERTUNIQUEIDS Error, naming them, when two migrated documents share an id.
    ids = cellfun(@(d) char(d.get('base.id')), docs, 'UniformOutput', false);
    [u, ~, j] = unique(ids);
    counts = accumarray(j(:), 1);
    dup = u(counts > 1);
    if isempty(dup)
        return;
    end
    lines = {};
    for q = 1:min(numel(dup), 10)
        hit = find(strcmp(ids, dup{q}));
        cls = cellfun(@(k) char(docs{k}.className()), num2cell(hit), ...
            'UniformOutput', false);
        lines{end+1} = sprintf('  %s x%d: %s', dup{q}, numel(hit), ...
            strjoin(cls, ', ')); %#ok<AGROW>
    end
    error('NDI:migrate:duplicateIds', ...
        ['%d id(s) are carried by more than one migrated document (of %d); ' ...
         'nothing was written. First %d (id xN: classes):\n%s'], ...
        numel(dup), numel(docs), numel(lines), strjoin(lines, newline));
end

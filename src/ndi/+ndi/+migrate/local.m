function result = local(path, options)
%LOCAL Migrate a local NDI dataset/session to V_delta on disk.
%
%   RESULT = ndi.migrate.local(PATH) migrates the on-disk did_v1
%   database under PATH/.ndi to the V_delta wire format by reading
%   every document body via the did2 v1 readers, running
%   did2.convert.v1_to_v2 per body, and writing the surviving docs
%   into PATH/.ndi/V_delta.sqlite via did2.database.sqlitedb.
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
%                      would change without writing the V_delta
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
%                      migrated document against its V_delta schema
%                      during conversion and again on insert into
%                      the V_delta database. Tests with no schema
%                      cache available may pass false; production
%                      callers should leave this true.
%     SchemaCache      ([] or a did2.schema.cache handle, default
%                      []) - override the shared schema cache. Used
%                      by tests; production callers should rely on
%                      ndi.schemas.init having set the active cache.
%     TargetVersion    (1,:) char, default 'V_delta') - migration
%                      target wire format. 'V_delta' preserves the
%                      historical class-preserving behaviour and
%                      writes V_delta.sqlite. 'V_epsilon' (Brainstorm E)
%                      'V_zeta' (Brainstorm I) and 'V_eta' (Brainstorm
%                      J) route split-eligible classes through the
%                      matching migrators (1 -> N) and run a second pass
%                      using the open body set. For V_epsilon/V_zeta the
%                      pass resolves session-context-dependent deferrals
%                      (e.g. stimulus_bath -> bath); for V_eta it promotes
%                      attributed anatomical loci to Path-S part-subjects
%                      (a part-`subject` + `term_assertion` + `part_of`
%                      relation, retargeting the co-anchored manipulation).
%                      Writes <TargetVersion>.sqlite. V_eta (Brainstorm J)
%                      is the current direction; V_zeta/V_epsilon are
%                      retained as archived references.
%
%   RESULT is a struct with fields:
%       path         - the input PATH (char).
%       source       - struct describing the v1 source that was
%                      read: `kind` ('sqlite', 'dumbjsondb', or
%                      'none' when the function consumed the
%                      existing V_delta file instead) and `path`
%                      (char).
%       destination  - absolute path of the V_delta sqlite file
%                      this run wrote (or would write, when DryRun
%                      is true).
%       alreadyMigrated - logical; true when a V_delta sqlite file
%                      already existed and the run did a fast
%                      idempotent pass (read V_delta, re-validate).
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
%
%   Idempotency:
%       Re-running on a dataset that already has a V_delta.sqlite
%       under .ndi is a fast no-op modulo validation: the function
%       loads every document from the existing V_delta file,
%       re-runs did2.convert.v1_to_v2 (which short-circuits already-
%       V_delta bodies), and re-validates references. Nothing is
%       written when DryRun is true OR the V_delta file is
%       byte-equivalent to what would have been produced. To force
%       a full re-migration, delete PATH/.ndi/V_delta.sqlite first.
%
%   Errors:
%       NDI:migrate:badPath         - PATH is not a directory.
%       NDI:migrate:noNdiDir        - PATH/.ndi is missing; not
%                                     an NDI session/dataset root.
%       NDI:migrate:noV1Source      - .ndi exists but contains no
%                                     recognised v1 store and no
%                                     V_delta file.
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
        options.TargetVersion (1,:) char = 'V_delta'
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

    lockFile = fullfile(ndiDir, '.migrate.lock');
    lockHandle = acquireLock(lockFile);
    lockCleanup = onCleanup(@() releaseLock(lockHandle));

    dstPath = fullfile(ndiDir, [options.TargetVersion '.sqlite']);
    quarantineFile = fullfile(ndiDir, 'migrate_quarantine.json');
    backupDir = fullfile(path, '.v1-backup');

    alreadyMigrated = isfile(dstPath);
    backupCreated = false;
    if alreadyMigrated
        [bodies, srcInfo] = readBodiesFromVDelta(dstPath);
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
                 'Object_id_*_v*.json) and no V_delta.sqlite found ' ...
                 'under "%s".'], ndiDir);
        end
        if options.Backup && ~options.DryRun && ~isfolder(backupDir)
            copyBackup(ndiDir, backupDir);
            backupCreated = true;
        end
    end

    % Build the converter args. Only forward TargetVersion when it is NOT
    % the default 'V_delta': the default path must stay call-compatible with
    % the stable released did-matlab (whose v1_to_v2 predates the
    % TargetVersion option). A 'V_epsilon' run requires the newer did-matlab
    % anyway, so adding the name-value there is safe.
    v2args = {'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'Verbose', false};
    if ~strcmp(options.TargetVersion, 'V_delta')
        v2args = [v2args, {'TargetVersion', options.TargetVersion}];
    end
    convertResult = did2.convert.v1_to_v2(bodies, v2args{:});

    % --- second pass: context-dependent (session-aware) deferrals ----------
    % Some V_epsilon classes cannot be migrated from a single document alone
    % (e.g. stimulus_bath -> bath needs the stimulator element's subject and
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
    strainReport = [];
    openmindsCitationsReport = [];
    datasetEntitiesReport = [];
    epochMintReport = [];
    epochAnchorReport = [];
    sessionAnchorReport = [];
    responseParametersReport = [];
    lawnPlateReport = [];
    genericFileFoldReport = [];
    validIntervalReport = [];
    softwareDedupReport = [];
    ontologyRowReport = [];
    ontologyLabelReport = [];
    imagedEntityReport = [];
    if any(strcmp(options.TargetVersion, {'V_epsilon', 'V_zeta'}))
        try
            resolver = ndi.migrate.internal.bodyResolver(bodies);
            convertResult = resolveDeferred(convertResult, resolver, options);
        catch ME
            warning('NDI:migrate:deferredResolveFailed', ...
                ['Second-pass resolution of session-context deferrals ' ...
                 'failed (%s); leaving them quarantined.'], ME.message);
        end
    elseif strcmp(options.TargetVersion, 'V_eta')
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
        %   (1b) ONTOLOGY ROW SUBJECTS (#53): an `ontologyTableRow` names its
        %       subject in a way a single document cannot follow -- a
        %       `document_id` edge, or a plain table cell holding a subject
        %       document id or local identifier. Pass 1 therefore guards and
        %       passes the row through (20,583 documents in the last measured
        %       census: JH 14,378 + Dab 6,205, run 31415147934). Here the
        %       subject is resolved against the migrated set and the row is
        %       re-folded through v1_to_v2, where the pass-1 fan-out runs.
        %       Runs BEFORE Path-S so the statements it emits are Path-S
        %       candidates. See ndi.migrate.internal.ontologyRowSubjects.
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
        %       EPOCH-SCOPED, carrying column order in `sequence`) plus
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
        %       visual_grating_manipulation, sampled_body, data_body, term,
        %       term_observation, subject_observation, strain,
        %       directed_relation, entity, epoch, relative_reference), and
        %       (5)/(7) index `session` documents by an exact class-name match
        %       (epochMint.m:282, resolveSessionAnchors.m:206) so a duplicate
        %       `dataset` entity cannot pollute either index whichever way round
        %       they run. Dropping a duplicate cannot dangle an inbound edge
        %       either, because the duplicates SHARE the surviving id.
        %       See ndi.migrate.internal -- deliberately NOT there: the pass is
        %       DID-side so the gate and production run the same code.
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
        %   (7c) LAWN / PLATE SUBJECTS: mint the bacterial LAWN and PLATE
        %       subject tiers from Haley's E. coli tables, join them with
        %       `member_of`, and give every patch subject the
        %       (experiment, plate, patch) `local_identifier`. The patch row
        %       keys on `imageID` and carries neither `plateID` nor `expID`
        %       (+setup/+conv/+haley/doImport.m:714-723), so both the
        %       membership and the identifier come off the same two-hop chain
        %       patch -> image row -> plate row, which no single-document
        %       migrator can walk. Lives DID-side
        %       (did2.convert.resolveLawnPlateSubjects).
        %
        %       THIS IS THE MODELLING CALL THE TWO ONTOLOGY PASSES DEFERRED,
        %       now made. ndi.migrate.internal.ontologyLabelSubjects says in
        %       its own words: "Whether a bacterial patch ever gets a subject
        %       -- a plate? a lawn? nothing? -- is a modelling call, and
        %       modelling calls are the team's"; step (1c)'s note above and
        %       ontologyRowSubjects' "A ROW WITH NO SUBJECT COLUMN IS NOT A
        %       DEFECT" say the same thing from the other side. The team
        %       answered on 2026-08-11 ("each lawn can be a subject and a plate
        %       of lawns is another subject where each lawn is a member of
        %       it"), so those two passes' `blocked_target_has_no_subject` and
        %       `unresolved_no_candidate` counts now have somewhere to go. They
        %       are NOT changed here -- this pass adds the subject tier; it
        %       does not re-run them.
        %
        %       ORDER: (7b) then (7c), after (7) and before (6), which is the
        %       relative order all three DID call sites use
        %       (runCorpusDiscovery.m:70/88/108/145/178/211). Within that,
        %       (7c) commutes with everything above it -- it reads
        %       `ontology_table_row` and `subject` documents, which no other
        %       sub-pass in this block writes -- and (6) stays LAST so it still
        %       sees any `software` minted by a re-folded body, which is the
        %       reason its own note gives for running there.
        %  (7c2) IMAGED-ENTITY SUBJECTS (team decision, 2026-08-11: "Mint a
        %       subject for what the image is of. And shouldn't there be an
        %       accompanying ontology_table_row that gives that information?").
        %       The answer to the second half is yes and it is the mechanism:
        %       an image names an `ontologyTableRow`, and the row is what says
        %       what the image depicts. A subject-less image is attributed by
        %       walking image -> row -> subject and is then RE-FOLDED, so
        %       +migrators_j/image_stack.m's guard passes and the
        %       image_observation + sampled_body fold finally runs on the
        %       E. coli half (doImport.m:789,811,827 -- the 4,563 documents of
        %       the `image_observation.subject_id` census row).
        %       See ndi.migrate.internal.imagedEntitySubjects.
        %
        %       IT MINTS NOTHING, AND THAT IS THE POINT. (7c) ALREADY MINTED
        %       the plate subject an E. coli image is of, and says in its own
        %       "WHAT IT DOES NOT DO": "NO IMAGE SUBJECT. An image is not a
        %       subject; the image rows are read as the JOIN TABLE they are and
        %       are left exactly as pass 1 emitted them." This pass closes that
        %       gap by ATTACHING. A second mint here would put two subjects on
        %       one plate -- both valid, both referenced, invisible to every
        %       gate. Where no subject exists it REFUSES and COUNTS
        %       (`unresolved_no_plate_subject`), which is the number that tells
        %       the team whether (7c)'s "only where that tier has something
        %       measured about it" rule should treat an image as a measurement.
        %
        %       ORDER: IMMEDIATELY AFTER (7c), AND THE DEPENDENCY IS REAL. It
        %       reads the plate subjects (7c) mints; run any earlier it would
        %       find none and report a zero that meant "too early", not "clean".
        %       It is the one sub-pass here that does NOT commute.
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
        %   (6) SOFTWARE DEDUP (#25): pass 1 mints one `software` entity per
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
        try
            resolver = ndi.migrate.internal.bodyResolver(bodies);
            convertResult = resolveDeferred(convertResult, resolver, options);
        catch ME
            warning('NDI:migrate:deferredResolveFailed', ...
                ['Second-pass resolution of session-context deferrals ' ...
                 'failed (%s); leaving them quarantined.'], ME.message);
        end
        try
            [convertResult, ontologyRowReport] = ...
                resolveOntologyRowSubjects(convertResult, bodies, options);
        catch ME
            warning('NDI:migrate:ontologyRowSubjectsFailed', ...
                ['Second-pass ontology_table_row subject resolution failed ' ...
                 '(%s); leaving the rows as passthrough.'], ME.message);
        end
        try
            [convertResult, ontologyLabelReport] = ...
                resolveOntologyLabelSubjects(convertResult, options);
        catch ME
            warning('NDI:migrate:ontologyLabelSubjectsFailed', ...
                ['Second-pass ontology_label subject resolution failed ' ...
                 '(%s); leaving the labels as passthrough.'], ME.message);
        end
        try
            convertResult = resolveStimulusPresentations(convertResult, bodies, options);
        catch ME
            warning('NDI:migrate:presentationResolveFailed', ...
                ['Second-pass stimulus_presentation assembly failed (%s); ' ...
                 'leaving presentations as passthrough.'], ME.message);
        end
        try
            convertResult = resolvePathS(convertResult, options);
        catch ME
            warning('NDI:migrate:pathSFailed', ...
                ['Second-pass Path-S promotion failed (%s); leaving ' ...
                 'anatomical loci located-by-default.'], ME.message);
        end
        try
            [convertResult, strainReport] = ...
                resolveStrainAssembly(convertResult, options);
        catch ME
            warning('NDI:migrate:strainAssemblyFailed', ...
                ['Second-pass strain assembly failed (%s); leaving the ' ...
                 'openminds Strain documents as passthrough.'], ME.message);
        end
        try
            [convertResult, openmindsCitationsReport] = ...
                did2.convert.resolveOpenmindsCitations( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:openmindsCitationsFailed', ...
                ['Second-pass openMINDS citation assembly failed (%s); ' ...
                 'leaving the `openminds` documents as passthroughs, which ' ...
                 'is the state they are in without this pass.'], ME.message);
        end
        try
            [convertResult, datasetEntitiesReport] = ...
                resolveDatasetEntitiesPass(convertResult, options);
        catch ME
            warning('NDI:migrate:datasetEntitiesFailed', ...
                ['Second-pass dataset entity resolution failed (%s); leaving ' ...
                 'the duplicate `dataset` entities and the unresolvable ' ...
                 '`migrated_session_membership` edges in place.'], ME.message);
        end
        try
            [convertResult, epochMintReport] = did2.convert.epochMint( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:epochMintFailed', ...
                ['Second-pass epoch mint failed (%s); leaving the epoch ' ...
                 'association as the did_v1 `epochid` string.'], ME.message);
        end
        try
            [convertResult, ensembleReport] = resolveEnsembleMembership( ...
                convertResult, epochMintReport, options);
        catch ME
            warning('NDI:migrate:ensembleMembershipFailed', ...
                ['Second-pass ensemble membership failed (%s); leaving the ' ...
                 'ensemble map documents as passthrough.'], ME.message);
        end
        try
            [convertResult, epochAnchorReport] = ...
                resolveEpochAnchorFold(convertResult, epochMintReport, options);
        catch ME
            warning('NDI:migrate:epochAnchorFoldFailed', ...
                ['Second-pass epoch anchor fold failed (%s); leaving the ' ...
                 'stimulator anchors as pass-1 epoch_bounded_reference ' ...
                 'documents.'], ME.message);
        end
        try
            [convertResult, sessionAnchorReport] = ...
                did2.convert.resolveSessionAnchors( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:sessionAnchorFoldFailed', ...
                ['Second-pass session anchor fold failed (%s); leaving the ' ...
                 'time references as pass-1 session_relative_reference / ' ...
                 'session_bounded_reference documents.'], ME.message);
        end
        try
            [convertResult, responseParametersReport] = ...
                did2.convert.resolveResponseParameters( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:responseParametersFoldFailed', ...
                ['Second-pass stimulus-response parameter fold failed (%s); ' ...
                 'leaving the run knobs in their own ' ...
                 '`stimulus_response_scalar_parameters_basic` documents with ' ...
                 'the leaf still carrying the edge.'], ME.message);
        end
        try
            [convertResult, lawnPlateReport] = ...
                did2.convert.resolveLawnPlateSubjects( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:lawnPlateSubjectsFailed', ...
                ['Second-pass lawn/plate subject mint failed (%s); leaving ' ...
                 'the E. coli patch and plate rows as passthroughs.'], ...
                ME.message);
        end
        try
            [convertResult, imagedEntityReport] = ...
                resolveImagedEntitySubjects(convertResult, bodies, options);
        catch ME
            warning('NDI:migrate:imagedEntitySubjectsFailed', ...
                ['Second-pass imaged-entity subject attribution failed (%s); ' ...
                 'leaving every subject-less image as a passthrough.'], ...
                ME.message);
        end
        try
            [convertResult, genericFileFoldReport] = ...
                did2.convert.foldGenericFiles( ...
                convertResult, ...
                'Validate',      options.Validate, ...
                'SchemaCache',   options.SchemaCache, ...
                'TargetVersion', options.TargetVersion);
        catch ME
            warning('NDI:migrate:genericFileFoldFailed', ...
                ['Second-pass generic_file fold failed (%s); leaving every ' ...
                 '`generic_file` document as a passthrough, which is the ' ...
                 'state it is in without this pass.'], ME.message);
        end
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
            warning('NDI:migrate:validIntervalDecomposeFailed', ...
                ['Second-pass valid_interval decompose failed (%s); leaving ' ...
                 'every `valid_interval` document as a passthrough, which is ' ...
                 'the state it is in without this pass. NOTE what this does ' ...
                 'NOT mean: absence of a validity statement still means the ' ...
                 'data is VALID (ndi.app.markgarbage is opt-in), so a failure ' ...
                 'here loses the go-forward representation, not the meaning.'], ...
                ME.message);
        end
        try
            [convertResult, softwareDedupReport] = ...
                resolveSoftwareDedup(convertResult);
        catch ME
            warning('NDI:migrate:softwareDedupFailed', ...
                ['Second-pass software dedup failed (%s); leaving one ' ...
                 '`software` entity per consuming document.'], ME.message);
        end
    end

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

    refReport = did2.validate.references(convertResult.migrated);

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
    result.quarantine = convertResult.quarantine;
    result.quarantineFile = wroteQuarantineFile;
    result.references = refReport;
    result.secondPass = struct( ...
        'ensembleMembership',  ensembleReport, ...
        'strainAssembly',      strainReport, ...
        'ontologyRowSubjects', ontologyRowReport, ...
        'ontologyLabelSubjects', ontologyLabelReport, ...
        'openmindsCitations',  openmindsCitationsReport, ...
        'datasetEntities',     datasetEntitiesReport, ...
        'epochMint',           epochMintReport, ...
        'epochAnchorFold',     epochAnchorReport, ...
        'sessionAnchorFold',   sessionAnchorReport, ...
        'responseParametersFold', responseParametersReport, ...
        'lawnPlateSubjects',   lawnPlateReport, ...
        'imagedEntitySubjects', imagedEntityReport, ...
        'genericFileFold',     genericFileFoldReport, ...
        'validIntervalDecompose', validIntervalReport, ...
        'softwareDedup',       softwareDedupReport);

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

% ---- second pass: session-context-dependent deferrals ---------------------

function convertResult = resolveDeferred(convertResult, resolver, options)
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
            bodies = assembleDeferred(q(k).class_name, v1Body, resolver, ...
                options.TargetVersion);
            assembled = [assembled, bodies]; %#ok<AGROW>
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

function bodies = assembleDeferred(className, v1Body, resolver, targetVersion)
% Dispatch a deferred v1 body to its session-aware assembler. Returns a cell
% array of target-version bodies (so a 1 -> N assembly fits). Add new
% context-dependent classes here as their assemblers land.
    switch className
        case 'stimulus_bath'
            [bathBody, timeRefBody] = ...
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

function convertResult = resolvePathS(convertResult, options)
%RESOLVEPATHS V_eta second pass: promote attributed anatomical loci to Path-S
%   part-subjects using the whole migrated body set. The pass-1 J migrators emit
%   a located-by-default `term_observation` for every anatomical site (D3); here
%   -- with the corpus-wide subject graph in hand -- a site that is an
%   intervention target (co-anchored with a manipulation) becomes a part-subject
%   + a `term_assertion` of its anatomical kind + a `part_of` `directed_relation`,
%   and the co-anchored manipulation is retargeted onto the part. Merely-located
%   sites (probe/label) are left untouched. See ndi.migrate.internal.pathSPromotion.
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);
    if ~changed
        return;
    end
    % rewrap the surviving (possibly retargeted) bodies
    keptDocs = cell(1, numel(kept));
    for k = 1:numel(kept)
        keptDocs{k} = did2.document(kept{k});
    end
    convertResult.migrated = keptDocs;
    % fold the minted part-subject / term_assertion / part_of bodies through
    % v1_to_v2: they are tagged schema_version 'V_eta', so the converter
    % short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate
    % rather than re-migrating -- the same footing the deferred-resolution pass
    % uses.
    if ~isempty(minted)
        sub = did2.convert.v1_to_v2(minted, ...
            'Validate', options.Validate, ...
            'SchemaCache', options.SchemaCache, ...
            'TargetVersion', options.TargetVersion, ...
            'Verbose', false);
        convertResult.migrated = [convertResult.migrated, sub.migrated];
        convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    end
    convertResult.summary = recountSummary(convertResult);
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
%   built yet (the `sampled_body` cache document and its T6 `is_cache` marker,
%   neither of which exists in the built schema set).
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
    % The minted relations are tagged schema_version 'V_eta', so v1_to_v2
    % short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate --
    % the same footing the deferred-resolution and Path-S passes use.
    sub = did2.convert.v1_to_v2(minted, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, report] = resolveOntologyRowSubjects(convertResult, bodies, options)
%RESOLVEONTOLOGYROWSUBJECTS V_eta second pass (#53): give each passed-through
%   `ontology_table_row` the subject it names, then re-fold it so the pass-1
%   per-column fan-out runs.
%
%   ndi.migrate.internal.ontologyRowSubjects does the RESOLUTION (pure struct
%   logic, no converter, no schema) and returns a plan: for every row whose
%   subject it could resolve against the migrated set, a copy of the did_v1
%   body with a `subject_id` dependency added. This function does the FOLD, one
%   row at a time, through did2.convert.v1_to_v2 at TargetVersion V_eta --
%   where did2.convert.migrators_j.ontology_table_row's guard now passes.
%
%   ONE ROW AT A TIME, AND REVERTIBLE, ON PURPOSE. Two outcomes must not be
%   allowed to make anything worse than the passthrough they replace:
%
%     * the re-fold QUARANTINES -> keep the passthrough. A quarantine is a
%       gating failure; a passthrough is not. Trading the second for the first
%       is the `epochfiles_ingested` regression, and it is what happened when
%       distance_metadata's endpoint relation was minted (a non-gating
%       quarantine became a GATING orphan failure).
%     * the re-fold produces ONLY the row again (every column was an identity
%       column, so migrateRow skipped them all and the migrator returned
%       `{preBody}`) -> keep the ORIGINAL passthrough. Writing the re-folded
%       copy would add a `subject_id` edge to a tombstone and nothing else:
%       a document that looks converted and says exactly what it said before.
%       Haley's plateSubjectTable is `{subject_id, plate_id}` and lands here.
%
%   REPORT carries the resolver's denominators plus the fold outcomes;
%   REPORT.changed is true only when a row was actually REPLACED.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [plan, report] = ndi.migrate.internal.ontologyRowSubjects(bodies, structs);

    % Fold outcomes are part of the same instrument, so they are initialised
    % unconditionally -- a field that appears only on the success path is a
    % counter that cannot report a zero.
    report.rows_planned          = numel(plan);
    report.rows_replaced         = 0;
    report.refold_no_statements  = 0;
    report.refold_quarantined    = 0;
    report.statements_emitted    = 0;
    report.changed               = false;
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
            continue;   % REVERT: keep the passthrough
        end
        if ~isempty(sub.quarantine) || isempty(sub.migrated)
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT
        end
        if isscalar(sub.migrated) ...
                && strcmp(sub.migrated{1}.className(), 'ontology_table_row')
            report.refold_no_statements = report.refold_no_statements + 1;
            continue;   % REVERT
        end
        replacedIds{end+1} = plan(k).source_id; %#ok<AGROW>
        newDocs = [newDocs, sub.migrated]; %#ok<AGROW>
        report.rows_replaced = report.rows_replaced + 1;
        report.statements_emitted = report.statements_emitted + numel(sub.migrated);
    end

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if strcmp(d.className(), 'ontology_table_row') ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the re-folded statements
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
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
%   tagged schema_version 'V_eta' and is therefore short-circuited
%   (isAlreadyTarget) to ensureClassBlocks + validate, the same footing Path-S
%   and ensembleMembership use for minted bodies.
%
%   THE LABEL'S id IS PRESERVED, so the replacement supersedes the passthrough
%   rather than joining it: two documents with one id is not a state this
%   database has a meaning for. The passthrough is removed only for labels whose
%   replacement actually came back out of the re-fold.
%
%   ONE AT A TIME, AND REVERTIBLE, ON PURPOSE -- the rule
%   resolveOntologyRowSubjects states and the reason is the same: a re-fold that
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
            sub = did2.convert.v1_to_v2({plan(k).body}, ...
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
        if strcmp(d.className(), 'ontology_label') ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the term_observation carrying its id
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.changed = true;
end

function [convertResult, report] = resolveImagedEntitySubjects(convertResult, bodies, options)
%RESOLVEIMAGEDENTITYSUBJECTS V_eta second pass: attribute each subject-less
%   image to the subject of WHAT IT IS AN IMAGE OF, then re-fold it so the
%   pass-1 image_observation + sampled_body fold runs.
%
%   ndi.migrate.internal.imagedEntitySubjects does the RESOLUTION (pure struct
%   logic, no converter, no schema) and returns a plan: for every image whose
%   depicted subject it could resolve against the migrated set, a copy of the
%   did_v1 body with a `subject_id` dependency added. This function does the
%   FOLD, one image at a time, through did2.convert.v1_to_v2 at TargetVersion
%   V_eta -- where did2.convert.migrators_j.image_stack's guard now passes.
%
%   ORDER: IMMEDIATELY AFTER did2.convert.resolveLawnPlateSubjects, AND THE
%   DEPENDENCY IS REAL, not a preference. That pass mints the plate subjects
%   this one attaches to; run before it, this pass would find no plate subject
%   for any image and report a clean-looking zero that meant only "too early".
%
%   ONE IMAGE AT A TIME, AND REVERTIBLE, ON PURPOSE -- the rule
%   resolveOntologyRowSubjects sets, for the same reason:
%
%     * the re-fold QUARANTINES -> keep the passthrough. A quarantine is a
%       gating failure and a passthrough is not, and trading the second for the
%       first is the `epochfiles_ingested` regression.
%     * the re-fold produces only the image again (the migrator took a
%       passthrough arm anyway) -> keep the ORIGINAL. Writing the re-folded copy
%       would add a `subject_id` edge to a tombstone and nothing else: a
%       document that looks converted and says exactly what it said before.
%
%   THE SESSION ANCHORS IT CREATES ARE FOLDED, and this is not optional. The
%   image_stack fold mints a `session_relative_reference` per image
%   (+migrators_j/image_stack.m, the "session-relative time anchor" block), but
%   did2.convert.resolveSessionAnchors -- which rewrites those into
%   `relative_reference` -- has ALREADY RUN by the time this pass can go, because
%   it sits above resolveLawnPlateSubjects in the call order. Left alone, this
%   pass would emit anchors in the pass-1 form while every other anchor in the
%   batch had been folded: not a quarantine and not an orphan, but a batch that
%   is internally inconsistent for no reason a reader could see. So the fold is
%   re-run, ONLY when this pass actually replaced something. It is safe to run
%   twice: resolveSessionAnchors selects documents BY CLASS NAME
%   (`session_relative_reference` / `session_bounded_reference`), and an
%   already-folded anchor is a `relative_reference`, so the second run cannot
%   see it. Re-running is not free on a large batch, which is exactly why it is
%   conditional on `changed` rather than unconditional.
%
%   REPORT carries the resolver's denominators plus the fold outcomes;
%   REPORT.changed is true only when an image was actually REPLACED.
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [plan, report] = ndi.migrate.internal.imagedEntitySubjects(bodies, structs);

    % Fold outcomes belong to the same instrument, so they are initialised
    % unconditionally -- a field that appears only on the success path is a
    % counter that cannot report a zero.
    report.images_refolded         = 0;
    report.refold_no_observation   = 0;
    report.refold_quarantined      = 0;
    report.documents_emitted       = 0;
    report.session_anchors_refolded = false;
    report.changed                 = false;
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
            continue;   % REVERT: keep the passthrough
        end
        if ~isempty(sub.quarantine) || isempty(sub.migrated)
            report.refold_quarantined = report.refold_quarantined + 1;
            continue;   % REVERT
        end
        if isscalar(sub.migrated) ...
                && any(strcmp(sub.migrated{1}.className(), ...
                    {'image_stack', 'ontology_image'}))
            report.refold_no_observation = report.refold_no_observation + 1;
            continue;   % REVERT
        end
        replacedIds{end+1} = plan(k).source_id; %#ok<AGROW>
        newDocs = [newDocs, sub.migrated]; %#ok<AGROW>
        report.images_refolded = report.images_refolded + 1;
        report.documents_emitted = report.documents_emitted + numel(sub.migrated);
    end

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if any(strcmp(d.className(), {'image_stack', 'ontology_image'})) ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the re-folded observation
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.changed = true;

    % Fold the anchors this pass just created -- see the header for why this is
    % conditional and why running twice is safe.
    try
        convertResult = did2.convert.resolveSessionAnchors( ...
            convertResult, ...
            'Validate',      options.Validate, ...
            'SchemaCache',   options.SchemaCache, ...
            'TargetVersion', options.TargetVersion);
        report.session_anchors_refolded = true;
    catch ME
        % Reported, never swallowed: the anchors stay in their pass-1 form and
        % the false in this field is what says so.
        warning('NDI:migrate:imagedEntityAnchorFoldFailed', ...
            ['Re-folding the session anchors minted by the imaged-entity ' ...
             'pass failed (%s); those anchors remain ' ...
             '`session_relative_reference`.'], ME.message);
    end
    convertResult.summary = recountSummary(convertResult);
end

function [convertResult, report] = resolveStrainAssembly(convertResult, options)
%RESOLVESTRAINASSEMBLY V_eta second pass: assemble the unattached `openminds`
%   Strain documents into `strain` entities with their ids PRESERVED, consuming
%   the Species / GeneticStrainType fragment documents they reference into the
%   strain's `species` / `genetic_strain_type` fields and wiring
%   `backgroundStrain` into `background_strain_#`. A second pass because those
%   values live in OTHER documents, reachable only through the `ndi://` /
%   `openminds_#` links a single-document migrator cannot follow.
%
%   Id preservation is load-bearing rather than tidy: `ontologyTableRow`'s
%   `bacteriaStrain` column holds the strain document's id as a plain string
%   (haley/doImport.m:164,734), so nothing would flag a re-mint. The
%   `strain_id` edge itself is NOT attached here -- it rides with the pass that
%   mints subjects from `ontologyTableRow` (#53), which does not exist yet.
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
    seenIds = {};
    for k = 1:numel(docs)
        cls = docs{k}.className();
        if strcmp(cls, 'dataset')
            c.dataset_entities = c.dataset_entities + 1;
            id = safeDocGet(docs{k}, 'base.id');
            if ~isempty(id) && ~any(strcmp(id, seenIds))
                seenIds{end+1} = id; %#ok<AGROW>
            end
        elseif strcmp(cls, 'directed_relation') && strcmp( ...
                safeDocGet(docs{k}, 'base.name'), 'migrated_session_membership')
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
    epochMintReport, options)
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
    [plan, report] = ndi.migrate.internal.epochAnchorFold(structs, epochIndex);

    % Fold outcomes belong to the same instrument, so they are initialised
    % unconditionally -- a field that appears only on the success path is a
    % counter that cannot report a zero.
    report.anchors_refolded   = 0;
    report.refold_quarantined = 0;
    report.folded             = false;
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

    if isempty(replacedIds)
        return;
    end

    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if strcmp(d.className(), 'epoch_bounded_reference') ...
                && any(strcmp(d.get('base.id'), replacedIds))
            continue;   % superseded by the relative_reference carrying its id
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = [kept, newDocs];
    convertResult.summary = recountSummary(convertResult);
    report.folded = true;
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

function convertResult = resolveStimulusPresentations(convertResult, bodies, options)
%RESOLVESTIMULUSPRESENTATIONS V_eta second pass: assemble each legacy
%   stimulus_presentation into a body-backed visual_grating_manipulation on the
%   animal (+ its sampled_body), using the recording graph. The pass-1 converter
%   has no per-document migrator for stimulus_presentation (the animal and the
%   trial series are only knowable from the whole body set -- the
%   stimulus_response -> element -> subject link), so it passes through; here it
%   becomes the manipulation. A presentation with no responding animal is left as
%   passthrough (nothing to place the manipulation on). The manipulation preserves
%   the presentation's id, so inbound references resolve to it.
    resolver = ndi.migrate.internal.bodyResolver(bodies);
    % The first-run v1 readers (did2.convert.readers.sqliteV1 / dumbJsonV1)
    % return raw JSON char bodies -- nothing is decoded there. isPresentationBody
    % (and stimulusPresentationToManipulation's struct-typed argument) need
    % decoded structs, so normalise here; the idempotent re-run path already
    % passes structs, which this leaves untouched.
    bodies = decodeBodies(bodies);
    minted = {};
    consumed = {};   % presentation ids that became a manipulation
    for k = 1:numel(bodies)
        b = bodies{k};
        if ~isPresentationBody(b)
            continue;
        end
        [manip, bodyDoc, ~] = ndi.migrate.internal.stimulusPresentationToManipulation( ...
            b, resolver, options.TargetVersion);
        if isempty(manip)
            continue;   % no animal responded -> leave the presentation as-is
        end
        minted{end+1} = manip;   %#ok<AGROW>
        minted{end+1} = bodyDoc; %#ok<AGROW>
        consumed{end+1} = bodyBaseId(b); %#ok<AGROW>
    end
    if isempty(minted)
        return;
    end
    % drop the passthrough stimulus_presentation docs that were assembled away
    kept = {};
    for k = 1:numel(convertResult.migrated)
        d = convertResult.migrated{k};
        if strcmp(d.className(), 'stimulus_presentation') ...
                && any(strcmp(d.get('base.id'), consumed))
            continue;
        end
        kept{end+1} = d; %#ok<AGROW>
    end
    convertResult.migrated = kept;
    % fold the minted manipulation + sampled_body through v1_to_v2: they are
    % tagged schema_version == TargetVersion, so the converter short-circuits them
    % (isAlreadyTarget) to ensureClassBlocks + validate -- the same footing the
    % deferred-resolution and Path-S passes use.
    sub = did2.convert.v1_to_v2(minted, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
    convertResult.migrated = [convertResult.migrated, sub.migrated];
    convertResult.quarantine = [convertResult.quarantine, sub.quarantine];
    convertResult.summary = recountSummary(convertResult);
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
    sqliteListing = sqliteListing(~strcmpi({sqliteListing.name}, 'V_delta.sqlite'));
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

% ---- read V_delta bodies (idempotent re-run path) --------------------------

function [bodies, srcInfo] = readBodiesFromVDelta(dstPath)
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
        fprintf('  already-migrated fast pass (V_delta.sqlite present).\n');
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
    fprintf('  orphan refs:      %d (of %d edges)\n', ...
        result.references.orphan_count, result.references.edges_examined);
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

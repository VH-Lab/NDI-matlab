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
    epochMintReport = [];
    sessionAnchorReport = [];
    softwareDedupReport = [];
    ontologyRowReport = [];
    ontologyLabelReport = [];
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
        % V_eta's second pass has seven kinds of work, all needing the whole
        % migrated body set (the corpus-wide session/element graph):
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
        %       `member_of` edges (neuron-subject -> ensemble group-subject)
        %       plus `derived_from` provenance for the combined-binary cache.
        %       Adds only; drops nothing (the verify-before-delete gate has not
        %       run). See ndi.migrate.internal.ensembleMembership.
        %   (4) STRAIN ASSEMBLY: the unattached `openminds` Strain documents
        %       become `strain` entities (ids preserved), consuming their
        %       Species / GeneticStrainType fragments. See
        %       ndi.migrate.internal.strainAssembly.
        %   (5) EPOCH MINT (#60): one `epoch` entity per distinct
        %       (base.session_id, epoch-id string). The KEY IS THE PAIR --
        %       an `epochid.epochid` string is reused across sessions (142 of
        %       corpus B's 149 distinct ids), so keying on the string alone
        %       would fuse epochs from different sessions. Lives DID-side
        %       (did2.convert.epochMint) beside resolveDatasetEntities, so the
        %       corpus discovery harness runs the same code this does.
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
            [convertResult, ensembleReport] = ...
                resolveEnsembleMembership(convertResult, options);
        catch ME
            warning('NDI:migrate:ensembleMembershipFailed', ...
                ['Second-pass ensemble membership failed (%s); leaving the ' ...
                 'ensemble map documents as passthrough.'], ME.message);
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
        'epochMint',           epochMintReport, ...
        'sessionAnchorFold',   sessionAnchorReport, ...
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
            bodies = {timeRefBody, bathBody};
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

function [convertResult, report] = resolveEnsembleMembership(convertResult, options)
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
%   verify-before-delete (0 stranded per-neuron trains) that has not run. The
%   pass MEASURES that gate -- REPORT.neuron_edges_stranded and
%   REPORT.stranded_neuron_ids -- and reports its denominator first.
%   See ndi.migrate.internal.ensembleMembership for what is deliberately not
%   built yet (epoch-scoping the edges, and the `sampled_body` cache document).
    report = [];
    docs = convertResult.migrated;
    if isempty(docs)
        return;
    end
    structs = cell(1, numel(docs));
    for k = 1:numel(docs)
        structs{k} = docs{k}.toStruct();
    end
    [kept, minted, report] = ndi.migrate.internal.ensembleMembership(structs);
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

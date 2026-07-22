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
        % V_eta's second pass has two kinds of work, both needing the whole
        % migrated body set (the corpus-wide session/element graph):
        %   (1) DEFERRALS: some J migrators still defer a document that needs
        %       session context -- stimulus_bath (-> dose_manipulation, D8
        %       retired the bath family). Resolve them the same way the older
        %       targets do (assembleDeferred), just at TargetVersion V_eta.
        %   (2) PATH-S: an attributed anatomical locus is promoted to a
        %       part-subject. Run AFTER the deferrals so a manipulation the
        %       deferral emits can be a Path-S retarget candidate.
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

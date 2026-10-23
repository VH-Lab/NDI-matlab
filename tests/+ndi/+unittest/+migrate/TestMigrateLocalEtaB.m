classdef TestMigrateLocalEtaB < matlab.unittest.TestCase
%TESTMIGRATELOCALETAB Corpus B through the WHOLE V_eta pipeline.
%
%   Corpus B is the Fitzpatrick-lab tree-shrew dataset `2013_treeshrew_LGNctx`
%   (13 sessions dated 2008, subjects ts08xx@fitzpatrick_duke, plus the dataset
%   session): 12,917 v1 documents, migrated in full through ndi.migrate.local,
%   opened through ndi.session.dir, and read back through the object API.
%
%   WHY B HAS ITS OWN e2e. B holds every one of the 1,242 vhlab NewStim
%   `stimulus_presentation` documents these corpora carry (53,144 stimuli),
%   and they are what the stimulus second pass (stimulusPresentationTo-
%   TimedSequence + the NewStim class recogniser) folds or refuses. They used
%   to be checked inside TestMigrateLocalEtaDab, because Dab.zip bundles the
%   whole of B beside Dabrowska's own sessions (all 12,917 B files are byte-
%   identical members of Dab.zip; 0 depends_on edges cross between the two
%   halves). Jess Haley, 2026-10-21: the Dab tests read only the Dabrowska
%   documents, and the presentation / grating checks live HERE, on B's own zip
%   (the same B.zip DID-matlab's testCorpusB reads).
%
%   HARD ASSERTS: the corpus size, 0 quarantine, 0 orphans, 0 fragments, and
%   the 1,242 presentations the stimulus pass reads -- all measured (the B
%   documents migrated with 0 quarantine / 0 orphans inside the Dab e2e run
%   39553759047, and its fold report read 1,242 presentations).
%
%   REPORT-ONLY: the pass-1 unconverted set, the final survivor set, the
%   per-session read-back counts, the fold / refusal split and the parameter
%   census. They decide nothing (Operating Rule 4).
%
%   SKIPS, NEVER FAILS, when the environment cannot support it: no mksqlite,
%   NDI_TEST_ETA unset, DID_SCHEMA_PATH unset, or the corpus will not download.
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring container;
%   validation runs via CI (test-eta-migrate-b.yml).

    properties
        SessionRoot
        CorpusDir
        Result
        Bodies
    end

    methods (TestClassSetup)

        function gateAndMigrate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; skipping.');
            end
            try
                testCase.CorpusDir = ensureBCorpus();
            catch ME
                assumeFail(testCase, sprintf( ...
                    'could not fetch the B corpus (%s); skipping.', ...
                    ME.message));
            end

            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));

            t = tic;
            testCase.Bodies = readCorpusBodies(testCase.CorpusDir);
            fprintf('  [B timing] readCorpusBodies: %d docs in %.1f s\n', ...
                numel(testCase.Bodies), toc(t));
            t = tic;
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);
            fprintf('  [B timing] buildV1Sqlite: %.1f s\n', toc(t));

            t = tic;
            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
            fprintf('  [B timing] ndi.migrate.local: %.1f s\n', toc(t));
        end

    end

    methods (TestClassTeardown)
        function cleanup(testCase)
            try
                if ~isempty(testCase.SessionRoot) && isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testTheWholeCorpusMigratesWithNothingQuarantinedOrDangling(testCase)
            % DENOMINATOR FIRST: a pass over zero documents quarantines zero.
            verifyEqual(testCase, numel(testCase.Bodies), 12917, sprintf( ...
                ['the B corpus did not read as 12917 documents (got %d); ' ...
                 'every assertion here would be about a different corpus'], ...
                numel(testCase.Bodies)));
            verifyGreaterThan(testCase, testCase.Result.summary.total, 0, ...
                'the migration saw no documents at all');
            verifyEmpty(testCase, testCase.Result.quarantine, ...
                quarantineDiag(testCase.Result));
            verifyEqual(testCase, testCase.Result.references.orphan_count, 0, ...
                sprintf('the migrated graph does not close: %d orphan(s). %s', ...
                    testCase.Result.references.orphan_count, ...
                    resultDiag(testCase.Result)));
            verifyGreaterThan(testCase, testCase.Result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans is a ' ...
                 'statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % REPORT-ONLY census of what pass 1 handed straight back; the
            % denominator and the fragment count are asserted.
            s = testCase.Result.summary;
            fprintf(['\n  PASS-1 CONVERSION CENSUS (B)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');
            verifyEqual(testCase, s.total, 12917, ...
                'the pass did not see 12917 documents; this figure is about a different corpus');
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT, report-only. The census above counts pass
            % 1; it cannot see the SECOND PASSES that run afterward
            % (stimulusPresentationToTimedSequence among them), so a
            % class that reads "unconverted" there can still reach decided shape.
            % The only sound test of "is this corpus fully at decided shape" is
            % the FINAL output: a v1 SOURCE class name still labelling a
            % destination document did not fold. Measured before it is asserted.
            src = testCase.Bodies;
            dst = destinationBodies(testCase.Result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(src, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (B)\n' ...
                     '    DENOMINATOR: %d source document(s), %d destination ' ...
                     'document(s)\n' ...
                     '    v1 source class names still labelling a destination ' ...
                     'document: %d\n'], ...
                numel(src), numel(dst), numel(survivors));
            if isempty(survivors)
                fprintf('      (none -- every v1 class folded)\n');
            else
                for k = 1:numel(survivors)
                    note = 'UNFOLDED -- a Bar-2 gap unless persist or a declared deferral';
                    if any(strcmp(survivors(k).class_name, {'subject', 'session'}))
                        note = 'persist (v1 class IS the V_eta class)';
                    elseif strcmp(survivors(k).class_name, 'stimulus_response_scalar_parameters_basic')
                        note = 'SIGNED verify-before-delete deferral (#61)';
                    end
                    fprintf('      %6d  %-40s %s\n', survivors(k).count, ...
                        survivors(k).class_name, note);
                end
            end
            % A denominator that read nothing is the silentLoss failure; assert
            % it even while the survivor set itself is report-only.
            verifyEqual(testCase, numel(src), 12917, ...
                'the source census did not read 12917 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
            % THE HEADLINE. If this errors, nothing below it is meaningful. B
            % holds several sessions in ONE migrated database, so this opens ONE
            % of them (the first `session` document) and confirms NDI can reach
            % it on the did2sqlite backend. Per-session object COUNTS are
            % printed, not pinned. What IS asserted: the
            % session opens, the backend chosen is the did2 one, and anything the
            % object API returns is the right TYPE -- zero-with-no-error is the
            % pre-vintage symptom, and a wrong type is a missed rename.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            migrated = destinationBodies(testCase.Result.destination);
            % did-schema #88: the session (or, for a dataset's own session,
            % the dataset) entity; its base.id is the session id
            [sessionDoc, sessionId] = ndi.unittest.migrate.largestSessionRecord(migrated);
            assertNotEmpty(testCase, sessionDoc, ...
                'no session or dataset record in the migrated database');
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionId);

            s = ndi.session.dir(testCase.SessionRoot);
            assertTrue(testCase, isa(s, 'ndi.session.dir'), ...
                'ndi.session.dir did not return a session object');

            selected = ndi.database.fun.opendatabase( ...
                fullfile(testCase.SessionRoot, '.ndi'), s.id());
            assertTrue(testCase, isa(selected, ...
                'ndi.database.implementations.database.did2sqlite'), sprintf( ...
                'opendatabase chose a "%s", not a did2sqlite', class(selected)));

            devs = s.daqsystem_load();
            if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
            for k = 1:numel(devs)
                verifyTrue(testCase, isa(devs{k}, 'ndi.daq.system'), sprintf( ...
                    'daqsystem_load returned a "%s"', class(devs{k})));
            end

            els = s.getelements();
            if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
            for k = 1:numel(els)
                verifyTrue(testCase, isa(els{k}, 'ndi.element'), sprintf( ...
                    'getelements returned a "%s"', class(els{k})));
            end

            fprintf(['\n  READ-BACK (one of B''s session(s))\n' ...
                     '    daqsystem_load: %d object(s)\n' ...
                     '    getelements:    %d object(s)\n'], ...
                numel(devs), numel(els));
        end

        function testTheNavigatorFindsTheMigratedIngestedEpochs(testCase)
            % did-schema #88, Decided by Jess Haley, 2026-10-22 [ingested
            % epochs found] ("B1a"): the classic navigator's ingested-epoch
            % query finds a migrated `ingestion_manifest` through
            % `epoch_file_pattern_id` (ndi.vintage.ingestedQuery), and reads
            % its epoch id, files and probe map (ndi.vintage.ingestedEpochs).
            %
            % DENOMINATORS FIRST, corpus-wide: B carries 2,484 v1
            % epochfiles_ingested documents; after migration each is an
            % ingestion_manifest or (a row with no home) a passthrough
            % epochfiles_ingested. Then, in the session this test opens: for
            % each acquisition system's navigator, the documents the vintage
            % query finds must be exactly that session's documents pointing at
            % the navigator, and every one must give an epoch id and appear in
            % the navigator's epoch table.
            % the source bodies are JSON TEXT (readCorpusBodies), so their
            % class is read from the text, as finalV1SurvivorCensus does
            src = testCase.Bodies(cellfun(@(x) isequal(regexp(char(x), ...
                '"class_name"\s*:\s*"([^"]+)"', 'tokens', 'once'), {'epochfiles_ingested'}), ...
                testCase.Bodies));
            migrated = destinationBodies(testCase.Result.destination);
            manifests = findAllByClass(migrated, 'ingestion_manifest');
            passthrough = findAllByClass(migrated, 'epochfiles_ingested');
            fprintf(['\n  INGESTED EPOCHS (B1)\n' ...
                     '    DENOMINATOR: %d source epochfiles_ingested; migrated to %d ' ...
                     'ingestion_manifest + %d passthrough\n'], ...
                numel(src), numel(manifests), numel(passthrough));
            verifyEqual(testCase, numel(src), 2484, ...
                'B no longer carries 2,484 ingested epochs; the figures below are about a different corpus');
            verifyEqual(testCase, numel(manifests) + numel(passthrough), numel(src), ...
                'an ingested epoch neither became a manifest nor passed through');

            [~, sessionId] = ndi.unittest.migrate.largestSessionRecord(migrated);
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), sessionId);
            s = ndi.session.dir(testCase.SessionRoot);
            devs = s.daqsystem_load();
            if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
            totalFound = 0;
            for k = 1:numel(devs)
                nav = devs{k}.filenavigator;
                navId = nav.id();
                expected = 0;
                for m = [manifests, passthrough]
                    b = m{1};
                    if strcmp(ndi.v2.sessionIdOf(b), s.id()) && ...
                            (any(strcmp(ndi.v2.edgeIds(b, 'epoch_file_pattern_id'), navId)) || ...
                             any(strcmp(ndi.v2.edgeIds(b, 'filenavigator_id'), navId)))
                        expected = expected + 1;
                    end
                end
                found = s.database_search(ndi.vintage.ingestedQuery(navId, s.id()));
                E = ndi.vintage.ingestedEpochs(s, found, nav.epochprobemap_class);
                withId = sum(~cellfun(@isempty, {E.epoch_id}));
                withMap = sum(~cellfun(@isempty, {E.probemap}));
                et = nav.epochtable();
                inTable = sum(ismember({E.epoch_id}, {et.epoch_id}));
                fprintf(['    %s: %d expected, %d found by the vintage query, %d with an ' ...
                         'epoch id, %d with a probe map, %d in the epoch table (of %d)\n'], ...
                    devs{k}.name, expected, numel(found), withId, withMap, inTable, numel(et));
                verifyEqual(testCase, numel(found), expected, sprintf( ...
                    '%s: the navigator''s ingested-epoch query missed or over-found', devs{k}.name));
                verifyEqual(testCase, withId, numel(found), sprintf( ...
                    '%s: an ingested epoch read with no epoch id', devs{k}.name));
                verifyEqual(testCase, inTable, numel(found), sprintf( ...
                    '%s: an ingested epoch is missing from the epoch table', devs{k}.name));
                totalFound = totalFound + numel(found);
            end
            fprintf('    session %s: %d ingested epoch(s) found over %d system(s)\n', ...
                s.id(), totalFound, numel(devs));
        end

        function testStimulusPresentationRefusalsByReason(testCase)
            % REPORT-ONLY (moved here from TestMigrateLocalEtaDab, Jess Haley
            % 2026-10-21: the 1,242 presentations are corpus B's). The second
            % pass records a REASON per refused presentation
            % (Result.secondPass.stimulusSequence.refusals), and this surfaces
            % the histogram of those reasons -- which the corpus log did not.
            % It decides nothing (Operating Rule 4): whether "no responding
            % animal" (a genuine subject-less presentation, whose home is a bare
            % `timed_sequence` -- a team call) DOMINATES, or a different reason
            % (an unresolved-linkage bug the resolver should fix) does, is the
            % measurement this exists to take. Denominator asserted; the split
            % is report-only.
            r = testCase.Result.secondPass.stimulusSequence;
            testCase.assertTrue(isstruct(r) && isfield(r, 'presentations_read'), ...
                'the migrate result carries no stimulusSequence report');

            ndi.unittest.migrate.printStimulusFoldReport(r, 'B');

            % FORK 1 is LIVE: it attributes a response-less presentation to the
            % animal recorded in its OWN session-scoped epoch (the `via epoch,
            % own session` line). THE STIMULATOR ROUTE is LIVE (Jess Haley,
            % 2026-10-21, PR #1021): when the own session-epoch records no
            % element, the presentation's `stimulus_element_id` -> stimulator
            % element -> its v1 subject. On B the 68 presentations fork 1
            % cannot attribute are recorded epochs with no sorted unit (B
            % writes element_epoch only for sorted units), NOT session-id gaps;
            % the stimulator route resolves all 68 in the research read. FORK 2
            % is MEASURED AND DISARMED (2026-08-25): cross-session it gives 2-12
            % sibling subjects and the true animal for none of the 68, so `via
            % epoch, sibling session` reads 0. The residual is characterised by
            % the reasons below; a refusal "refused by class: <NewStim class>"
            % means an animal WAS resolved but the stimuli are not gratings
            % (the class recogniser, Jess Haley 2026-10-21) -- a separate gap
            % whose value model is still open (#48).

            % Denominator only: a run that read the wrong number of
            % presentations would make the histogram a statement about
            % something else. MEASURED: B.zip holds 1242 stimulus_presentation
            % documents, and the Dab e2e (run 39553759047, which carried B)
            % read 1242. The fold / refusal split stays report-only.
            verifyEqual(testCase, r.presentations_read, 1242, ...
                ['the second pass did not read the 1242 stimulus_presentation ' ...
                 'bodies B holds, so the refusal histogram describes something else']);
        end

        function testWhatTheStimulusPresentationParametersActuallyAre(testCase)
            % REPORT-ONLY (moved here from TestMigrateLocalEtaDab). These are the
            % Fitzpatrick tree-shrew vhlab NewStim visual stimuli, NOT
            % Dabrowska's: Dabrowska's only stimulator is the drug `bath`, and
            % the earlier reading that Dab's presentations were bath events was
            % a corpus-bundling confusion (Dab.zip carries the whole of B). This dumps
            % the ACTUAL parameter field-name sets across every stimulus, and the
            % value ranges of the grating-named fields, so what the decoder wrote
            % is SEEN rather than inferred: a real grating carries angle+sf+tf
            % with varied values; a bath event mistyped as one carries a stray or
            % constant field. It decides nothing (Rule 4). The parse mirrors
            % stimulusArray/stimParameters so the sets match what the fold saw.
            gratingNames = {'angle', 'orientation', 'sFrequency', ...
                'spatial_frequency', 'sf', 'tFrequency', 'temporal_frequency', 'tf'};
            fieldSets = containers.Map('KeyType', 'char', 'ValueType', 'double');
            gCount    = containers.Map('KeyType', 'char', 'ValueType', 'double');
            gVals     = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for g = 1:numel(gratingNames); gCount(gratingNames{g}) = 0; end
            nPres = 0; nStim = 0;

            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                if ~(isfield(j, 'document_class') && isfield(j.document_class, 'class_name') ...
                        && strcmp(j.document_class.class_name, 'stimulus_presentation'))
                    continue;
                end
                nPres = nPres + 1;
                if ~isfield(j, 'stimulus_presentation') ...
                        || ~isfield(j.stimulus_presentation, 'stimuli')
                    continue;
                end
                raw = j.stimulus_presentation.stimuli;
                stims = {};
                if isstruct(raw)
                    for i = 1:numel(raw); stims{end+1} = raw(i); end %#ok<AGROW>
                elseif iscell(raw)
                    stims = raw;
                end
                for i = 1:numel(stims)
                    s = stims{i};
                    if ~(isstruct(s) && isscalar(s) && isfield(s, 'parameters') ...
                            && isstruct(s.parameters) && isscalar(s.parameters))
                        continue;
                    end
                    nStim = nStim + 1;
                    p = s.parameters;
                    fns = sort(fieldnames(p));
                    key = strjoin(reshape(fns, 1, []), ',');
                    if isKey(fieldSets, key); fieldSets(key) = fieldSets(key) + 1; ...
                    else; fieldSets(key) = 1; end
                    for g = 1:numel(gratingNames)
                        gn = gratingNames{g};
                        if isfield(p, gn) && ~isempty(p.(gn))
                            gCount(gn) = gCount(gn) + 1;
                            v = p.(gn);
                            if isnumeric(v) && isscalar(v)
                                if isKey(gVals, gn); acc = gVals(gn); else; acc = []; end
                                acc(end+1) = v; %#ok<AGROW>
                                gVals(gn) = acc;
                            end
                        end
                    end
                end
            end

            fprintf('\n  STIMULUS-PARAMETER CENSUS (B, #31) -- report-only\n');
            fprintf(['    DENOMINATOR: %d stimulus_presentation, %d stimulus(i) ' ...
                     'with a scalar parameters struct\n'], nPres, nStim);
            fprintf('    distinct parameter field-name set(s): %d\n', fieldSets.Count);
            ksets = keys(fieldSets);
            counts = cell2mat(values(fieldSets));
            [~, ord] = sort(counts, 'descend');
            for i = 1:min(numel(ksets), 25)
                kk = ksets{ord(i)};
                fprintf('        %6d  {%s}\n', fieldSets(kk), kk);
            end
            fprintf('    grating-named field presence + value range:\n');
            anyGrating = false;
            for g = 1:numel(gratingNames)
                gn = gratingNames{g};
                if gCount(gn) == 0; continue; end
                anyGrating = true;
                if isKey(gVals, gn) && ~isempty(gVals(gn))
                    vv = gVals(gn);
                    fprintf('        %-20s present %6d   distinct-values %d   min %g   max %g\n', ...
                        gn, gCount(gn), numel(unique(vv)), min(vv), max(vv));
                else
                    fprintf('        %-20s present %6d   (non-numeric / non-scalar values)\n', ...
                        gn, gCount(gn));
                end
            end
            if ~anyGrating
                fprintf('        (no grating-named field present on any stimulus)\n');
            end

            verifyGreaterThan(testCase, nPres, 0, ...
                'no stimulus_presentation bodies read -- census describes nothing');
        end

    end
end

% ===================== harness ============================================

function tf = etaEnabled()
v = getenv('NDI_TEST_ETA');
tf = ~isempty(v) && ~any(strcmpi(v, {'0','false','no'}));
end

function corpusDir = ensureBCorpus()
%ENSUREBCORPUS Download (once) and extract B.zip.
%   The same B.zip DID-matlab's testCorpusB reads (~18 MB). Its 12,917 json
%   documents are byte-identical to the B half of Dab.zip.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/B.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-B');
corpusDir = fullfile(cacheRoot, 'B');
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, 'B.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
% Fallback: the zip may extract the json documents to cacheRoot directly, or
% under a differently-named single subdirectory. Find the directory that
% actually holds *.json and use it, rather than skipping on a name guess.
if ~isempty(dir(fullfile(cacheRoot, '*.json')))
    corpusDir = cacheRoot;
    return;
end
sub = dir(cacheRoot);
sub = sub([sub.isdir] & ~ismember({sub.name}, {'.','..'}));
for k = 1:numel(sub)
    candidate = fullfile(cacheRoot, sub(k).name);
    if ~isempty(dir(fullfile(candidate, '*.json')))
        corpusDir = candidate;
        return;
    end
end
error('ndi:corpus:noDir', ...
    'B.zip did not extract any directory holding *.json under %s', cacheRoot);
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the corpus, as JSON text.
%   `._` sidecars are macOS resource forks the zip carries; skipping them is
%   what did2.validate.sourceCensus's own reader does.
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end
end

function buildV1Sqlite(tmpFile, bodies)
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES.
%   The shape is `docs(doc_id, doc_idx, json_code, timestamp)` because that is
%   what did2.convert.readers.sqliteV1 issues (`SELECT json_code FROM docs`),
%   the same columns the real legacy backend writes.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
% BULK INSERT IN ONE TRANSACTION -- one fsync per row outside a transaction is
% pathological at scale (the Soph run #1 timeout). Throwaway fixture DB, so
% drop the per-write durability guarantees too.
mksqlite(dbid, 'PRAGMA synchronous = OFF');
mksqlite(dbid, 'PRAGMA journal_mode = MEMORY');
mksqlite(dbid, 'BEGIN TRANSACTION');
for k = 1:numel(bodies)
    docId = sprintf('id_%06d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
mksqlite(dbid, 'COMMIT');
end

function bodies = destinationBodies(dstPath)
%DESTINATIONBODIES Every document in the destination, as structs, read ONCE.
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
bodies = cell(1, numel(ids));
for k = 1:numel(ids)
    bodies{k} = db.get(ids{k}).toStruct();
end
end

function hits = findAllByClass(bodies, className)
hits = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if isfield(b,'document_class') && isfield(b.document_class,'class_name') ...
            && strcmp(b.document_class.class_name, className)
        hits{end+1} = b; %#ok<AGROW>
    end
end
end

function doc = findByClass(bodies, className)
doc = [];
hits = findAllByClass(bodies, className);
if ~isempty(hits); doc = hits{1}; end
end

function s = quarantineDiag(result)
if isempty(result.quarantine)
    s = ''; return;
end
n = numel(result.quarantine);
s = sprintf('%d document(s) quarantined; first %d:', n, min(5,n));
for i = 1:min(5,n)
    s = sprintf('%s\n    %s: %s', s, result.quarantine(i).class_name, ...
        result.quarantine(i).reason);
end
end

function s = resultDiag(result)
s = sprintf('[migrated %d, quarantined %d, edges %d] %s', ...
    result.summary.total, numel(result.quarantine), ...
    result.references.edges_examined, quarantineDiag(result));
end

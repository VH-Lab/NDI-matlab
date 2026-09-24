classdef TestMigrateLocalEtaSoph < matlab.unittest.TestCase
%TESTMIGRATELOCALETASOPH The Soph corpus through the WHOLE V_eta pipeline.
%
%   The THIRD corpus to get the PRED / 20211116 treatment, and by far the
%   largest: ~101,427 v1 documents (~446 MB compressed). Migrate the whole
%   corpus, open the result through ndi.session.dir, and read it back through
%   the object API -- with the ELEMENT ASSEMBLER exercised at Soph's scale
%   (~1,647 element documents, ~800x PRED: the first real workout for it).
%
%   WHY SOPH IS THE NEXT STEP. Corpus census run 32192718170 (2026-08-18,
%   post clock-alignment) measured Soph migrating CLEAN: 0 quarantine, and
%   every batch post-pass fully engaged -- epochMint 176, resolveSessionAnchors
%   folded 73,995 anchors to relative_reference, resolveResponseParameters
%   inlined 9,851 leaves -- and 0 ontology_table_row (the D10/D11 gap belongs
%   to Dab, not Soph). Almost all of Soph's volume flows through paths that
%   are already built and verified: the 12 vision calculators (id-preserving
%   1->1 fold) and the element assembler. Its only standing survivors are
%   DECLARED, not gaps: the SIGNED stimulus_response_scalar_parameters_basic
%   verify-before-delete deferral (#61, 11,167 husks) and the deferred
%   ingested-payload family (#66).
%
%   REPORT-ONLY ON THIS FIRST LANDING for the census + object-navigation
%   methods, DELIBERATELY. Soph's exact pass-1 unconverted set and final
%   survivor set are MEASURED here before they are asserted -- arming a gate
%   against a guessed 101k-document set would either pass vacuously or fail on
%   a persist-legitimate survivor. And unlike PRED / 20211116, Soph holds 33
%   sessions in one migrated database, so the multi-session read-back scoping
%   is measured before it is pinned. The no-quarantine / no-orphan arm, the
%   "the session opens on the did2sqlite backend" arm, and the calculator
%   id-preservation arm assert TODAY; the census + navigation-count arms land
%   once the printed sets are read from a real run.
%
%   SKIPS, NEVER FAILS, when the environment cannot support it: no mksqlite,
%   NDI_TEST_ETA unset, DID_SCHEMA_PATH unset, or the corpus will not
%   download. "Could not run" and "ran and found a defect" are different
%   results and must stay distinguishable.
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring container;
%   validation runs via CI.

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
                testCase.CorpusDir = ensureSophCorpus();
            catch ME
                assumeFail(testCase, sprintf( ...
                    'could not fetch the Soph corpus (%s); skipping.', ...
                    ME.message));
            end

            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));

            % PHASE TIMING. At Soph's scale (~101,427 documents) the setup is
            % where run #1 timed out, so each phase reports its wall-clock: a
            % future timeout is then localised from the log instead of guessed.
            t = tic;
            testCase.Bodies = readCorpusBodies(testCase.CorpusDir);
            fprintf('  [Soph timing] readCorpusBodies: %d docs in %.1f s\n', ...
                numel(testCase.Bodies), toc(t));
            t = tic;
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);
            fprintf('  [Soph timing] buildV1Sqlite: %.1f s\n', toc(t));

            t = tic;
            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
            fprintf('  [Soph timing] ndi.migrate.local: %.1f s\n', toc(t));
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
            % DENOMINATOR FIRST. A pass over zero documents quarantines zero
            % documents, and that reading prints the same digit as a clean
            % migration -- so the corpus size is asserted before anything else.
            verifyEqual(testCase, numel(testCase.Bodies), 101427, sprintf( ...
                ['the Soph corpus did not read as 101427 documents (got %d); ' ...
                 'every assertion here would be about a different corpus'], ...
                numel(testCase.Bodies)));
            verifyGreaterThan(testCase, testCase.Result.summary.total, 0, ...
                'the migration saw no documents at all');

            verifyEmpty(testCase, testCase.Result.quarantine, ...
                quarantineDiag(testCase.Result));

            % THE GRAPH CLOSES. Soph is the corpus that made this matter: a
            % DISSOLVED calculator loses its id and strands every downstream
            % reference -- the 11,448-orphan failure, measured on Soph. The
            % id-preserving 1->1 fold is what keeps this at zero.
            verifyEqual(testCase, testCase.Result.references.orphan_count, 0, ...
                sprintf('the migrated graph does not close: %d orphan(s). %s', ...
                    testCase.Result.references.orphan_count, ...
                    resultDiag(testCase.Result)));
            verifyGreaterThan(testCase, testCase.Result.references.edges_examined, 0, ...
                ['the reference sweep examined 0 edges, so its 0 orphans is a ' ...
                 'statement about the sweep and not about the corpus']);
        end

        function testEveryDocumentThatDidNotConvertDidSoDeliberately(testCase)
            % REPORT-ONLY ON THIS FIRST LANDING (see the class header). The
            % pass-1 conversion census names every class a single-document
            % migrator handed straight back; separating a deliberate deferral
            % from an accidental fall-through is done by declaring the set,
            % and that set is read from THIS run's output before it is pinned.
            % The denominator IS asserted -- a census that read nothing is the
            % silentLoss failure, and it must not masquerade as "all converted".
            s = testCase.Result.summary;

            fprintf(['\n  PASS-1 CONVERSION CENSUS (Soph)\n' ...
                     '    DENOMINATOR: %d document(s) read, %d migrated, ' ...
                     '%d quarantined\n' ...
                     '    unconverted (migrator returned its input): %d\n' ...
                     '    fragments (emitted, but hollow):           %d\n'], ...
                s.total, s.migrated_count, s.quarantine_count, ...
                s.unconverted_count, s.fragment_count);
            ndi.unittest.migrate.printClassTable(s.unconverted_by_class, '    unconverted');
            ndi.unittest.migrate.printClassTable(s.fragment_by_class,    '    fragment');

            verifyEqual(testCase, s.total, 101427, ...
                'the pass did not see 101427 documents; this figure is about a different corpus');

            % A FRAGMENT IS NEVER DELIBERATE. Unlike a passthrough it is a
            % document the migrator DID emit and that carries nothing -- the
            % failure did2.validate.isFragment exists to catch. Recorded 0 on
            % Soph in the census run; asserted here rather than assumed.
            verifyEqual(testCase, s.fragment_count, 0, sprintf( ...
                ['%d document(s) migrated to a FRAGMENT. A passthrough is a ' ...
                 'deferral; a fragment is silent loss.'], s.fragment_count));
        end

        function testNoV1DocumentSurvivesUnfoldedInTheFinalOutput(testCase)
            % THE BAR-2 INSTRUMENT, report-only on this first landing. The
            % census above counts what the single-document migrators did in
            % pass 1; it cannot see the SECOND PASSES that run afterward
            % (epochMint's armed folds, resolveResponseParameters,
            % resolveClockAlignment), so a class that reads "unconverted" there
            % can still reach its decided shape. The only sound test of "is
            % this corpus fully at decided shape" is the FINAL output: a v1
            % SOURCE class name that still labels a destination document did
            % not fold. Measured before it is asserted.
            src = testCase.Bodies;
            dst = destinationBodies(testCase.Result.destination);
            survivors = ndi.unittest.migrate.finalV1SurvivorCensus( ...
                reshape(src, 1, []), reshape(dst, 1, []));

            fprintf(['\n  BAR-2 FINAL-OUTPUT V1 SURVIVOR CENSUS (Soph)\n' ...
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
            verifyEqual(testCase, numel(src), 101427, ...
                'the source census did not read 101427 documents');
            verifyGreaterThan(testCase, numel(dst), 0, ...
                'the destination census read zero documents');
        end

        function testTheMigratedSessionOpensAndReadsBackThroughNDI(testCase)
            % THE HEADLINE. If this errors, nothing below it is meaningful.
            % Soph holds 33 sessions in ONE migrated database, so this opens
            % ONE of them (the first `session` document) and confirms NDI can
            % reach it on the did2sqlite backend. The per-session object COUNTS
            % are printed, not pinned, on this first landing: whether a query
            % scopes cleanly to one of 33 sessions is exactly what this run
            % measures. What IS asserted is that the session opens, the backend
            % chosen is the did2 one, and anything the object API returns is
            % the right TYPE -- zero-with-no-error is the pre-vintage symptom,
            % and a wrong type is a missed rename.
            assertTrue(testCase, isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            migrated = destinationBodies(testCase.Result.destination);
            sessionDoc = findByClass(migrated, 'session');
            assertNotEmpty(testCase, sessionDoc, ...
                'no `session` document in the migrated database');
            vlt.file.str2text( ...
                fullfile(testCase.SessionRoot, '.ndi', 'unique_reference.txt'), ...
                sessionDoc.base.session_id);

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

            fprintf(['\n  READ-BACK (one of Soph''s 33 session(s))\n' ...
                     '    daqsystem_load: %d object(s)\n' ...
                     '    getelements:    %d object(s)\n'], ...
                numel(devs), numel(els));
        end

        function testTheCalculatorFamilyKeepsItsIdentities(testCase)
            % SOPH'S HEADLINE FOLD. Soph is ~70% vision calculators, and the
            % 1->1 fold's whole point is that a calculator output keeps its
            % base.id so downstream references resolve. The orphan count above
            % is the systemic check; this one names the mechanism, so a
            % regression says WHICH property broke. Asserted (not report-only)
            % because id-preservation is decided, built, and previously green
            % on this exact corpus.
            srcIds = {};
            for k = 1:numel(testCase.Bodies)
                j = jsondecode(testCase.Bodies{k});
                cn = '';
                if isfield(j,'document_class') && isfield(j.document_class,'class_name')
                    cn = j.document_class.class_name;
                end
                if any(strcmp(cn, {'tuningcurve_calc','oridirtuning_calc', ...
                        'contrast_tuning_calc','spatial_frequency_tuning_calc', ...
                        'temporal_frequency_tuning_calc','speed_tuning_calc', ...
                        'contrast_sensitivity_calc','hartley_calc'}))
                    srcIds{end+1} = j.base.id; %#ok<AGROW>
                end
            end
            verifyNotEmpty(testCase, srcIds, ...
                'no calculator documents found in the Soph corpus to check');

            migrated = destinationBodies(testCase.Result.destination);
            dstIds = cellfun(@(d) string(d.base.id), migrated(:)');
            missing = srcIds(~ismember(string(srcIds), dstIds));
            verifyEmpty(testCase, missing, sprintf( ...
                ['%d of %d calculator id(s) are absent from the migrated set. ' ...
                 'A calculator that DISSOLVES loses its id and every downstream ' ...
                 'reference dangles -- the 11,448-orphan failure Soph is named ' ...
                 'for.'], numel(missing), numel(srcIds)));
        end

    end
end

% ===================== harness ============================================

function tf = etaEnabled()
v = getenv('NDI_TEST_ETA');
tf = ~isempty(v) && ~any(strcmpi(v, {'0','false','no'}));
end

function corpusDir = ensureSophCorpus()
%ENSURESOPHCORPUS Download (once) and extract Soph.zip.
%   Same URL shape and cache layout as the PRED / 20211116 helpers. The zip
%   is ~446 MB; the download and the migration together are why Soph is a
%   dispatched job rather than a per-push one.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Soph.zip';
cacheRoot = fullfile(tempdir(), 'ndi-corpus-Soph');
corpusDir = fullfile(cacheRoot, 'Soph');
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~isfolder(cacheRoot); mkdir(cacheRoot); end
zipPath = fullfile(cacheRoot, 'Soph.zip');
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
    'Soph.zip did not extract any directory holding *.json under %s', cacheRoot);
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
% BULK INSERT IN ONE TRANSACTION. Outside an explicit transaction every
% INSERT is its own implicit commit -- one fsync per row -- which is invisible
% at PRED/20211116 scale (<=1,220 rows) and pathological at Soph's ~101,427:
% run #1 (2026-08-19) timed out at 5h50m on exactly this loop while the same
% corpus migrates in a fraction of that on the DID side. This is a throwaway
% fixture DB, so also drop the per-write durability guarantees.
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

classdef TestMigrateLocalEtaSophReadSpeed < matlab.unittest.TestCase
%TESTMIGRATELOCALETASOPHREADSPEED Soph's read phases, before and after migration, one shard.
%
%   did-schema did_v2_go_forward_class_audit.md [read speed margin] (Jess
%   Haley, 2026-11-06) and [read speed check after getprobes] (2026-11-19;
%   VH-Lab/NDI-matlab#1266): every read step on every corpus inside
%   1.10 x v1 + 1 s, summed over the corpus's sessions. B and Dab run the
%   check inside their end-to-end tests. Soph cannot: ndi.migrate.local over
%   the whole of Soph (101,427 documents) takes 16,051 s (run 44482411325)
%   to 19,506 s (run 44606372766, cancelled at the 6-hour limit before its
%   read-back finished), so a whole-corpus migration leaves no room for a
%   second read of every session in one hosted job.
%
%   SHARDED AS DID-matlab SHARDS IT. test-eta-read-speed-soph.yml cuts Soph
%   into whole-session shards with DID-matlab's tools/shard_corpus.py
%   (sessions joined by a depends_on stay together; the union of the shards
%   is the corpus, each document in exactly one shard). Each job runs this
%   class over one shard: it migrates the shard, reads every session of it
%   before and after migration (ndi.unittest.migrate.readPhaseTimings, the
%   same five phases as B and Dab), asserts the denominators and that both
%   sides return the same objects, and writes the timings to
%   NDI_READ_SPEED_REPORT. The margin itself is applied to the CORPUS, not
%   to a shard: TestMigrateLocalEtaSophReadSpeedTotal sums every shard's
%   sessions and runs ndi.unittest.migrate.verifyReadPhases on the sum, the
%   check B and Dab run. Here the shard's own verdict is printed, not
%   enforced, so a shard's figure cannot pass for the corpus's.
%
%   WHAT A SHARD DOES NOT SEE: other sessions. Each side's database holds
%   only the shard's documents, so a session is read in a smaller database
%   than the whole migrated Soph; both sides are read from the same shard.
%
%   Environment:
%     NDI_SOPH_SHARD_DIR     the shard root shard_corpus.py wrote: Soph/*.json
%                            and Soph.sample.json (the manifest)
%     NDI_READ_SPEED_REPORT  the JSON file the timings are written to
%
%   SKIPS, NEVER FAILS, when it is not asked to run: no mksqlite,
%   NDI_TEST_ETA unset, DID_SCHEMA_PATH unset or NDI_SOPH_SHARD_DIR unset.
%   A shard root that is named and missing FAILS.

    properties
        ShardDir
        Manifest
        SessionRoot
        Result
        Bodies
    end

    methods (TestClassSetup)

        function gateAndMigrate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~ndi.unittest.migrate.envTrue('NDI_TEST_ETA')
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; skipping.');
            end
            testCase.ShardDir = char(getenv('NDI_SOPH_SHARD_DIR'));
            if isempty(testCase.ShardDir)
                assumeFail(testCase, 'NDI_SOPH_SHARD_DIR unset; skipping.');
            end
            manifestFile = fullfile(testCase.ShardDir, 'Soph.sample.json');
            testCase.assertTrue(isfile(manifestFile), sprintf( ...
                'NDI_SOPH_SHARD_DIR names %s, which holds no Soph.sample.json', ...
                testCase.ShardDir));
            testCase.Manifest = jsondecode(fileread(manifestFile));

            % DENOMINATOR FIRST: the shard holds what its manifest says
            t = tic;
            testCase.Bodies = readCorpusBodies(fullfile(testCase.ShardDir, 'Soph'));
            m = testCase.Manifest;
            fprintf(['  [Soph read speed] shard %d of %d: %d of %d document(s), ' ...
                '%d of %d session(s); read in %.1f s\n'], m.shard_index, m.shard_count, ...
                numel(testCase.Bodies), m.docs_in_corpus, m.sessions_kept, ...
                m.sessions_in_corpus, toc(t));
            testCase.assertEqual(numel(testCase.Bodies), m.docs_kept, ...
                'the shard folder does not hold the documents its manifest lists');
            testCase.assertGreaterThan(numel(testCase.Bodies), 0, 'the shard is empty');

            testCase.SessionRoot = tempname();
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));
            t = tic;
            buildV1Sqlite(fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite'), ...
                testCase.Bodies);
            fprintf('  [Soph read speed] buildV1Sqlite: %.1f s\n', toc(t));
            t = tic;
            testCase.Result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'did_v2', 'Backup', false);
            fprintf('  [Soph read speed] ndi.migrate.local: %.1f s\n', toc(t));
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

        function testReadPhasesOfTheShard(testCase)
            % A read of a shard that did not migrate cleanly would time a
            % different corpus: the migration's own figures first.
            testCase.assertEqual(testCase.Result.summary.total, numel(testCase.Bodies), ...
                'the migration did not read every document of the shard');
            testCase.assertEmpty(testCase.Result.quarantine, ...
                sprintf('%d document(s) of the shard quarantined', ...
                numel(testCase.Result.quarantine)));
            testCase.assertTrue(isfile(testCase.Result.destination), sprintf( ...
                'ndi.migrate.local reported destination %s and no file is there', ...
                testCase.Result.destination));

            T = ndi.unittest.migrate.readPhaseTimings(testCase.Bodies, ...
                fileparts(testCase.Result.destination), ...
                sprintf('Soph shard %d of %d', testCase.Manifest.shard_index, ...
                testCase.Manifest.shard_count), ...
                'Profile', ndi.unittest.migrate.envTrue('NDI_PROFILE_READS'));
            % the shard's own verdict, printed only: the margin is applied
            % to the corpus's sum (TestMigrateLocalEtaSophReadSpeedTotal)
            ndi.unittest.migrate.verifyReadPhases(testCase, T, 'Enforce', false);

            % written before anything is verified, so the total job sees
            % every shard that measured, and a failing shard is still read
            writeReport(T, testCase.Manifest, numel(testCase.Bodies));

            % DENOMINATORS: every session of the shard read, none raised
            nSessionDocs = numel(sessionIds(testCase.Bodies));
            testCase.verifyGreaterThan(numel(T.sessions), 0, ...
                'the read-speed check read no session of the shard');
            testCase.verifyEqual(numel(T.sessions), nSessionDocs, ...
                'the read did not open every session the shard holds');
            nErr = 0;
            for i = 1:numel(T.sessions)
                nErr = nErr + numel(T.sessions(i).errors);
            end
            testCase.verifyEqual(nErr, 0, 'a read phase raised, so its time cannot be compared');
            % the same objects on both sides, the probe map's duplicates of
            % existing probes included ([probes from the index keep v1's
            % duplicates], Jess Haley, 2026-11-10), as in B and Dab
            for i = 1:numel(T.sessions)
                c = T.sessions(i).counts;
                if isempty(fieldnames(c)); continue; end
                testCase.verifyEqual(c.v2.elements, c.v1.elements, ...
                    sprintf('session %s: getelements count', T.sessions(i).id));
                testCase.verifyEqual(c.v2.probes, c.v1.probes, ...
                    sprintf('session %s: getprobes count', T.sessions(i).id));
            end
        end

    end
end

% ===================== harness ============================================

function writeReport(T, manifest, nBodies)
%WRITEREPORT The shard's timings, as JSON, for the corpus total.
%   Per session: id, reference, the seconds of each phase on each side (a
%   phase that raised is NaN and is written as null), the counts and the
%   errors. The shard's manifest figures ride along as the denominators.
out = char(getenv('NDI_READ_SPEED_REPORT'));
if isempty(out)
    fprintf('  [Soph read speed] NDI_READ_SPEED_REPORT unset; no report written\n');
    return;
end
sessions = cell(1, numel(T.sessions));
for i = 1:numel(T.sessions)
    s = T.sessions(i);
    sessions{i} = struct('id', s.id, 'reference', s.reference, 'v1', s.v1, ...
        'v2', s.v2, 'counts', s.counts, 'errors', {reshape(s.errors, 1, [])});
end
R = struct('corpus', 'Soph', 'shard_index', manifest.shard_index, ...
    'shard_count', manifest.shard_count, 'docs_in_corpus', manifest.docs_in_corpus, ...
    'docs_kept', manifest.docs_kept, 'docs_read', nBodies, ...
    'sessions_in_corpus', manifest.sessions_in_corpus, ...
    'kept_files_sha256', manifest.kept_files_sha256, 'phases', {T.phases}, ...
    'sessions', {sessions});
folder = fileparts(out);
if ~isempty(folder) && ~isfolder(folder); mkdir(folder); end
fid = fopen(out, 'w');
closeIt = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(R, 'PrettyPrint', true));
fprintf('  [Soph read speed] %d session(s) written to %s\n', numel(sessions), out);
end

function sids = sessionIds(bodies)
% the distinct session ids of the shard's `session` documents: the sessions
% readPhaseTimings opens
sids = {};
for k = 1:numel(bodies)
    b = jsondecode(char(bodies{k}));
    if isfield(b, 'document_class') && strcmp(b.document_class.class_name, 'session')
        sids{end+1} = char(b.base.session_id); %#ok<AGROW>
    end
end
sids = unique(sids);
end

function bodies = readCorpusBodies(corpusDir)
%READCORPUSBODIES Every v1 document in the shard, as JSON text.
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
%BUILDV1SQLITE A did_v1 sqlite database holding BODIES (as TestMigrateLocalEtaSoph builds it).
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
mksqlite(dbid, 'PRAGMA synchronous = OFF');
mksqlite(dbid, 'PRAGMA journal_mode = MEMORY');
mksqlite(dbid, 'BEGIN TRANSACTION');
for k = 1:numel(bodies)
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        sprintf('id_%06d', k), k, bodies{k}, 0);
end
mksqlite(dbid, 'COMMIT');
end

classdef TestMigrateLocal < matlab.unittest.TestCase
%TESTMIGRATELOCAL Unit tests for ndi.migrate.local.
%
%   Builds a synthetic NDI session tree on the fly (a directory with
%   a .ndi/ subdirectory holding either a v1 did-sqlite database or a
%   matlabdumbjsondb file set), runs ndi.migrate.local against it, and
%   inspects the resulting sqlite, the backup, the quarantine sidecar,
%   the lock semantics, and the idempotency fast pass.
%
%   Every call but testDefaultTargetIsVeta's explicit one relies on the
%   DEFAULT TargetVersion, 'V_eta' (the only value accepted), so these tests run the
%   V_eta path: +migrators_j in pass 1 and the second pass.
%
%   Tests run with Validate=false so the test runner does not need a
%   checked-out did-schema tree next to it. The mksqlite gate lives in
%   TestClassSetup; if mksqlite is missing the whole file is skipped.

    properties
        SessionRoot   % char, absolute path to a per-test session tree
    end

    methods (TestClassSetup)
        function gateOnMksqlite(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, ...
                    'mksqlite is not on the MATLAB path; skipping ndi.migrate.local tests.');
            end
        end
    end

    methods (TestMethodSetup)
        function makeFreshSession(testCase)
            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));
        end
    end

    methods (TestMethodTeardown)
        function cleanupSession(testCase)
            try
                if isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testDefaultTargetIsVeta(testCase)
            % ndi.migrate.local migrates to V_eta unless asked otherwise
            % (VH-Lab/NDI-matlab#804): it writes V_eta.sqlite and runs the
            % V_eta second pass, whose report is carried on the result.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            result = ndi.migrate.local(testCase.SessionRoot, 'Validate', false);

            [~, name, ext] = fileparts(result.destination);
            verifyEqual(testCase, [name ext], 'V_eta.sqlite');
            verifyTrue(testCase, isfile(fullfile(testCase.SessionRoot, '.ndi', 'V_eta.sqlite')));
            % result.secondPass exists on every target, but its reports are
            % [] unless the V_eta second pass ran; the strain pass reports
            % its denominator whenever it is handed documents
            verifyNotEmpty(testCase, result.secondPass.strainAssembly, ...
                'the V_eta second pass did not run on the default target');
            verifyGreaterThan(testCase, result.secondPass.strainAssembly.documents_inspected, 0);

            % the default is declared, not inferred from a file name
            explicit = ndi.migrate.local(testCase.SessionRoot, 'Validate', false, ...
                'TargetVersion', 'V_eta');
            verifyTrue(testCase, explicit.alreadyMigrated, ...
                'an explicit V_eta run finds the default run''s V_eta.sqlite');
        end

        function testAnyOtherTargetIsRefused(testCase)
            % V_eta is the only target. Asking for another is an argument
            % error, before anything is read.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});
            verifyError(testCase, @() ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false, 'TargetVersion', 'V_none'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testMigratesV1SqliteToVEta(testCase)
            % Round-trip a synthetic v1 sqlite store: produces the
            % V_eta sqlite file with one row per source doc.
            bodies = { ...
                jsonencode(makeV1Body('alpha')), ...
                jsonencode(makeV1Body('beta')), ...
                jsonencode(makeV1Body('gamma'))};
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, bodies);

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);

            verifyEqual(testCase, result.summary.total, 3);
            verifyEqual(testCase, result.summary.migrated_count, 3);
            verifyEqual(testCase, result.summary.quarantine_count, 0);
            verifyEqual(testCase, result.source.kind, 'sqlite');
            verifyTrue(testCase, result.wroteDestination);
            verifyFalse(testCase, result.alreadyMigrated);
            verifyTrue(testCase, isfile(result.destination));

            db = did2.database.sqlitedb(result.destination);
            cleanup = onCleanup(@() db.close()); %#ok<NASGU>
            verifyEqual(testCase, db.count(), 3);
        end

        function testMigratesDumbJsonDb(testCase)
            % Round-trip a synthetic dumbjsondb store under .ndi.
            ndiDir = fullfile(testCase.SessionRoot, '.ndi');
            writeDumbJsonDoc(ndiDir, 'id_alpha', 0, ...
                jsonencode(makeV1Body('alpha')));
            writeDumbJsonDoc(ndiDir, 'id_beta', 0, ...
                jsonencode(makeV1Body('beta')));

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);

            verifyEqual(testCase, result.source.kind, 'dumbjsondb');
            verifyEqual(testCase, result.summary.migrated_count, 2);
            db = did2.database.sqlitedb(result.destination);
            cleanup = onCleanup(@() db.close()); %#ok<NASGU>
            verifyEqual(testCase, db.count(), 2);
        end

        function testBackupCreatedByDefault(testCase)
            % Backup option defaults to true and copies .ndi/ to
            % <path>/.v1-backup/ before migrating.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);

            verifyTrue(testCase, result.backup.created);
            verifyTrue(testCase, isfolder(result.backup.path));
            verifyTrue(testCase, isfile(fullfile(result.backup.path, ...
                'did-sqlite.sqlite')));
        end

        function testBackupSkippedWhenDisabled(testCase)
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false, 'Backup', false);

            verifyFalse(testCase, result.backup.created);
            verifyFalse(testCase, isfolder(result.backup.path));
        end

        function testDryRunWritesNothing(testCase)
            % DryRun must not touch the V_eta file, the backup,
            % or the quarantine sidecar.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false, 'DryRun', true);

            verifyTrue(testCase, result.dryRun);
            verifyFalse(testCase, result.wroteDestination);
            verifyFalse(testCase, isfile(result.destination));
            verifyFalse(testCase, isfolder(result.backup.path));
            verifyEqual(testCase, result.summary.migrated_count, 1);
        end

        function testIdempotentSecondRunIsFastPass(testCase)
            % After a successful migration, re-running uses the
            % V_eta file as the source (alreadyMigrated=true) and
            % does not re-write it or re-create the backup.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            first = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);
            verifyTrue(testCase, first.wroteDestination);

            second = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);
            verifyTrue(testCase, second.alreadyMigrated);
            verifyFalse(testCase, second.wroteDestination);
            verifyFalse(testCase, second.backup.created);
            verifyEqual(testCase, second.summary.migrated_count, 1);
        end

        function testQuarantineWrittenForMalformedDoc(testCase)
            % One good body + one malformed body: the migrated count
            % is 1, the quarantine count is 1, and the sidecar file
            % is written next to the V_eta sqlite.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, ...
                {jsonencode(makeV1Body('alpha')), 'not json {'});

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);

            verifyEqual(testCase, result.summary.total, 2);
            verifyEqual(testCase, result.summary.migrated_count, 1);
            verifyEqual(testCase, result.summary.quarantine_count, 1);
            verifyTrue(testCase, isfile(result.quarantineFile));

            text = fileread(result.quarantineFile);
            decoded = jsondecode(text);
            verifyEqual(testCase, numel(decoded), 1);
        end

        function testContinueOnErrorFalseRaisesAfterQuarantine(testCase)
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, ...
                {jsonencode(makeV1Body('alpha')), 'not json {'});

            verifyError(testCase, ...
                @() ndi.migrate.local(testCase.SessionRoot, ...
                    'Validate', false, 'ContinueOnError', false), ...
                'NDI:migrate:hadQuarantine');
        end

        function testLockHeldRejectsConcurrentRun(testCase)
            % A pre-existing lock file simulates a concurrent run;
            % the second call must error with NDI:migrate:locked.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});
            lockFile = fullfile(testCase.SessionRoot, '.ndi', '.migrate.lock');
            fid = fopen(lockFile, 'w'); fclose(fid);

            verifyError(testCase, ...
                @() ndi.migrate.local(testCase.SessionRoot, ...
                    'Validate', false), ...
                'NDI:migrate:locked');
        end

        function testLockReleasedAfterRun(testCase)
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            ndi.migrate.local(testCase.SessionRoot, 'Validate', false);

            lockFile = fullfile(testCase.SessionRoot, '.ndi', '.migrate.lock');
            verifyFalse(testCase, isfile(lockFile));
        end

        function testBadPathErrors(testCase)
            verifyError(testCase, ...
                @() ndi.migrate.local('/this/path/should/not/exist'), ...
                'NDI:migrate:badPath');
        end

        function testNoNdiDirErrors(testCase)
            emptyRoot = tempname();
            mkdir(emptyRoot);
            cleanup = onCleanup(@() rmdir(emptyRoot, 's')); %#ok<NASGU>
            verifyError(testCase, ...
                @() ndi.migrate.local(emptyRoot), ...
                'NDI:migrate:noNdiDir');
        end

        function testNoV1SourceErrors(testCase)
            % .ndi exists but contains nothing recognizable.
            verifyError(testCase, ...
                @() ndi.migrate.local(testCase.SessionRoot), ...
                'NDI:migrate:noV1Source');
        end

        function testReferencesReported(testCase)
            % depends_on edge pointing at a non-existent id surfaces
            % as an orphan in the references report (no quarantine).
            %
            % The batch carries its `session` document, as a real session
            % directory does (ndi.session.dir persists one on first open). On
            % did-schema #88 base.session_id is a `session_id` EDGE to the
            % session entity, whose base.id IS the session id
            % (V_eta_relation_inheritance_plan.md item 4), so every document
            % carries one more edge -- and without the session document every
            % one of them would be an orphan. The ONE orphan is the parent_id.
            session = makeV1Session();
            good = makeV1Body('alpha');
            orphan = makeV1Body('beta');
            orphan.depends_on = struct( ...
                'name',  'parent_id', ...
                'value', 'deadbeefdeadbeef_0000111122223333');
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(session), jsonencode(good), ...
                jsonencode(orphan)});

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', false);

            verifyEqual(testCase, result.summary.migrated_count, 3);
            verifyEqual(testCase, result.references.orphan_count, 1);
            sessionEdges = 0;
            if ndi.v2.sessionIdIsEdge()
                sessionEdges = 3;     % one per document, the session's own included
            end
            verifyEqual(testCase, result.references.edges_examined, 1 + sessionEdges);
        end
    end
end

% ---- helpers --------------------------------------------------------------

function body = makeV1Body(name)
body = struct();
body.document_class = struct( ...
    'class_name',    'demo_a', ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct( ...
    'id',         ['aabb1122ccdd3344_' pad16(name)], ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       name, ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
body.demo_a = struct('marker', name);
end

function body = makeV1Session()
% the did_v1 `session` document ndi.session.dir writes: base.session_id is
% the session id (makeV1Body's), session.reference its name
body = struct();
body.document_class = struct( ...
    'class_name',    'session', ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct( ...
    'id',         'aabb1122ccdd3344_5e55100000000000', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'session', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
body.session = struct('reference', 'test_session');
end

function s = pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end

function buildV1Sqlite(tmpFile, bodies)
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    docId = sprintf('id_%04d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
end

function writeDumbJsonDoc(dir, docId, version, body)
filename = sprintf('Object_id_%s_v%s.json', docId, dec2hex(version, 5));
fullPath = fullfile(dir, filename);
fid = fopen(fullPath, 'w');
fwrite(fid, body, 'char');
fclose(fid);
try fileattrib(fullPath, '+r'); catch, end
end

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

        function testDefaultTargetIsDidV2(testCase)
            % ndi.migrate.local migrates to the V2 set unless asked otherwise
            % (VH-Lab/NDI-matlab#804). The set is 'did_v2' and its database
            % file did_v2.sqlite ([schema set renamed did_v2], [V2 database
            % file renamed], Jess Haley, 2026-10-25 and 2026-11-01); the V2
            % second pass runs and its report is carried on the result.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});

            result = ndi.migrate.local(testCase.SessionRoot, 'Validate', false);

            [~, name, ext] = fileparts(result.destination);
            verifyEqual(testCase, [name ext], 'did_v2.sqlite');
            verifyTrue(testCase, isfile(fullfile(testCase.SessionRoot, '.ndi', 'did_v2.sqlite')));
            verifyFalse(testCase, isfile(fullfile(testCase.SessionRoot, '.ndi', 'V_eta.sqlite')), ...
                'a new migration wrote the earlier file name');
            % result.secondPass exists on every target, but its reports are
            % [] unless the V2 second pass ran; the strain pass reports
            % its denominator whenever it is handed documents
            verifyNotEmpty(testCase, result.secondPass.strainAssembly, ...
                'the V2 second pass did not run on the default target');
            verifyGreaterThan(testCase, result.secondPass.strainAssembly.documents_inspected, 0);

            % the default is declared, not inferred from a file name
            explicit = ndi.migrate.local(testCase.SessionRoot, 'Validate', false, ...
                'TargetVersion', 'did_v2');
            verifyTrue(testCase, explicit.alreadyMigrated, ...
                'an explicit did_v2 run finds the default run''s did_v2.sqlite');

            % the set's earlier name is still accepted: the same set
            renamed = ndi.migrate.local(testCase.SessionRoot, 'Validate', false, ...
                'TargetVersion', 'V_eta');
            verifyTrue(testCase, renamed.alreadyMigrated, ...
                'a V_eta run finds the did_v2 run''s database: the same set');
            [~, name, ext] = fileparts(renamed.destination);
            verifyEqual(testCase, [name ext], 'did_v2.sqlite');
        end

        function testAnExistingVetaDatabaseIsStillOpened(testCase)
            % [V2 database file renamed]: NDI still opens an existing
            % V_eta.sqlite. A session migrated before the rename is found
            % by a re-run (which continues it, under its own name) and by
            % the database hierarchy, and no did_v2.sqlite is made beside it.
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(makeV1Body('alpha'))});
            first = ndi.migrate.local(testCase.SessionRoot, 'Validate', false);
            ndiDir = fullfile(testCase.SessionRoot, '.ndi');
            movefile(first.destination, fullfile(ndiDir, 'V_eta.sqlite'));

            verifyEqual(testCase, ...
                ndi.database.implementations.database.did2sqlite.FILEIN(ndiDir), ...
                fullfile(ndiDir, 'V_eta.sqlite'));
            again = ndi.migrate.local(testCase.SessionRoot, 'Validate', false);
            verifyTrue(testCase, again.alreadyMigrated, ...
                'a re-run did not find the existing V_eta.sqlite');
            [~, name, ext] = fileparts(again.destination);
            verifyEqual(testCase, [name ext], 'V_eta.sqlite');
            verifyFalse(testCase, isfile(fullfile(ndiDir, 'did_v2.sqlite')), ...
                'a re-run made a second database beside the existing one');

            db = ndi.database.fun.opendatabase(ndiDir, 'ref');
            verifyClass(testCase, db, 'ndi.database.implementations.database.did2sqlite');
            verifyEqual(testCase, db.database_filename, fullfile(ndiDir, 'V_eta.sqlite'));
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
            %
            % The `session` document is migrated by DID-matlab's session
            % migrator, which builds an `entity` with did2.build, so this test
            % needs a V_eta schema set; without one that document is
            % quarantined (did2:schema:missingClass) and two of three migrate.
            % test-eta-migrate-e2e.yml runs this class with the schema.
            testCase.assumeTrue(~isempty(which('did2.schema.cache')) && ...
                did2.schema.cache.shared().hasClass('entity'), ...
                'no V_eta schema set (did-schema #88, `entity`) where did2.schema.cache looks');
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
            % The two demo_a documents have no migrator and no step changes
            % them, so they are carried as v1 documents, stamped 'did_v1'
            % (Decided by Jess Haley, 2026-10-24 [passthrough stays v1: how]):
            % a v1 body records its session in the base.session_id FIELD, not
            % as an edge. Only the migrated session entity carries the edge.
            verifyEqual(testCase, result.summary.carried_as_v1, 2);
            sessionEdges = 0;
            if ndi.v2.sessionIdIsEdge()
                sessionEdges = 1;     % the session's own; the v1 documents carry a field
            end
            verifyEqual(testCase, result.references.edges_examined, 1 + sessionEdges);
        end

        % ---- the final v1 stamp ([passthrough stays v1: how]) --------------
        % Decided by Jess Haley, 2026-10-24 [passthrough stays v1] and
        % [passthrough stays v1: how], 2026-10-25 [document stamps]: a v1
        % document no migrator or pass changes stays a v1 document, judged at
        % the end of ndi.migrate.local, stamped 'did_v1', stored without V_eta
        % validation and counted.

        function testAnUnchangedDocumentIsCarriedAsItsV1Source(testCase)
            alpha = makeV1Body('alpha');      % demo_a: no migrator, no pass
            % a document pass 1 changes: the image_stack_parameters superclass
            % migrator drops its empty `timestamp` placeholder (this used a
            % `filter`, whose superclass migrator DID-matlab deleted:
            % [unreached superclass migrators deleted], Jess Haley, 2026-10-27)
            filt = makeV1Changed('lowpass');
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, {jsonencode(alpha), jsonencode(filt)});

            result = ndi.migrate.local(testCase.SessionRoot, 'Validate', false);

            verifyEqual(testCase, result.summary.quarantine_count, 0);
            verifyEqual(testCase, result.summary.migrated_count, 2);
            % the summary reports the count carried as v1, denominator first
            verifyEqual(testCase, result.summary.carried_as_v1, 1);
            verifyEqual(testCase, result.carriedAsV1.documents_inspected, 2);
            verifyEqual(testCase, result.carriedAsV1.passed_through_pass_one, 1);
            verifyEqual(testCase, result.carriedAsV1.carried_as_v1, 1);
            verifyEqual(testCase, {result.carriedAsV1.carried_by_class.class_name}, {'demo_a'});

            db = did2.database.sqlitedb(result.destination);
            cleanup = onCleanup(@() db.close()); %#ok<NASGU>
            [nV1, nTotal] = db.countV1();
            verifyEqual(testCase, [nV1, nTotal], [1, 2]);

            % the unchanged document IS its v1 source, plus the stamp
            expected = jsondecode(jsonencode(alpha));
            expected.document_class.schema_version = 'did_v1';
            got = db.get(alpha.base.id).toStruct();
            verifyTrue(testCase, isequaln(got, expected), ...
                'an unchanged document must be stored as its v1 source stamped did_v1');

            % the migrated document keeps its V2 stamp and its migrated shape
            gotF = db.get(filt.base.id).toStruct();
            verifyEqual(testCase, gotF.document_class.schema_version, did2.schema.v2Stamp());
            verifyFalse(testCase, isfield(gotF.image_stack_parameters, 'timestamp'));
            verifyEqual(testCase, gotF.image_stack_parameters.label, 'kept');
        end

        function testCarryUnchangedAsV1ReportsEveryOutcome(testCase)
            % The step on its own: one record carried, one changed after
            % pass 1, one absent at the end, one past the sources.
            a = makeV1Body('alpha');
            b = makeV1Body('beta');
            c = makeV1Body('gamma');
            r = did2.convert.v1_to_v2({a, b, c}, 'Validate', false);
            verifyEqual(testCase, numel(r.passthrough), 3);
            docs = r.migrated;
            % beta changed by a later step
            sb = docs{2}.toStruct();
            sb.demo_a.marker = 'changed later';
            docs{2} = did2.document(sb);
            % gamma removed by a later step
            docs(3) = [];
            rec = r.passthrough;
            rec(end+1) = rec(1);
            rec(end).input_index = 99;   % a transient body, not a source
            [out, rep] = ndi.migrate.internal.carryUnchangedAsV1(docs, rec, {a, b, c});
            verifyEqual(testCase, rep.documents_inspected, 2);
            verifyEqual(testCase, rep.passed_through_pass_one, 4);
            verifyEqual(testCase, rep.carried_as_v1, 1);
            verifyEqual(testCase, rep.changed_after_pass_one, 1);
            verifyEqual(testCase, rep.absent_at_end, 1);
            verifyEqual(testCase, rep.not_a_source, 1);
            verifyEqual(testCase, {rep.changed_by_class.class_name}, {'demo_a'});
            verifyEqual(testCase, [rep.changed_by_class.count], 1);
            verifyEqual(testCase, {rep.absent_by_class.class_name}, {'demo_a'});
            verifyEqual(testCase, rep.carried_as_v1 + rep.changed_after_pass_one ...
                + rep.absent_at_end + rep.not_a_source + rep.source_unreadable ...
                + rep.source_id_mismatch, rep.passed_through_pass_one);
            expected = a;
            expected.document_class.schema_version = 'did_v1';
            verifyTrue(testCase, isequaln(out{1}.toStruct(), expected));
            verifyEqual(testCase, out{2}.toStruct().document_class.schema_version, did2.schema.v2Stamp());
        end

        function testCarryUnchangedAsV1CountsSecondPassRows(testCase)
            % [carry register] (Jess Haley, 2026-10-26): a carried document a
            % second-pass step named is counted under the register row its
            % reason cites; the rest are counted apart, and the two sum to
            % carried_as_v1. A row for a document that is not carried counts
            % nowhere; the first row named for an id wins.
            a = makeV1Body('alpha');
            b = makeV1Body('beta');
            r = did2.convert.v1_to_v2({a, b}, 'Validate', false);
            rows = struct('id', {a.base.id, a.base.id, 'not-a-document'}, ...
                'row', {'carry-080', 'carry-083', 'carry-088'});
            [~, rep] = ndi.migrate.internal.carryUnchangedAsV1(r.migrated, ...
                r.passthrough, {a, b}, rows);
            verifyEqual(testCase, rep.carried_as_v1, 2);
            verifyEqual(testCase, rep.carried_with_second_pass_row, 1);
            verifyEqual(testCase, rep.carried_without_second_pass_row, 1);
            verifyEqual(testCase, {rep.carried_by_row.row}, {'carry-080'});
            verifyEqual(testCase, [rep.carried_by_row.count], 1);
            % without rows: nothing is attributed
            [~, rep0] = ndi.migrate.internal.carryUnchangedAsV1(r.migrated, ...
                r.passthrough, {a, b});
            verifyEqual(testCase, rep0.carried_with_second_pass_row, 0);
            verifyEqual(testCase, rep0.carried_without_second_pass_row, 2);
            verifyEmpty(testCase, rep0.carried_by_row);
        end

        function testADependentOfACarriedDocumentCountsUnderCarry064(testCase)
            % [dependents of a carried document carry] (Jess Haley,
            % 2026-10-26): a record whose `dependency` is itself carried as
            % v1 counts under carry-064; one whose dependency converted (or
            % is absent) keeps its own row.
            a = makeV1Body('alpha');
            b = makeV1Body('beta');
            r = did2.convert.v1_to_v2({a, b}, 'Validate', false);
            rows = struct('id', {a.base.id, b.base.id}, ...
                'row', {'carry-096', 'carry-096'}, ...
                'dependency', {b.base.id, 'not-a-document'});
            [~, rep] = ndi.migrate.internal.carryUnchangedAsV1(r.migrated, ...
                r.passthrough, {a, b}, rows);
            verifyEqual(testCase, rep.carried_with_second_pass_row, 2);
            got = containers.Map({rep.carried_by_row.row}, {rep.carried_by_row.count});
            verifyEqual(testCase, got('carry-064'), 1);
            verifyEqual(testCase, got('carry-096'), 1);
        end

        function testCarryRowOfReadsTheFirstTag(testCase)
            verifyEqual(testCase, ndi.migrate.internal.carryRowOf( ...
                '[carry-080] unplaced (carried as v1): x'), 'carry-080');
            verifyEqual(testCase, ndi.migrate.internal.carryRowOf( ...
                "a: [carry-092] cannot place y [carry-064]"), 'carry-092');
            verifyEqual(testCase, ndi.migrate.internal.carryRowOf('no tag'), '');
            verifyEqual(testCase, ndi.migrate.internal.carryRowOf(''), '');
        end
    end
end

% ---- helpers --------------------------------------------------------------

function body = makeV1Changed(name)
% a did_v1 document pass 1 changes: a class no migrator names, whose
% `image_stack_parameters` superclass block holds the template's empty
% `timestamp` placeholder, which DID-matlab's superclass migrator
% (+migrators_j/+super/image_stack_parameters) drops
body = makeV1Body(name);
body.document_class.class_name = 'some_unregistered_class';
body.document_class.superclasses = struct('class_name', ...
    {'base', 'image_stack_parameters'}, 'class_version', '1.0.0');
body = rmfield(body, 'demo_a');
body.some_unregistered_class = struct('foo', 'bar');
body.image_stack_parameters = struct('timestamp', [], 'label', 'kept');
end

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

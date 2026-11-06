classdef TestDatasetWriterV2 < matlab.unittest.TestCase
%TESTDATASETWRITERV2 a new ndi.dataset.dir writes the dataset's v2 record into a v2 database.
%
%   Jess Haley 2026-11-03 [v2 line reads and writes both] (did-schema
%   did_v2_go_forward_class_audit.md): a v1 database is written as v1, a v2
%   database as v2. When ndi.dataset.dir creates a dataset in a folder whose
%   database is v2 (did2) and holds no record yet, the dataset's own record
%   is the `dataset` entity whose id is the dataset's (session) id, with no
%   separate session record beside it, and the reference stays in
%   .ndi/reference.txt (TEAM-SIGN-OFF [relation inheritance], Jess Haley
%   2026-10-21, did-schema did_v2_relation_inheritance_plan.md). The entity
%   also carries the reference as its `local_identifier`, as a migrated
%   dataset's record carries its old reference (Decided by Jess Haley,
%   2026-11-06 [new dataset named by its reference], did-schema
%   did_v2_go_forward_class_audit.md). The dataset opens again from it, and a
%   v2 session can be added to it. A v1 database keeps the v1 `session`
%   document.
%
%   Filtered (never passed) when did2.build or a v2 schema with `entity` is
%   missing.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity` (did-schema #88)');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testAV1DatabaseKeepsTheV1SessionDocument(testCase)
            dsPath = fullfile(testCase.Dir, 'ds');
            mkdir(dsPath);
            D = ndi.dataset.dir('ds1', dsPath);
            testCase.assertFalse(isfile(fullfile(dsPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME())), ...
                'a new folder was given a v2 database; this test is about a v1 one');
            d = D.database_search(ndi.query('', 'isa', 'session'));
            testCase.verifyNumElements(d, 1, 'a v1 dataset holds one v1 session document');
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'session');
            testCase.verifyEqual(d{1}.document_properties.session.reference, 'ds1');
            testCase.verifyEqual(d{1}.session_id(), D.id(), ...
                'the session document is not in the dataset''s session');
            testCase.verifyEmpty(D.database_search(ndi.query('', 'isa', 'entity')), ...
                'a v1 database got v2 entities');
            testCase.verifyEqual(ndi.session.dir.directorytype(dsPath), 'dataset');

            D2 = ndi.dataset.dir(dsPath);
            testCase.verifyEqual(D2.id(), D.id());
            testCase.verifyEqual(D2.reference(), 'ds1');
        end

        function testAV2DatabaseGetsTheDatasetEntity(testCase)
            dsPath = fullfile(testCase.Dir, 'ds');
            dbFile = testCase.emptyV2Database(dsPath);

            D = ndi.dataset.dir('ds1', dsPath);
            testCase.assertFalse(isfile(fullfile(dsPath, '.ndi', 'did-sqlite.sqlite')), ...
                'the dataset was given a v1 database beside the v2 one');
            testCase.verifyEqual(D.reference(), 'ds1');

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(dbFile);
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.assertNumElements(stored, 1, sprintf( ...
                'expected the dataset''s one record (classes: %s)', strjoin(classes, ', ')));
            e = stored{1};
            testCase.verifyEqual(e.document_class.class_name, 'entity');
            testCase.verifyEqual(ndi.v2.kindOf(e), 'dataset');
            testCase.verifyEqual(e.base.id, D.id(), 'the dataset entity''s id is the dataset id');
            testCase.verifyEqual(ndi.v2.edgeIds(e, 'session_id'), {D.id()});
            testCase.verifyTrue(did2.schema.isV2Stamp(e), 'the dataset entity is stamped v2');
            testCase.verifyTrue(isfield(e.entity, 'local_identifier'), ...
                'the dataset entity has no local_identifier');
            testCase.verifyEqual(char(e.entity.local_identifier), 'ds1', ...
                'the dataset entity''s local_identifier is not the dataset''s reference');
            try
                did2.document(e).validate();
                ok = true;
                msg = '';
            catch ME
                ok = false;
                msg = ME.message;
            end
            testCase.verifyTrue(ok, ['the dataset entity does not validate: ' msg]);
            testCase.verifyEqual(strtrim(fileread(fullfile(dsPath, '.ndi', 'reference.txt'))), 'ds1');
            testCase.verifyEqual(ndi.session.dir.directorytype(dsPath), 'dataset');

            % it opens again from that record, writing nothing more
            D2 = ndi.dataset.dir(dsPath);
            testCase.verifyEqual(D2.id(), D.id());
            testCase.verifyEqual(D2.reference(), 'ds1');
            testCase.verifyNumElements(testCase.storedBodies(dbFile), 1, ...
                'reopening the dataset wrote another record');

            % and a v2 session can be added to it (ndi.dataset/addSessionV2
            % files it under the dataset entity)
            sPath = fullfile(testCase.Dir, 's1');
            mkdir(sPath);
            S = ndi.setup.V2.createSession(sPath, 's1');
            D2.add_ingested_session(S);
            [refs, ids] = D2.session_list();
            testCase.verifyTrue(any(strcmp(ids, S.id())), 'the added session is not listed');
            testCase.verifyTrue(any(strcmp(refs, 's1')));
            testCase.verifyFalse(any(strcmp(ids, D.id())), ...
                'the dataset''s own record is listed as a session');
        end

        function testANewDatasetRecordCarriesItsReference(testCase)
            % Decided by Jess Haley, 2026-11-06 [new dataset named by its
            % reference] (did-schema did_v2_go_forward_class_audit.md): a
            % brand-new dataset's record carries its reference as
            % local_identifier, as a migrated dataset's does; reference.txt
            % keeps the folder's reference as well.
            dsPath = fullfile(testCase.Dir, 'newds');
            dbFile = testCase.emptyV2Database(dsPath);
            ref = 'my_new_dataset_2026';
            D = ndi.dataset.dir(ref, dsPath);

            stored = testCase.storedBodies(dbFile);
            testCase.assertNumElements(stored, 1, 'expected the dataset''s one record');
            e = stored{1};
            testCase.assertEqual(ndi.v2.kindOf(e), 'dataset');
            testCase.verifyEqual(e.base.id, D.id());
            testCase.assertTrue(isfield(e.entity, 'local_identifier'), ...
                'the new dataset''s record has no local_identifier');
            testCase.verifyEqual(char(e.entity.local_identifier), ref, ...
                'the new dataset''s record does not carry its reference as local_identifier');
            testCase.verifyEqual(strtrim(fileread(fullfile(dsPath, '.ndi', 'reference.txt'))), ref, ...
                'reference.txt no longer holds the dataset''s reference');

            % reopened, the record and the reference are unchanged
            D2 = ndi.dataset.dir(dsPath);
            testCase.verifyEqual(D2.reference(), ref);
            stored2 = testCase.storedBodies(dbFile);
            testCase.verifyNumElements(stored2, 1, 'reopening the dataset wrote another record');
            testCase.verifyEqual(char(stored2{1}.entity.local_identifier), ref);
        end
    end

    methods
        function dbFile = emptyV2Database(~, folder)
            ndiDir = fullfile(folder, '.ndi');
            mkdir(ndiDir);
            dbFile = fullfile(ndiDir, ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
            db = did2.database.sqlitedb(dbFile);
            db.close();
        end

        function s = storedBodies(~, dbFile)
            db = did2.database.sqlitedb(dbFile);
            closer = onCleanup(@() db.close()); %#ok<NASGU>
            ids = db.allIds();
            s = cell(1, numel(ids));
            for k = 1:numel(ids)
                raw = db.get(ids{k});
                if iscell(raw)
                    raw = raw{1};
                end
                s{k} = raw.toStruct();
            end
        end
    end
end

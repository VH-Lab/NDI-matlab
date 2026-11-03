classdef TestDatasetWriterV2 < matlab.unittest.TestCase
%TESTDATASETWRITERV2 a new ndi.dataset.dir writes the dataset's V2 record into a V2 database.
%
%   Jess Haley 2026-11-03 [v2 line reads and writes both] (did-schema
%   did_v2_go_forward_class_audit.md): a v1 database is written as v1, a v2
%   database as v2. When ndi.dataset.dir creates a dataset in a folder whose
%   database is V2 (did2) and holds no record yet, the dataset's own record
%   is the `dataset` entity whose id is the dataset's (session) id, with no
%   separate session record beside it, and the reference stays in
%   .ndi/reference.txt (TEAM-SIGN-OFF [relation inheritance], Jess Haley
%   2026-10-21, did-schema did_v2_relation_inheritance_plan.md). It is the
%   bare dataset entity DID-matlab's migration writes for a dataset with no
%   metadata (+migrators_j/private/jBareDataset.m). The dataset opens again
%   from it, and a V2 session can be added to it. A v1 database keeps the v1
%   `session` document.
%
%   Filtered (never passed) when did2.build or a V2 schema with `entity` is
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
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
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
            testCase.assertFalse(isa(D.session.database, ...
                'ndi.database.implementations.database.did2sqlite'), ...
                'a new folder was given a V2 database; this test is about a v1 one');
            d = D.database_search(ndi.query('', 'isa', 'session'));
            testCase.verifyNumElements(d, 1, 'a v1 dataset holds one v1 session document');
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'session');
            testCase.verifyEqual(d{1}.document_properties.session.reference, 'ds1');
            testCase.verifyEqual(d{1}.id(), D.id(), 'the session document''s id is not the dataset id');
            testCase.verifyEmpty(D.database_search(ndi.query('', 'isa', 'entity')), ...
                'a v1 database got V2 entities');
            testCase.verifyEqual(ndi.session.dir.directorytype(dsPath), 'dataset');

            D2 = ndi.dataset.dir(dsPath);
            testCase.verifyEqual(D2.id(), D.id());
            testCase.verifyEqual(D2.reference(), 'ds1');
        end

        function testAV2DatabaseGetsTheDatasetEntity(testCase)
            dsPath = fullfile(testCase.Dir, 'ds');
            dbFile = testCase.emptyV2Database(dsPath);

            D = ndi.dataset.dir('ds1', dsPath);
            testCase.assertTrue(isa(D.session.database, ...
                'ndi.database.implementations.database.did2sqlite'), 'the dataset is not V2');
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
            testCase.verifyTrue(did2.schema.isV2Stamp(e), 'the dataset entity is stamped V2');
            testCase.verifyFalse(isfield(e.entity, 'local_identifier') && ...
                ~isempty(e.entity.local_identifier), ...
                'the folder''s reference was written into the dataset entity');
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

            % and a V2 session can be added to it (ndi.dataset/addSessionV2
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

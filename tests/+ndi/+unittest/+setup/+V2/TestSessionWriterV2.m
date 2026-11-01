classdef TestSessionWriterV2 < matlab.unittest.TestCase
%TESTSESSIONWRITERV2 ndi.session.dir writes a V2 session record into a V2 database.
%
%   When ndi.session.dir opens a folder whose database holds no session
%   record, it writes one. Into a V2 (did2) database it now writes the V2
%   record (an `entity` of type session whose id is the session id, as
%   ndi.setup.V2.createSession writes it), not a v1 `session` document
%   stamped did_v1. A v1 database keeps the v1 document.
%
%   Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
%   (did-schema did_v2_go_forward_class_audit.md): "the end state is that
%   every NDI writer writes V2 documents and a V2 session accepts only V2
%   documents".
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
        function testAV2DatabaseGetsTheV2SessionRecord(testCase)
            sid = ndi.ido.unique_id();
            ndiDir = fullfile(testCase.Dir, '.ndi');
            mkdir(ndiDir);
            dbFile = fullfile(ndiDir, ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
            % an empty V2 database: no session record in it
            db = did2.database.sqlitedb(dbFile);
            testCase.assertEmpty(db.allIds(), 'the V2 database starts empty');
            db.close();
            vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), sid);
            vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), 'ref1');

            S = ndi.session.dir(testCase.Dir);
            testCase.verifyEqual(S.id(), sid);
            testCase.verifyEqual(S.reference, 'ref1');

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(dbFile);
            testCase.assertNotEmpty(stored, 'ndi.session.dir wrote no session record');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(classes, 'session')), sprintf( ...
                'a v1 `session` document was written into a V2 database (classes: %s)', ...
                strjoin(classes, ', ')));
            isSessionEntity = cellfun(@(s) strcmp(s.document_class.class_name, 'entity') ...
                && strcmp(s.base.id, sid), stored);
            testCase.verifyEqual(nnz(isSessionEntity), 1, sprintf( ...
                'expected one session entity whose id is the session id (classes: %s)', ...
                strjoin(classes, ', ')));
            ent = stored{find(isSessionEntity, 1)};
            testCase.verifyTrue(did2.schema.isV2Stamp(ent), ...
                'the session entity is stamped V2 (not did_v1)');
            testCase.verifyEqual(char(ent.entity.local_identifier), 'ref1');

            % and it opens again from the record it wrote, writing nothing more
            n = numel(stored);
            S2 = ndi.session.dir(testCase.Dir);
            testCase.verifyEqual(S2.id(), sid);
            testCase.verifyEqual(S2.reference, 'ref1');
            testCase.verifyNumElements(testCase.storedBodies(dbFile), n, ...
                'reopening wrote another session record');
        end

        function testAV1DatabaseKeepsTheV1SessionDocument(testCase)
            % a new folder gets a v1 database (databasehierarchyinit entry 1)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(isfile(fullfile(testCase.Dir, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME())), ...
                'a new folder was given a V2 database; this test is about a v1 one');
            d = S.database_search(ndi.query('', 'isa', 'session'));
            testCase.verifyNumElements(d, 1, 'a v1 database holds one v1 session document');
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'session');
            testCase.verifyEqual(d{1}.document_properties.session.reference, 'ref1');
        end
    end

    methods
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

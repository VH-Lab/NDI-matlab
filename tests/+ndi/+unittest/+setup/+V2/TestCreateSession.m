classdef TestCreateSession < matlab.unittest.TestCase
%TESTCREATESESSION ndi.setup.V2.createSession makes a session NDI can open.
%
%   The point of the function is the round trip: a V2 (did2) database is
%   written, and the ordinary ndi.session.dir(PATH) then opens it with the
%   same id and reference, through the did2sqlite backend. Filtered (never
%   passed) when did2.build or a V2 schema with `study` is missing.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(fullfile(schemaPath, 'study.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `study`');
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
        function testRoundTrip(testCase)
            sid = ndi.ido.unique_id();
            session = ndi.setup.V2.createSession(testCase.Dir, 'day 22-02-01', ...
                'SessionId', sid);
            testCase.verifyEqual(session.id(), sid);
            testCase.verifyEqual(session.reference, 'day 22-02-01');
            testCase.verifyTrue(isfile(fullfile(testCase.Dir, '.ndi', 'V_eta.sqlite')));

            reopened = ndi.session.dir(testCase.Dir);
            testCase.verifyEqual(reopened.id(), sid);
            testCase.verifyEqual(reopened.reference, 'day 22-02-01');
            s = reopened.database_search(ndi.query('', 'isa', 'session'));
            testCase.verifyNumElements(s, 1);
            testCase.verifyEqual(s{1}.document_properties.session.local_identifier, 'day 22-02-01');
        end

        function testStudyRelationIsStoredInTheSession(testCase)
            study = ndi.ido.unique_id();
            [session, docs] = ndi.setup.V2.createSession(testCase.Dir, 'd1', ...
                'StudyIds', {study});
            testCase.verifyNumElements(docs, 2);
            rel = session.database_search(ndi.query('', 'isa', 'directed_relation'));
            testCase.verifyNumElements(rel, 1);
            r = rel{1}.document_properties;
            testCase.verifyEqual(r.directed_relation.relation.name, 'part_of');
            parent = r.depends_on(strcmp({r.depends_on.name}, 'parent_id'));
            testCase.verifyEqual(parent.document_id, study);
        end

        function testRefusesToOverwriteByDefault(testCase)
            ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.verifyError(@() ndi.setup.V2.createSession(testCase.Dir, 'd2'), ...
                'ndi:setup:V2:sessionExists');
            s = ndi.setup.V2.createSession(testCase.Dir, 'd2', 'Overwrite', true);
            testCase.verifyEqual(s.reference, 'd2');
        end

        function testWritesInBatches(testCase)
            % 1 session document + 4 relations, written 2 at a time, not
            % re-validated on insert: every document arrives, and the
            % batch count is what writeDocuments reports
            studies = arrayfun(@(~) ndi.ido.unique_id(), 1:4, 'UniformOutput', false);
            [session, docs] = ndi.setup.V2.createSession(testCase.Dir, 'd1', ...
                'StudyIds', studies, 'BatchSize', 2, 'Validate', false, 'Progress', true);
            testCase.verifyNumElements(docs, 5);
            testCase.verifyNumElements(session.database_search( ...
                ndi.query('', 'isa', 'directed_relation')), 4);

            file = fullfile(testCase.Dir, 'more.sqlite');
            stats = ndi.setup.V2.writeDocuments(file, docs, 'BatchSize', 2, 'Progress', false);
            testCase.verifyEqual([stats.documents, stats.batches, stats.files], [5, 3, 0]);
            db = did2.database.sqlitedb(file);
            testCase.verifyEqual(db.count(), 5);
            db.close();
        end
    end
end

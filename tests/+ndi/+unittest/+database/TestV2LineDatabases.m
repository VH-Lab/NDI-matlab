classdef TestV2LineDatabases < matlab.unittest.TestCase
%TESTV2LINEDATABASES On the V2 line a new session is V2 and a v1 database is read-only.
%
%   Decided by Jess Haley, 2026-11-03 (did-schema
%   did_v2_go_forward_class_audit.md):
%     [V2 branch writes V2 only] "We're on the v2 branch. That should write
%       v2 exclusively and read v1 and v2." A new session gets a V2 database.
%     [v1 database read-only on the v2 line] an existing v1 database opens
%       read-only: reading works, and any write is refused with an error that
%       names ndi.migrate.local; no database holds both v1 and v2 documents
%       written by the V2 line.
%
%   See also: ndi.database.fun.databasehierarchyinit,
%             ndi.database.implementations.database.didsqlite,
%             ndi.unittest.session.makeV1Session.

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            w = warning('off', 'NDI:V2:v1DocumentsPresent');
            testCase.addTeardown(@() warning(w));
        end
    end

    methods (Test)

        function testANewSessionHasAV2Database(testCase)
            S = ndi.session.dir('ref_new', testCase.Root);
            ndiDir = fullfile(testCase.Root, '.ndi');
            testCase.verifyTrue(isfile(fullfile(ndiDir, 'did_v2.sqlite')), ...
                'a new session did not get did_v2.sqlite');
            testCase.verifyFalse(isfile(fullfile(ndiDir, 'did-sqlite.sqlite')), ...
                'a new session got a v1 (did-sqlite) database');
            testCase.verifyTrue(S.writesV2(), 'a new session''s database is not V2');
            db = ndi.database.fun.opendatabase(ndiDir, S.id());
            testCase.verifyClass(db, 'ndi.database.implementations.database.did2sqlite');

            % its session record is the V2 one: an entity of type session
            % whose id is the session id, and nothing in it is v1
            rec = ndi.v2.sessionRecord(S, S.id());
            testCase.assertNumElements(rec, 1);
            testCase.verifyEqual(ndi.v2.kindOf(rec{1}.document_properties), 'session');
            testCase.verifyEqual(rec{1}.id(), S.id());
            ids = db.alldocids();
            testCase.verifyNotEmpty(ids);
            for i = 1:numel(ids)
                p = db.read(ids{i}).document_properties;
                testCase.verifyTrue(did2.schema.isV2Stamp(p), ...
                    sprintf('document %s of a new session is not V2', ids{i}));
            end
            clear db

            % reopening it opens the same V2 database and adds no second record
            S2 = ndi.session.dir('ref_new', testCase.Root);
            testCase.verifyEqual(S2.id(), S.id());
            testCase.verifyNumElements(ndi.v2.sessionRecord(S2, S2.id()), 1);
        end

        function testAV1DatabaseIsReadAsStored(testCase)
            [sid, docs] = ndi.unittest.session.makeV1Session(testCase.Root, 'ref_v1', ...
                {ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '')});
            S = ndi.session.dir('ref_v1', testCase.Root);
            testCase.verifyEqual(S.id(), sid);
            testCase.verifyEqual(S.reference, 'ref_v1');
            testCase.verifyFalse(S.writesV2());
            got = S.database_search(ndi.query('base.id', 'exact_string', docs{2}.id(), ''));
            testCase.assertNumElements(got, 1);
            testCase.verifyEqual(got{1}.document_properties.subject.local_identifier, 'mouse@lab');
            testCase.verifyFalse(isfield(got{1}.document_properties.document_class, ...
                'schema_version'), 'a v1 document was stamped or converted on read');
            testCase.verifyFalse(isfile(fullfile(testCase.Root, '.ndi', 'did_v2.sqlite')), ...
                'opening a v1 session made a V2 database beside it (a mixed session)');
        end

        function testWritingToAV1DatabaseIsRefused(testCase)
            [~, docs] = ndi.unittest.session.makeV1Session(testCase.Root, 'ref_ro', ...
                {ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '')});
            S = ndi.session.dir('ref_ro', testCase.Root);
            n0 = numel(S.database_search(ndi.query('', 'isa', 'base')));
            testCase.assertEqual(n0, 2, 'the fixture holds the session document and the subject');

            v1doc = ndi.document('subject', 'subject.local_identifier', 'rat@lab', ...
                'subject.description', '') + S.newdocument();
            testCase.verifyError(@() S.database_add(v1doc), 'NDI:database:v1ReadOnly');
            v2doc = ndi.setup.V2.entityDocuments('organism', ...
                struct('local_identifier', 'rat@lab'), struct(), 'SessionId', S.id());
            testCase.verifyError(@() S.database_add(ndi.document(v2doc{1})), ...
                'NDI:database:v1ReadOnly', ...
                'a V2 document was written into a v1 database (a mixed database)');
            testCase.verifyError(@() S.database_rm(docs{2}.id()), 'NDI:database:v1ReadOnly');

            try
                S.database_add(v1doc);
                testCase.verifyFail('the write was not refused');
            catch err
                testCase.verifySubstring(err.message, 'ndi.migrate.local');
                testCase.verifySubstring(err.message, 'read-only');
            end

            S2 = ndi.session.dir('ref_ro', testCase.Root);
            testCase.verifyNumElements(S2.database_search(ndi.query('', 'isa', 'base')), n0, ...
                'a refused write changed the v1 database');
        end

    end
end

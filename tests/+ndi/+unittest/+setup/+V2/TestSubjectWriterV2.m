classdef TestSubjectWriterV2 < matlab.unittest.TestCase
%TESTSUBJECTWRITERV2 ndi.subject writes the V2 subject record into a V2 database.
%
%   Given the session it writes for, ndi.subject/newdocument writes, into a
%   V2 (did2) database, an `entity` of type organism whose id is the
%   subject's id (the shape DID-matlab's +migrators_j/subject.m writes for a
%   v1 `subject`), not a v1 `subject` document stamped did_v1. So does
%   ndi.subject.does_subjectstring_match_session_document, which ndi.element
%   calls to make a subject it is given by name, and it finds that record
%   again. A v1 database keeps the v1 document.
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
        function testNewdocumentOnAV2DatabaseIsTheV2Record(testCase)
            [S, dbFile] = testCase.v2Session();
            testCase.verifyTrue(S.writesV2(), 'the session does not report its V2 database');
            sub = ndi.subject('mouse23@nosuchlab.org', 'a test mouse');
            docs = sub.newdocument(S);
            S.database_add(docs);

            ent = testCase.onlySubject(dbFile, sub.id());
            testCase.verifyTrue(did2.schema.isV2Stamp(ent), ...
                'the subject entity is stamped V2 (not did_v1)');
            want = ndi.v2.vocabTerm('entity_type', 'organism');
            testCase.verifyEqual(char(ent.entity.type.name), char(want.name));
            testCase.verifyEqual(char(ent.entity.local_identifier), 'mouse23@nosuchlab.org');
            testCase.verifyEqual(char(ent.entity.name), 'mouse23@nosuchlab.org');
            testCase.verifyEqual(char(ent.entity.notes), 'a test mouse');
            testCase.verifyEqual(char(ndi.v2.sessionIdOf(ent)), S.id(), ...
                'the subject is in the session it was written for');
        end

        function testMadeByNameOnAV2DatabaseAndFoundAgain(testCase)
            [S, dbFile] = testCase.v2Session();
            [b, sid] = ndi.subject.does_subjectstring_match_session_document(S, ...
                'rat7@nosuchlab.org', 0);
            testCase.verifyFalse(logical(b), 'no subject is there before it is made');
            testCase.verifyEmpty(sid);

            [b, sid] = ndi.subject.does_subjectstring_match_session_document(S, ...
                'rat7@nosuchlab.org', 1);
            testCase.verifyTrue(logical(b));
            ent = testCase.onlySubject(dbFile, sid);
            testCase.verifyEqual(char(ent.entity.local_identifier), 'rat7@nosuchlab.org');
            n = numel(testCase.storedBodies(dbFile));

            [b2, sid2] = ndi.subject.does_subjectstring_match_session_document(S, ...
                'rat7@nosuchlab.org', 1);
            testCase.verifyTrue(logical(b2));
            testCase.verifyEqual(sid2, sid, 'the V2 subject was not found by its local identifier');
            testCase.verifyNumElements(testCase.storedBodies(dbFile), n, ...
                'finding the subject again wrote another document');
        end

        function testAV1DatabaseKeepsTheV1SubjectDocument(testCase)
            % a new folder gets a v1 database (databasehierarchyinit entry 1)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.verifyFalse(S.writesV2(), 'a new folder was given a V2 database');
            sub = ndi.subject('mouse23@nosuchlab.org', 'a test mouse');
            d = sub.newdocument(S);
            testCase.verifyClass(d, 'ndi.document');
            testCase.verifyEqual(d.document_properties.document_class.class_name, 'subject');
            S.database_add(d);
            [b, sid] = ndi.subject.does_subjectstring_match_session_document(S, ...
                'mouse23@nosuchlab.org', 0);
            testCase.verifyTrue(logical(b));
            testCase.verifyEqual(sid, sub.id());
            % with no session, newdocument is the v1 document, as before
            d0 = sub.newdocument();
            testCase.verifyEqual(d0.document_properties.document_class.class_name, 'subject');
        end
    end

    methods
        function [S, dbFile] = v2Session(testCase)
            sid = ndi.ido.unique_id();
            ndiDir = fullfile(testCase.Dir, '.ndi');
            mkdir(ndiDir);
            dbFile = fullfile(ndiDir, ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
            db = did2.database.sqlitedb(dbFile);
            db.close();
            vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), sid);
            vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), 'ref1');
            S = ndi.session.dir(testCase.Dir);
            testCase.assertEqual(S.id(), sid);
        end

        function ent = onlySubject(testCase, dbFile, id)
            % DENOMINATOR FIRST: what the database holds
            stored = testCase.storedBodies(dbFile);
            testCase.assertNotEmpty(stored, 'the V2 database holds nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(classes, 'subject')), sprintf( ...
                'a v1 `subject` document was written into a V2 database (classes: %s)', ...
                strjoin(classes, ', ')));
            hit = cellfun(@(s) strcmp(s.base.id, id), stored);
            testCase.assertEqual(nnz(hit), 1, sprintf( ...
                'expected one document with the subject''s id (classes: %s)', ...
                strjoin(classes, ', ')));
            ent = stored{find(hit, 1)};
            testCase.assertEqual(ent.document_class.class_name, 'entity');
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

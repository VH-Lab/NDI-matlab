classdef TestV1WriteIntoV2Session < matlab.unittest.TestCase
%TESTV1WRITEINTOV2SESSION A v1 document NDI writes into a V2 session is stamped did_v1 and template-checked.
%
%   Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
%   (did-schema schemas/V_eta_go_forward_class_audit.md): "for now, a
%   v1-template document NDI writes into a session with a V2 database is
%   stamped did_v1 and checked against NDI's own v1 template, as a carried
%   document is". ndi.database.implementations.database.did2sqlite/do_add
%   does it through ndi.database.internal.stampV1Write.
%
%   Each test writes through ndi.session/database_add into a session made
%   by ndi.setup.V2.createSession (a did2 database, V_eta.sqlite), then
%   reads the STORED body back with did2.database.sqlitedb, so the stamp
%   asserted is the one on disk, not the one on the object handed in.
%
%   Filtered (never passed) when did2.build, did2.validate.v1Document or a
%   V2 schema with `entity` is missing.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
        Session
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            testCase.assumeTrue(~isempty(which('did2.validate.v1Document')), ...
                'did2.validate.v1Document (DID-matlab #270) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(fullfile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
        end
    end

    methods (TestMethodSetup)
        function makeSession(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            testCase.Session = ndi.setup.V2.createSession(testCase.Dir, 'd1');
        end
    end

    methods (Test)
        function testTheTemplatesAreRead(testCase)
            % DENOMINATOR FIRST: a check that read no template checks nothing
            T = ndi.database.internal.v1TemplateIndex();
            testCase.assertTrue(T.present, sprintf( ...
                'no NDI v1 template was read (root "%s")', T.root));
            testCase.verifyGreaterThan(T.count, 0);
            testCase.verifyTrue(isKey(T.byClass, 'sorting_parameters'), ...
                'NDI''s spike sorter template sorting_parameters is not in the index');
        end

        function testASpikeSorterDocumentIsStoredStampedV1(testCase)
            % the document ndi.app.spikesorter writes for its parameters
            % (ndi.document('sorting_parameters', ...)): a v1 template, with
            % the app block of its app.json superclass
            d = ndi.document('sorting_parameters', ...
                'base.name', 'a sorting', ...
                'base.session_id', testCase.Session.id());
            testCase.assertEmpty(did2.schema.stampOf(d.document_properties), ...
                'a v1 writer''s document arrives unstamped');

            testCase.Session.database_add(d);

            stored = testCase.storedBody(d.id());
            testCase.verifyEqual(did2.schema.stampOf(stored), 'did_v1', ...
                'the v1 document is stored stamped did_v1');
            testCase.verifyEqual(stored.document_class.class_name, 'sorting_parameters');
            testCase.verifyEqual(stored.sorting_parameters, ...
                d.document_properties.sorting_parameters, ...
                'nothing but the stamp changed');
            testCase.verifyEqual(stored.base.name, 'a sorting');

            % and NDI reads it back
            found = testCase.Session.database_search( ...
                ndi.query('base.id', 'exact_string', d.id(), ''));
            testCase.verifyNumElements(found, 1);
            testCase.verifyEqual(found{1}.document_properties.sorting_parameters, ...
                d.document_properties.sorting_parameters);
        end

        function testAMalformedV1DocumentFailsTheTemplateCheck(testCase)
            d = ndi.document('sorting_parameters', ...
                'base.session_id', testCase.Session.id());
            p = d.document_properties;
            p.sorting_parameters.not_in_the_template = 1;
            bad = ndi.document(p);

            testCase.verifyError(@() testCase.Session.database_add(bad), ...
                'NDI:did2sqlite:v1TemplateMismatch');
            testCase.verifyEmpty(testCase.Session.database_search( ...
                ndi.query('base.id', 'exact_string', bad.id(), '')), ...
                'a refused document is not stored');

            % the check itself names the problem
            try
                ndi.database.internal.stampV1Write(did2.document(p));
                testCase.verifyFail('stampV1Write accepted a field outside the template');
            catch ME
                testCase.verifyEqual(ME.identifier, 'NDI:did2sqlite:v1TemplateMismatch');
                testCase.verifySubstring(ME.message, ...
                    'sorting_parameters.not_in_the_template');
            end
        end

        function testAV2DocumentIsStillValidatedAsV2(testCase)
            % the test's made-up variable ('short name') is not a registered
            % term; the term registry is not what this test is about
            prevTerms = did2.schema.cache.strictMode('TermRegistry', false);
            testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTerms));
            sid = testCase.Session.id();
            d = termAssertion(sid, 'short name', 'X', sid);
            testCase.assertTrue(did2.schema.isV2Stamp(d), 'did2.build stamps V2');

            % unchanged by the v1 step
            [same, how] = ndi.database.internal.stampV1Write(did2.document(d));
            testCase.verifyEqual(how, 'unchanged');
            testCase.verifyEqual(did2.schema.stampOf(same), did2.schema.v2Stamp());

            testCase.Session.database_add(ndi.document(d));
            stored = testCase.storedBody(d.base.id);
            testCase.verifyEqual(did2.schema.stampOf(stored), did2.schema.v2Stamp(), ...
                'a V2 document keeps its V2 stamp');

            % a V2 document that breaks its V2 class is refused by the V2
            % validation, not passed to the v1 template check
            bad = termAssertion(sid, 'short name', 'Y', sid);
            bad.base.not_a_v2_field = 'x';
            try
                testCase.Session.database_add(ndi.document(bad));
                testCase.verifyFail('a V2 document with an undeclared field was stored');
            catch ME
                testCase.verifyTrue(startsWith(ME.identifier, 'did2:'), sprintf( ...
                    'refused by "%s", not by did2 validation: %s', ...
                    ME.identifier, ME.message));
                testCase.verifyFalse(startsWith(ME.identifier, 'NDI:did2sqlite:v1'), ...
                    'a V2 document went to the v1 template check');
            end
        end
    end

    methods
        function s = storedBody(testCase, id)
            % the body as did2 stored it
            db = did2.database.sqlitedb(fullfile(testCase.Dir, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            closer = onCleanup(@() db.close()); %#ok<NASGU>
            raw = db.get(id);
            if iscell(raw)
                testCase.assertNumElements(raw, 1);
                raw = raw{1};
            end
            s = raw.toStruct();
        end
    end
end

function d = termAssertion(entityId, variable, value, sid)
% VARIABLE of ENTITYID is the term named VALUE (as TestRelationPasses builds it)
arguments
    entityId {mustBeText}
    variable {mustBeText}
    value {mustBeText}
    sid {mustBeText}
end
d = did2.build.statement('assertion', entityId, did2.build.term('', variable), ...
    did2.build.term('', value), 'SessionId', sid, 'ValueKind', 'term');
end

classdef TestDependencyShapeRoundTrip < matlab.unittest.TestCase
%TESTDEPENDENCYSHAPEROUNDTRIP ndi.document keeps the dependency shape it was read in.
%
%   VH-Lab/DID-matlab#204 (Steve Van Hooser): "read V1 -> write V1; read
%   V_zeta -> write V_zeta. Migration becomes an explicit action." did-schema
%   did_v2_go_forward_class_audit.md [v2 line reads and writes both] (Jess
%   Haley, 2026-11-03): a v1 dataset stays v1 and what is written into it is
%   v1; a v2 dataset is written as v2.
%
%   DID-matlab #389 made did.document keep the shape. ndi.document's
%   constructor still renamed every depends_on key to the v2 `document_id`
%   (ndi.compat.normalizeDependsOn), so a v1 session's document came back
%   from the database and went back into it v2-shaped, and
%   ndi.compat.translateQueryPaths rewrote a query on `depends_on.value` to
%   `depends_on.document_id`. These tests hold:
%     - a v1 session's document keeps its v1 block (`value` keys) through
%       construction, add, reopen, read, setting a dependency and re-adding;
%     - a v2 session's document keeps `document_id`;
%     - a depends_on query finds both shapes, by the `depends_on` operation
%       (in the session's database) and by a `.field` path on any of the
%       three key spellings (fieldsearch).

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeRoot(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            warnState = warning('off', 'NDI:V2:v1DocumentsPresent');
            testCase.addTeardown(@() warning(warnState));
        end
    end

    methods (Test)

        % ---- v1 -> v1 -------------------------------------------------

        function testV1TemplateDocumentIsV1Shaped(testCase)
            doc = ndi.document('treatment', 'treatment.name', 'x');
            testCase.verifyEqual(entryKeys(doc), {'name', 'value'}, ...
                'a document from a v1 template keeps the template''s `value` key');
        end

        function testV1BodyIsUnchangedByConstruction(testCase)
            doc = ndi.document('treatment', 'treatment.name', 'x');
            props = doc.document_properties;
            props.depends_on = jsondecode(v1Block('aaaa1111', 'bbbb2222', ''));
            again = ndi.document(props);
            testCase.verifyEqual(jsonencode(again.document_properties.depends_on), ...
                v1Block('aaaa1111', 'bbbb2222', ''), 'nothing converted on construction');
        end

        function testV1SessionDocumentRoundTripsUnchanged(testCase)
            S = ndi.session.dir('ref_v1', testCase.Root);
            testCase.assertFalse(S.writesV2(), ['ndi.session.dir makes a v1 (did-sqlite) ' ...
                'session until [new database defaults to v2] is built; then this test ' ...
                'needs a v1 session made another way']);
            subj = ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '') + S.newdocument();
            S.database_add(subj);

            doc = ndi.document('treatment', 'treatment.name', 'x') + S.newdocument();
            doc = doc.set_dependency_value('subject_id', subj.id());
            doc = doc.set_dependency_value('manipulation_id', '');
            doc = doc.set_dependency_value('protocol_id', '');
            before = jsonencode(doc.document_properties.depends_on);
            testCase.verifyEqual(entryKeys(doc), {'name', 'value'});
            S.database_add(doc);

            % save, reopen, read
            S2 = ndi.session.dir('ref_v1', testCase.Root);
            got = S2.database_search(ndi.query('base.id', 'exact_string', doc.id(), ''));
            testCase.assertNumElements(got, 1);
            testCase.verifyEqual(jsonencode(got{1}.document_properties.depends_on), before, ...
                'read v1 -> the stored block is the v1 block, byte for byte');
            testCase.verifyEqual(entryKeys(got{1}), {'name', 'value'});
            testCase.verifyEqual(got{1}.dependency_value('subject_id'), subj.id());

            % set a dependency and write it back; the database checks that
            % the target is stored, so point it at a stored document
            target = ndi.document('subject', 'subject.local_identifier', 'protocol@lab', ...
                'subject.description', '') + S2.newdocument();
            S2.database_add(target);
            protocolId = target.id();
            changed = got{1}.set_dependency_value('protocol_id', protocolId);
            testCase.verifyEqual(entryKeys(changed), {'name', 'value'}, ...
                'the setter writes the v1 key into a v1 document');
            % DID never re-uses a removed id, so the changed document is
            % written back as a new document (a new base.id), as NDI's
            % writers replace a document
            newId = ndi.ido().id();
            changed = changed.setproperties('base.id', newId);
            S2.database_rm(doc.id());
            S2.database_add(changed);
            S3 = ndi.session.dir('ref_v1', testCase.Root);
            back = S3.database_search(ndi.query('base.id', 'exact_string', newId, ''));
            testCase.assertNumElements(back, 1);
            testCase.verifyEqual(entryKeys(back{1}), {'name', 'value'}, ...
                'write v1: no document_id key reaches the v1 database');
            testCase.verifyEqual(back{1}.dependency_value('protocol_id'), protocolId);
            testCase.verifyEqual(back{1}.dependency_value('subject_id'), subj.id());
        end

        function testV1SessionDependsOnQueryFindsTheV1Document(testCase)
            S = ndi.session.dir('ref_q1', testCase.Root);
            subj = ndi.document('subject', 'subject.local_identifier', 'mouse@lab', ...
                'subject.description', '') + S.newdocument();
            S.database_add(subj);
            doc = ndi.document('treatment', 'treatment.name', 'x') + S.newdocument();
            doc = doc.set_dependency_value('subject_id', subj.id());
            S.database_add(doc);
            found = S.database_search(ndi.query('', 'depends_on', 'subject_id', subj.id()));
            testCase.verifyNumElements(found, 1);
            testCase.verifyEqual(found{1}.id(), doc.id());
            testCase.verifyEqual(entryKeys(found{1}), {'name', 'value'});
        end

        % ---- v2 -> v2 -------------------------------------------------

        function testV2BodyIsUnchangedByConstruction(testCase)
            doc = ndi.document('treatment', 'treatment.name', 'x');
            props = doc.document_properties;
            props.document_class.schema_version = 'did_v2';
            props.depends_on = jsondecode(v2Block('aaaa1111', 'bbbb2222', ''));
            again = ndi.document(props);
            testCase.verifyEqual(jsonencode(again.document_properties.depends_on), ...
                v2Block('aaaa1111', 'bbbb2222', ''));
            again = again.set_dependency_value('protocol_id', 'cccc3333');
            testCase.verifyEqual(entryKeys(again), {'document_id', 'name'}, ...
                'the setter writes the v2 key into a v2 document');
        end

        function testV2SessionDocumentStaysV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity`');
            study = ndi.ido.unique_id();
            folder = fullfile(testCase.Root, 'v2');
            mkdir(folder);
            ndi.setup.V2.createSession(folder, 'd1', 'StudyIds', {study});
            S = ndi.session.dir(folder);
            testCase.assertTrue(S.writesV2());
            rel = S.database_search(ndi.query('', 'isa', 'directed_relation'));
            testCase.assertNumElements(rel, 1);
            testCase.verifyTrue(isfield(rel{1}.document_properties.depends_on, 'document_id'));
            testCase.verifyFalse(isfield(rel{1}.document_properties.depends_on, 'value'), ...
                'read v2 -> no v1 key appears');
            testCase.verifyEqual(rel{1}.dependency_value('parent_id'), study);
            other = ndi.ido.unique_id();
            changed = rel{1}.set_dependency_value('parent_id', other);
            testCase.verifyFalse(isfield(changed.document_properties.depends_on, 'value'), ...
                'write v2: the setter keeps document_id');
            testCase.verifyEqual(changed.dependency_value('parent_id'), other);

            % the depends_on operation finds the v2 document too
            found = S.database_search(ndi.query('', 'depends_on', 'parent_id', study));
            testCase.verifyNumElements(found, 1);
            testCase.verifyEqual(found{1}.id(), rel{1}.id());
        end

        % ---- a .field path on depends_on finds both shapes -----------

        function testFieldPathOnAnyKeyFindsBothShapes(testCase)
            target = 'aaaa1111';
            v1 = struct('depends_on', struct('name', 'subject_id', 'value', target));
            v2 = struct('depends_on', struct('name', 'subject_id', 'document_id', target));
            for key = {'value', 'document_id', 'id'}
                q = ndi.query(['depends_on.' key{1}], 'exact_string', target);
                testCase.verifyTrue(logical(did.datastructures.fieldsearch(v1, q.searchstructure)), ...
                    sprintf('depends_on.%s finds a v1 entry', key{1}));
                testCase.verifyTrue(logical(did.datastructures.fieldsearch(v2, q.searchstructure)), ...
                    sprintf('depends_on.%s finds a v2 entry', key{1}));
                miss = ndi.query(['depends_on.' key{1}], 'exact_string', 'zzzz');
                testCase.verifyFalse(logical(did.datastructures.fieldsearch(v1, miss.searchstructure)));
                testCase.verifyFalse(logical(did.datastructures.fieldsearch(v2, miss.searchstructure)));
            end
        end

        function testNegatedFieldPathExcludesBothShapes(testCase)
            target = 'aaaa1111';
            v1 = struct('depends_on', struct('name', 'subject_id', 'value', target));
            v2 = struct('depends_on', struct('name', 'subject_id', 'document_id', target));
            q = ndi.query('depends_on.value', '~exact_string', target);
            testCase.verifyFalse(logical(did.datastructures.fieldsearch(v1, q.searchstructure)));
            testCase.verifyFalse(logical(did.datastructures.fieldsearch(v2, q.searchstructure)));
            other = ndi.query('depends_on.value', '~exact_string', 'zzzz');
            testCase.verifyTrue(logical(did.datastructures.fieldsearch(v1, other.searchstructure)));
            testCase.verifyTrue(logical(did.datastructures.fieldsearch(v2, other.searchstructure)));
        end

        % ---- readers that read the target ---------------------------

        function testToTableReadsEitherKey(testCase)
            doc = ndi.document('treatment', 'treatment.name', 'x');
            doc = doc.set_dependency_value('subject_id', 'aaaa1111');
            t = doc.to_table();
            testCase.verifyEqual(t.depends_on_subject_id{1}, 'aaaa1111');
            props = doc.document_properties;
            props.document_class.schema_version = 'did_v2';
            props.depends_on = jsondecode(v2Block('bbbb2222', '', ''));
            t2 = ndi.document(props).to_table();
            testCase.verifyEqual(t2.depends_on_subject_id{1}, 'bbbb2222');
        end
    end
end

function block = v1Block(subjectId, manipulationId, protocolId)
block = sprintf(['[{"name":"manipulation_id","value":"%s"},' ...
    '{"name":"protocol_id","value":"%s"},' ...
    '{"name":"subject_id","value":"%s"}]'], manipulationId, protocolId, subjectId);
end

function block = v2Block(subjectId, manipulationId, protocolId)
block = sprintf(['[{"name":"manipulation_id","document_id":"%s"},' ...
    '{"name":"protocol_id","document_id":"%s"},' ...
    '{"name":"subject_id","document_id":"%s"}]'], manipulationId, protocolId, subjectId);
end

function keys = entryKeys(doc)
keys = sort(fieldnames(doc.document_properties.depends_on))';
end

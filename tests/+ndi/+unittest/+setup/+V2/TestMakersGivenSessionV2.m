classdef TestMakersGivenSessionV2 < matlab.unittest.TestCase
%TESTMAKERSGIVENSESSIONV2 Makers given the session write in its database's version.
%
%   ndi.setup.NDIMaker.subjectMaker/makeSubjectDocuments (given 'Sessions'),
%   ndi.database.fun.openMINDSobj2ndi_document (given the session rather than
%   its id) and ndi.database.fun.openMINDSobj2V2 write v1 documents for a v1
%   database and v2 documents for a v2 database: a v2 subject is an `entity`
%   of type organism, its species and biological sex are term assertions about
%   it, and its strain is a strain entity (written once per distinct strain)
%   the subject is `instance_of` -- the shape the migration gives the v1
%   `subject` and `openminds_subject` documents. Objects about a stimulus stay
%   v1 on either database (no decided v2 target).
%
%   Decided by Jess Haley, 2026-11-03 [writers are given the session] and
%   [v2 line reads and writes both] (did-schema
%   did_v2_go_forward_class_audit.md): a tool learns the version from the
%   session's database. A v1 database gets v1 documents, a v2 database v2.
%
%   Filtered (never passed) when did2.build, a v2 schema with `entity`, or
%   openMINDS is missing.

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
            testCase.assumeTrue(exist('openminds.controlledterms.Species', 'class') == 8, ...
                'openMINDS is not on the path');
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
        function testSubjectMakerOnAV1DatabaseWritesV1(testCase)
            S = testCase.v1Session();
            out = ndi.setup.NDIMaker.subjectMaker().makeSubjectDocuments( ...
                testCase.subjectInfo(S, {'worm1@nosuchlab.org'}), 'Sessions', {S});
            docs = out.documents{1};
            classes = cellfun(@(d) d.document_properties.document_class.class_name, docs, ...
                'UniformOutput', false);
            % DENOMINATOR FIRST: what was written
            % the subject, its species, its strain (and the strain's species
            % child) and its sex
            testCase.assertNumElements(docs, 5, sprintf('documents written: %s', strjoin(classes, ', ')));
            testCase.verifyEqual(classes{1}, 'subject');
            testCase.verifyEqual(docs{1}.document_properties.subject.local_identifier, 'worm1@nosuchlab.org');
            testCase.verifyTrue(all(strcmp(classes(2:end), 'openminds_subject')), strjoin(classes, ', '));
            ndi.setup.NDIMaker.subjectMaker().addSubjectsToSessions({S}, out.documents);
            [b, sid] = ndi.subject.does_subjectstring_match_session_document(S, 'worm1@nosuchlab.org', 0);
            testCase.verifyTrue(logical(b));
            testCase.verifyEqual(sid, docs{1}.id());
        end

        function testSubjectMakerOnAV2DatabaseWritesV2(testCase)
            S = testCase.v2Session();
            names = {'worm1@nosuchlab.org', 'worm2@nosuchlab.org'};
            maker = ndi.setup.NDIMaker.subjectMaker();
            out = maker.makeSubjectDocuments(testCase.subjectInfo(S, names), 'Sessions', {S});
            testCase.assertNumElements(out.documents, 2);
            all_docs = [out.documents{1}(:); out.documents{2}(:)]';
            props = cellfun(@(d) d.document_properties, all_docs, 'UniformOutput', false);
            classes = cellfun(@(p) p.document_class.class_name, props, 'UniformOutput', false);
            % DENOMINATOR FIRST: what was written
            testCase.assertNotEmpty(all_docs, 'nothing was written');
            testCase.verifyTrue(all(cellfun(@(p) did2.schema.isV2Stamp(p), props)), ...
                sprintf('a document is not v2 (classes: %s)', strjoin(classes, ', ')));
            testCase.verifyFalse(any(ismember(classes, {'subject', 'openminds_subject', 'openminds'})), ...
                sprintf('a v1 class was written for a v2 database: %s', strjoin(classes, ', ')));

            strains = props(cellfun(@(p) testCase.isEntity(p, 'strain'), props));
            testCase.verifyNumElements(strains, 1, 'the shared strain was not written exactly once');
            if ~isempty(strains)
                testCase.verifyEqual(char(strains{1}.entity.name), 'N2');
                testCase.verifyTrue(any(strcmp(cellstr(strains{1}.entity.global_identifier), ...
                    'WormBase:WBStrain00000001')), 'the strain''s identifier is not on the entity');
                strainId = strains{1}.base.id;
                sp = testCase.assertionsAbout(props, strainId);
                testCase.verifyTrue(testCase.hasTerm(sp, 'NCBITaxon:6239'), ...
                    'the strain''s species is not asserted on it');
            end

            for k = 1:numel(names)
                docs = out.documents{k};
                p1 = docs{1}.document_properties;
                testCase.verifyTrue(testCase.isEntity(p1, 'organism'), 'the subject is not an organism entity');
                testCase.verifyEqual(char(p1.entity.local_identifier), names{k});
                testCase.verifyEqual(char(ndi.v2.sessionIdOf(p1)), S.id());
                sid = p1.base.id;
                about = testCase.assertionsAbout(props, sid);
                testCase.verifyTrue(testCase.hasTerm(about, 'NCBITaxon:6239'), 'no species assertion');
                testCase.verifyTrue(testCase.hasTerm(about, 'PATO:0001340'), 'no biological sex assertion');
                if ~isempty(strains)
                    inst = props(cellfun(@(p) strcmp(p.document_class.class_name, 'directed_relation') ...
                        && isequal(ndi.v2.edgeIds(p, 'child_id'), {sid}) ...
                        && isequal(ndi.v2.edgeIds(p, 'parent_id'), {strainId}) ...
                        && ndi.v2.vocabIs('relation', p.directed_relation.relation, 'instance_of'), props));
                    testCase.verifyNumElements(inst, 1, 'the subject is not instance_of its strain');
                end
            end

            % written into the v2 database, and found again by name
            added = maker.addSubjectsToSessions({S}, out.documents);
            testCase.verifyTrue(all(added));
            [b, sid] = ndi.subject.does_subjectstring_match_session_document(S, names{2}, 0);
            testCase.verifyTrue(logical(b));
            testCase.verifyEqual(sid, out.documents{2}{1}.id());
        end

        function testOpenMINDSGivenTheSessionPicksTheVersion(testCase)
            sp = openminds.controlledterms.Species('name', 'Caenorhabditis elegans', ...
                'preferredOntologyIdentifier', 'NCBITaxon:6239');
            subjectId = ndi.ido.unique_id();

            S1 = testCase.v1Session();
            d1 = ndi.database.fun.openMINDSobj2ndi_document(sp, S1, 'subject', subjectId);
            testCase.assertNumElements(d1, 1);
            testCase.verifyEqual(d1{1}.document_properties.document_class.class_name, 'openminds_subject');

            S2 = testCase.v2Session();
            d2 = ndi.database.fun.openMINDSobj2ndi_document(sp, S2, 'subject', subjectId);
            testCase.assertNumElements(d2, 1);
            p = d2{1}.document_properties;
            testCase.verifyTrue(did2.schema.isV2Stamp(p));
            testCase.verifyEqual(p.document_class.class_name, 'assertion');
            testCase.verifyEqual(ndi.v2.edgeIds(p, 'entity_id'), {subjectId});
            testCase.verifyTrue(testCase.hasTerm({p}, 'NCBITaxon:6239'));

            % given only the session's id, the documents are v1, as before
            d3 = ndi.database.fun.openMINDSobj2ndi_document(sp, S2.id(), 'subject', subjectId);
            testCase.verifyEqual(d3{1}.document_properties.document_class.class_name, 'openminds_subject');
        end

        function testAStimulusObjectStaysV1OnAV2Database(testCase)
            % no decided v2 target for `openminds_stimulus`: it stays v1
            S = testCase.v2Session();
            a = openminds.controlledterms.StimulationApproach('name', 'visual stimulation');
            d = ndi.database.fun.openMINDSobj2ndi_document(a, S, 'stimulus', ndi.ido.unique_id());
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'openminds_stimulus');
        end
    end

    methods
        function info = subjectInfo(~, S, names)
            sp = openminds.controlledterms.Species('name', 'Caenorhabditis elegans', ...
                'preferredOntologyIdentifier', 'NCBITaxon:6239');
            n = numel(names);
            info.subjectName = names(:);
            info.strain = cell(n, 1);
            info.species = cell(n, 1);
            info.biologicalSex = cell(n, 1);
            for k = 1:n
                % a fresh strain object per subject, as the lab creators build them
                st = openminds.core.research.Strain('name', 'N2', 'species', sp, ...
                    'ontologyIdentifier', 'WBStrain:00000001');
                info.strain{k} = st;
                info.species{k} = sp;
                info.biologicalSex{k} = openminds.controlledterms.BiologicalSex( ...
                    'name', 'hermaphrodite', 'preferredOntologyIdentifier', 'PATO:0001340');
            end
            info.tableRowIndex = (1:n)';
            info.sessionID = repmat({S.id()}, n, 1);
        end

        function S = v1Session(testCase)
            d = fullfile(testCase.Dir, ['v1_' ndi.ido.unique_id()]);
            mkdir(d);
            S = ndi.session.dir('ref1', d);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a v2 database');
        end

        function S = v2Session(testCase)
            d = fullfile(testCase.Dir, ['v2_' ndi.ido.unique_id()]);
            ndiDir = fullfile(d, '.ndi');
            mkdir(ndiDir);
            sid = ndi.ido.unique_id();
            db = did2.database.sqlitedb(fullfile(ndiDir, ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            db.close();
            vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), sid);
            vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), 'ref2');
            S = ndi.session.dir(d);
            testCase.assertEqual(S.id(), sid);
            testCase.assertTrue(S.writesV2(), 'the session does not report its v2 database');
        end
    end

    methods (Static)
        function tf = isEntity(p, type)
            tf = strcmp(p.document_class.class_name, 'entity') && ...
                ndi.v2.vocabIs('entity_type', p.entity.type, type);
        end

        function a = assertionsAbout(props, id)
            a = props(cellfun(@(p) strcmp(p.document_class.class_name, 'assertion') ...
                && isequal(ndi.v2.edgeIds(p, 'entity_id'), {id}), props));
        end

        function tf = hasTerm(props, node)
            % does one of the statements PROPS have the term value NODE
            tf = false;
            for k = 1:numel(props)
                [kind, v] = ndi.v2.statementValue(props{k});
                if strcmp(kind, 'term') && isstruct(v) && isfield(v, 'node') && strcmp(char(v.node), node)
                    tf = true;
                    return;
                end
            end
        end
    end
end

classdef TestRelationPasses < matlab.unittest.TestCase
%TESTRELATIONPASSES What a relation passes, records' own relation, session_id as an edge.
%
%   did-schema V_eta_relation_inheritance_plan.md (2026-10-20, a proposal
%   built ahead of signature; Haley decision #109): every relation_bindings
%   row declares `passes`; a session or study is `included_in` a study or
%   dataset, which passes nothing, and `part_of` is physical again;
%   base.session_id becomes a required `session_id` edge to the session or
%   dataset entity, whose base.id IS the session id.
%
%   Needs did-schema #88 (or later) on DID_SCHEMA_PATH.
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
                isfile(fullfile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            % 'short name', 'species' and the values below are this test's own
            % vocabulary; what is tested is inheritance, not the term registry
            if ~isempty(which('did2.schema.termIndex'))
                prev = did2.schema.cache.strictMode('TermRegistry', false);
                testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
            end
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
        function testTheRegistryDeclaresWhatPasses(testCase)
            P = ndi.v2.relationPasses();
            testCase.verifyNotEmpty(P.names, 'the registry binds relations');
            testCase.verifyEqual(P.distributive, {'member_of'});
            testCase.verifyEqual(P.context, {'contained_in'});
            for r = {'part_of', 'sample_of', 'instance_of'}
                testCase.verifyTrue(ismember(r{1}, P.assertions), r{1});
            end
            % did-schema #88, Jess Haley 2026-10-22: [vocabulary nodes] K5 makes
            % sample_of, aliquot_of and passage_of ONE relation (RO "derives
            % from part of") and retires aliquot_of and passage_of; [epoch to
            % system link] retires recorded_by and [distance] measured_distance_to
            for r = {'aliquot_of', 'passage_of', 'recorded_by', 'measured_distance_to'}
                testCase.verifyFalse(ismember(r{1}, P.names), [r{1} ' is retired']);
            end
            % the lineage relations follow the registry: part_of and sample_of
            testCase.verifyEqual(ndi.entity.lineageRelations(), {'part_of', 'sample_of'});
            % ndi.entity takes its distributive and context relations from
            % the same registry
            testCase.verifyEqual(ndi.entity.distributiveRelations(), {'member_of'});
            testCase.verifyEqual(ndi.entity.contextRelations(), {'contained_in'});
            testCase.verifyTrue(P.declared, 'the registry declares passes');
            testCase.verifyTrue(ismember('included_in', P.nothing));
            testCase.verifyTrue(ismember('same_as', P.nothing));
        end

        function testARecordInheritsNothingFromWhatItIsIncludedIn(testCase)
            % T-1 (V_eta_relation_inheritance_plan.md): a study filed under a
            % dataset does not take the dataset's short name; a slice that is
            % part_of an animal still takes the animal's species
            sid = ndi.ido.unique_id();
            c = {'SessionId', sid};
            id = struct();
            for n = {'ds', 'st', 'org', 'slice'}
                id.(n{1}) = ndi.ido.unique_id();
            end
            docs = [ ...
                ndi.setup.V2.entityDocuments('dataset', struct('name', 'a dataset'), struct(), c{:}, 'Id', id.ds), ...
                ndi.setup.V2.entityDocuments('study', struct('name', 'a study'), struct(), c{:}, 'Id', id.st), ...
                ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'animal', ...
                    'type', did2.build.term('', 'organism')), struct(), c{:}, 'Id', id.org), ...
                ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'slice', ...
                    'type', did2.build.term('', 'tissue')), struct(), c{:}, 'Id', id.slice), ...
                {did2.build.directedRelation(id.st, id.ds, ndi.v2.vocabTerm('relation', 'included_in'), c{:}), ...
                 did2.build.directedRelation(id.slice, id.org, ndi.v2.vocabTerm('relation', 'part_of'), c{:}), ...
                 termAssertion(id.ds, 'short name', 'DS', sid), ...
                 termAssertion(id.st, 'short name', 'ST', sid), ...
                 did2.build.statement('assertion', id.org, did2.build.term('NCIT:C45293', 'Species'), ...
                    did2.build.term('NCBITaxon:6239', 'Caenorhabditis elegans'), c{:}, 'ValueKind', 'term')}];
            S = ndi.setup.V2.createSession(testCase.Dir, 'passes', 'SessionId', sid, 'Documents', docs);

            % physical part_of passes assertions
            slice = ndi.entity.fromDocument(S, id.slice);
            sp = slice.assertions({'variable', 'species'}, 'synonyms', false);
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(sp{1}.via(), 'part_of');

            st = ndi.entity.fromDocument(S, id.st);
            names = st.assertions({'variable', 'short name'}, 'synonyms', false);
            values = sort(cellfun(@(x) termText(x), names, 'UniformOutput', false));
            testCase.verifyEqual(values, {'ST'}, ...
                'included_in passes nothing: the study has its own short name only');
            testCase.verifyEqual(names{1}.via(), 'own');
            own = st.assertions({'variable', 'short name'}, 'inherited', false, 'synonyms', false);
            testCase.verifyNumElements(own, 1, 'inherited false: only its own');
        end

        function testContainersDuringFollowsTheDistributiveRelations(testCase)
            % ndi.v2.containersDuring reaches a member's containers through
            % the relations that pass `distributive` (ndi.v2.relationPasses,
            % as ndi.entity), not a hard-coded member_of. A cohort's stay on
            % a plate, distributive and with no time, is undecidable, so it
            % shows as UNDECIDED for a worm that is member_of the cohort, and
            % not for one tied to it by part_of, which passes assertions.
            testCase.verifyEqual(ndi.v2.relationPasses().distributive, {'member_of'});
            sid = ndi.ido.unique_id();
            c = {'SessionId', sid};
            id = struct();
            for n = {'member', 'part', 'cohort', 'plate'}
                id.(n{1}) = ndi.ido.unique_id();
            end
            subj = @(name, type) ndi.setup.V2.entityDocuments('subject', ...
                struct('local_identifier', name, 'type', did2.build.term('', type)), ...
                struct(), c{:}, 'Id', id.(name));
            stmt = {termAssertion(id.member, 'condition', 'a', sid), ...
                termAssertion(id.part, 'condition', 'a', sid)};
            docs = [subj('member', 'organism'), subj('part', 'organism'), ...
                subj('cohort', 'group'), subj('plate', 'device'), ...
                {did2.build.directedRelation(id.member, id.cohort, ndi.v2.vocabTerm('relation', 'member_of'), c{:}), ...
                 did2.build.directedRelation(id.part, id.cohort, ndi.v2.vocabTerm('relation', 'part_of'), c{:}), ...
                 did2.build.directedRelation(id.cohort, id.plate, ndi.v2.vocabTerm('relation', 'contained_in'), c{:}, ...
                    'Fields', struct('distributive', true))}, stmt];
            S = ndi.setup.V2.createSession(testCase.Dir, 'containers', 'SessionId', sid, ...
                'Documents', docs);
            [held, undecided] = ndi.v2.containersDuring(S, stmt);
            testCase.verifyEqual(held, {{}, {}}, 'an untimed stay reaches no container');
            testCase.verifyEqual(undecided, [true false], ...
                'member_of reaches the cohort''s stay; part_of does not');
        end

        function testTheAccessorReadsTheEdgeOnTheNewShape(testCase)
            % a V2 document with no base.session_id field and a session_id
            % edge; built by hand, so the test does not depend on the schema
            sid = ndi.ido.unique_id();
            p = struct();
            p.document_class = struct('class_name', 'entity', 'class_version', '1.0.0', ...
                'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
                'schema_version', 'V_eta');
            p.depends_on = struct('name', {'session_id'}, 'document_id', {sid});
            p.base = struct('id', sid, 'creation_timestamp', '2026-10-20T00:00:00.000Z');
            d = ndi.document(p);
            testCase.verifyEqual(d.session_id(), sid);
            testCase.verifyEqual(ndi.v2.sessionIdOf(p), sid, 'a struct reads the same');
            other = ndi.ido.unique_id();
            d2 = d.set_session_id(other);
            testCase.verifyEqual(d2.session_id(), other);
            testCase.verifyFalse(isfield(d2.document_properties.base, 'session_id'), ...
                'set_session_id moves the edge, adding no field');
            testCase.verifyEqual(ndi.v2.edgeIds(d2.document_properties, 'session_id'), {other});

            % the field, where a document has one (v1, and migrated V_eta)
            q = p;
            q.depends_on = struct('name', {}, 'document_id', {});
            q.base.session_id = sid;
            e = ndi.document(q);
            testCase.verifyEqual(e.session_id(), sid);
            e2 = e.set_session_id(other);
            testCase.verifyEqual(e2.document_properties.base.session_id, other);
            testCase.verifyEmpty(ndi.v2.edgeIds(e2.document_properties, 'session_id'));

            % neither: a V_eta document gets the edge
            r = q;
            r.base = rmfield(r.base, 'session_id');
            f = ndi.document(r).set_session_id(sid);
            testCase.verifyEqual(f.session_id(), sid);
            testCase.verifyFalse(isfield(f.document_properties.base, 'session_id'));
            testCase.verifyEqual(ndi.v2.edgeIds(f.document_properties, 'session_id'), {sid});
        end

        function testBuiltDocumentsCarryTheSessionEdge(testCase)
            % did2.build with 'SessionId' writes the edge (DID-matlab #218)
            sid = ndi.ido.unique_id();
            d = termAssertion(ndi.ido.unique_id(), 'short name', 'X', sid);
            testCase.verifyEqual(ndi.v2.sessionIdOf(d), sid);
            testCase.verifyFalse(isfield(d.base, 'session_id'));
            testCase.verifyEqual(ndi.v2.edgeIds(d, 'session_id'), {sid});
        end
    end
end

function d = termAssertion(entityId, variable, value, sid)
% VARIABLE of ENTITYID is the term named VALUE
arguments
    entityId {mustBeText}
    variable {mustBeText}
    value {mustBeText}
    sid {mustBeText}
end
d = did2.build.statement('assertion', entityId, did2.build.term('', variable), ...
    did2.build.term('', value), 'SessionId', sid, 'ValueKind', 'term');
end

function t = termText(s)
% the name of a term statement's value
arguments
    s
end
[~, ~, t] = ndi.v2.statementValue(s.document_properties());
t = char(t);
end

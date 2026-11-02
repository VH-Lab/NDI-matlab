classdef TestSameAs < matlab.unittest.TestCase
%TESTSAMEAS One thing recorded twice: `same_as` (V_eta tenet T18).
%
%   did-schema V_eta_duplicate_entities_plan.md, signed 2026-10-19: same_as
%   joins two records of one thing and never two instances of one kind; it
%   is written only on an identifier that names the thing itself, stored in
%   the dataset, and no id is deleted or rewritten. Read: a search treats a
%   same_as group as one entity, what is asserted of either record holds of
%   the group, and where the records disagree the reader says so and picks
%   neither. Joining a session to a dataset writes a same_as per match and
%   lists the name-only candidates.
%
%   Every document is built with ndi.setup.V2.entityDocuments and did2.build.
%   The schema binds `same_as` (an undirected_relation over entities,
%   did-schema #73 audit 2 D5) and `instance_of` from a device to a product;
%   serial numbers and manufacturers are term assertions.
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
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            % the fixtures' terms ('illumination',
            % 'objective', 'serial number', 'manufacturer') are this test's own
            % vocabulary, not a dataset's, so they are not in DID-schema's term
            % registry; what is tested here is same_as, not the registry
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
        function testTheSchemaBindsSameAs(testCase)
            % the premise of every test below, asserted rather than assumed
            [~, undirected] = ndi.v2.relationNames();
            testCase.verifyTrue(any(strcmp(undirected, 'same_as')), strjoin(undirected, ', '));
            testCase.verifyTrue(any(strcmp(ndi.v2.relationPasses().names, 'instance_of')));
        end

        function testTheEndsAreReadAsRelatumIdOnly(testCase)
            % did-schema [undirected ends are relata] (Jess Haley,
            % 2026-11-01): the ends were renamed `entity_id` -> `relatum_id`,
            % readers first, then the schema, then the code dropped
            % `entity_id`. Only `relatum_id` edges are ends (ndi.v2.relata),
            % and relationDocs/sameAs search only that name
            % (ndi.v2.relataEdges); what the builder writes is read back.
            testCase.verifyEqual(ndi.v2.relataEdges(), {'relatum_id'});
            old = struct('depends_on', struct('name', {'session_id', 'entity_id', 'entity_id'}, ...
                'document_id', {'s', 'a', 'b'}));
            cur = struct('depends_on', struct('name', {'relatum_id', 'session_id', 'relatum_id'}, ...
                'document_id', {'a', 's', 'b'}));
            testCase.verifyEqual(ndi.v2.relata(old), {});
            testCase.verifyEqual(ndi.v2.relata(cur), {'a', 'b'});
            testCase.verifyEqual(ndi.v2.relata(struct('depends_on', [])), {});
            a = ndi.ido.unique_id(); b = ndi.ido.unique_id();
            rel = did2.build.undirectedRelation({a, b}, ndi.v2.vocabTerm('relation', 'same_as'), ...
                'SessionId', ndi.ido.unique_id());
            testCase.verifyEqual(ndi.v2.relata(rel), {a, b});
            testCase.verifyFalse(any(strcmp({rel.depends_on.name}, 'entity_id')));
        end

        function testASearchForEitherRecordFindsTheGroupsInstances(testCase)
            [S, id] = testCase.readerSession();
            for name = {'Leica M165 FC', 'M165 FC stereo microscope'}
                found = sort(idsOf(ndi.entity.search(S, {'product', name{1}}, 'synonyms', false)));
                testCase.verifyEqual(found, sort({id.d1, id.d2}), ...
                    sprintf('"%s" names one record; the instances of both are found', name{1}));
            end
            % without inheritance a record is only itself
            own = idsOf(ndi.entity.search(S, {'product', 'Leica M165 FC'}, ...
                'inherited', false, 'synonyms', false));
            testCase.verifyEqual(own, {id.d1});
            % a relation to either record matches
            via = sort(idsOf(ndi.entity.search(S, {'instance_of', id.p2}, 'synonyms', false)));
            testCase.verifyEqual(via, sort({id.d1, id.d2}));
        end

        function testSameAsIsNamedByAnySpellingInARelationFilter(testCase)
            % the reader's fixture stores same_as as the schema does (its node
            % and label). A relation filter naming same_as by its label is
            % same_as itself, read by node (entity.relatedIds), and finds what
            % the handle finds; a name compare would read 'sameAs' as another
            % relation and widen the other end to its same_as records
            [S, id] = testCase.readerSession();
            byHandle = sort(idsOf(ndi.entity.search(S, {'undirected_relation', ...
                {'name', 'same_as', 'with', id.p1}}, 'synonyms', false)));
            testCase.verifyTrue(ismember(id.p2, byHandle), strjoin(byHandle, ', '));
            label = ndi.v2.vocabTerm('relation', 'same_as').name;
            byLabel = sort(idsOf(ndi.entity.search(S, {'undirected_relation', ...
                {'name', label, 'with', id.p1}}, 'synonyms', false)));
            testCase.verifyEqual(byLabel, byHandle, sprintf('named ''%s''', label));
        end

        function testWhatIsAssertedOfEitherRecordHoldsOfTheGroup(testCase)
            [S, id] = testCase.readerSession();
            d2 = ndi.entity.fromDocument(S, id.d2);
            a = testCase.verifyWarning(@() d2.assertions(), 'ndi:entity:sameAs:disagree');
            vars = cellfun(@(x) x.variable_name(), a, 'UniformOutput', false);
            testCase.verifyTrue(ismember('Equipment Type', vars), ...
                'asserted of the other record of its product (P1), it holds of D2');
            testCase.verifyTrue(ismember('illumination', vars), 'asserted of its own product (P2)');
            k = find(strcmp(vars, 'Equipment Type'), 1);
            testCase.verifySubstring(a{k}.via(), 'same_as');
            testCase.verifySubstring(a{k}.via(), 'instance_of');

            % one animal under two local identifiers: W1's species is W2's
            w2 = ndi.entity.fromDocument(S, id.w2);
            s = w2.assertions({'variable', 'species'}, 'synonyms', false);
            testCase.verifyNumElements(s, 1);
            testCase.verifyEqual(s{1}.via(), 'same_as');
            testCase.verifyEqual(sort(idsOf(ndi.entity.search(S, ...
                {'species', 'Caenorhabditis elegans'}, 'synonyms', false))), sort({id.w1, id.w2}), ...
                'a search finding either record finds both');
            testCase.verifyEqual(idsOf(w2.sameAs()), {id.w1});
            % a worm that is not the same thing is not reached
            w3 = ndi.entity.fromDocument(S, id.w3);
            testCase.verifyEmpty(w3.assertions({'variable', 'species'}, 'synonyms', false));
            testCase.verifyEmpty(w3.sameAs());
            testCase.verifyEmpty(w2.assertions({'variable', 'species'}, 'inherited', false, ...
                'synonyms', false), 'inherited false: only what is stated of the record itself');
        end

        function testADisagreementIsReportedAndNeitherValueIsPicked(testCase)
            [S, id] = testCase.readerSession();
            d1 = ndi.entity.fromDocument(S, id.d1);
            a = testCase.verifyWarning(@() d1.assertions({'variable', 'objective'}, ...
                'synonyms', false), 'ndi:entity:sameAs:disagree');
            values = sort(cellfun(@(x) termText(x), a, 'UniformOutput', false));
            testCase.verifyEqual(values, {'PlanApo 1.0x', 'PlanApo 2.0x'}, 'both are returned');
            T = d1.disagreements();
            testCase.verifyEqual(height(T), 2, evalc('disp(T)'));
            testCase.verifyEqual(unique(T.variable), "objective");
            testCase.verifyEqual(sort(T.record_id), sort(string({id.p1; id.p2})));
            testCase.verifyEqual(unique(T.about), string(id.d1));
            % the records agree on everything else: no other row
            w2 = ndi.entity.fromDocument(S, id.w2);
            testCase.verifyEqual(height(w2.disagreements()), 0);
            testCase.verifyWarningFree(@() w2.assertions('synonyms', false));
        end

        function testJoiningASessionWritesMatchesAndListsCandidates(testCase)
            [ds, S2, id] = testCase.joinFixture();
            ds.add_ingested_session(S2);
            r = ds.same_as_report();
            testCase.verifyTrue(startsWith(r.denominator, 'DENOMINATOR:'), r.denominator);
            pairs = sort(strcat(r.matches.incoming_id, '|', r.matches.existing_id));
            testCase.verifyEqual(pairs, sort(string({[id.sN2 '|' id.dN2]; ...
                [id.sProd '|' id.dProd]; [id.sScope '|' id.dScope]})), evalc('disp(r.matches)'));
            ev = r.matches.evidence(r.matches.incoming_id == id.sN2);
            testCase.verifySubstring(char(ev), 'wormbase:WBStrain00000001');
            testCase.verifyEqual(r.written, 3);
            testCase.verifyTrue(all(strlength(r.matches.relation_id) > 0));
            % listed, never written: a name alone, and a serial number with
            % no manufacturer on both
            cand = sort(strcat(r.candidates.incoming_id, '|', r.candidates.existing_id));
            testCase.verifyEqual(cand, sort(string({[id.sCB '|' id.dCB]; ...
                [id.sScope2 '|' id.dScope]})), evalc('disp(r.candidates)'));
            % two things of one name whose identifiers differ are two things
            testCase.verifyFalse(any(r.candidates.incoming_id == id.sOther) || ...
                any(r.matches.incoming_id == id.sOther));

            % the relations are in the dataset, both ids intact
            ds = ndi.dataset.dir(ds.getpath());
            rel = ds.database_search(ndi.query('', 'isa', 'undirected_relation', ''));
            % by node (Jess Haley 2026-10-22 [vocabulary nodes] L1): the stored
            % name is the schema's label ('sameAs' once the schema flips), so
            % a compare of the name with 'same_as' would count 0
            terms = cellfun(@(d) ndi.v2.blockOf(d.document_properties, ...
                'undirected_relation', 'relation', ''), rel, 'UniformOutput', false);
            testCase.verifyEqual(sum(ndi.v2.vocabIs('relation', terms, 'same_as')), 3);
            % written with the node and the name the schema stores for it
            want = ndi.v2.vocabTerm('relation', 'same_as');
            testCase.verifyEqual(cellfun(@(t) char(t.node), terms, 'UniformOutput', false), ...
                repmat({want.node}, size(terms)));
            testCase.verifyEqual(cellfun(@(t) char(t.name), terms, 'UniformOutput', false), ...
                repmat({want.name}, size(terms)));
            for k = {id.sN2, id.dN2, id.sProd, id.dProd}
                testCase.verifyNumElements(ds.database_search(ndi.query('base.id', ...
                    'exact_string', k{1}, '')), 1, 'no id is deleted or rewritten');
            end
            % and read as one: the dataset's N2 record reaches the session's
            n2 = ndi.entity.fromDocument(ds, id.dN2);
            testCase.verifyEqual(idsOf(n2.sameAs()), {id.sN2});
        end

        function testSameAsFalseReportsAndWritesNothing(testCase)
            [ds, S2, ~] = testCase.joinFixture();
            ds.add_ingested_session(S2, 'SameAs', false);
            r = ds.same_as_report();
            testCase.verifyEqual(height(r.matches), 3, 'still found and reported');
            testCase.verifyEqual(r.written, 0);
            testCase.verifyTrue(any(contains(r.notes, 'SameAs')), strjoin(r.notes, newline));
            rel = ds.database_search(ndi.query('', 'isa', 'undirected_relation', ''));
            testCase.verifyEmpty(rel);
        end

        function testALinkedSessionIsJoinedTheSameWay(testCase)
            [ds, S2, id] = testCase.joinFixture();
            ds.add_linked_session(S2);
            r = ds.same_as_report();
            testCase.verifyEqual(r.written, 3);
            % written in the dataset, not in the session's folder
            alone = ndi.session.dir(S2.getpath());
            testCase.verifyEmpty(alone.database_search(ndi.query('', 'isa', 'undirected_relation', '')));
            [~, ids] = ds.session_list();
            S = ds.open_session(ids{1});
            n2 = ndi.entity.fromDocument(S, id.sN2);
            testCase.verifyEqual(idsOf(n2.sameAs()), {id.dN2}, ...
                'a linked session opened through its dataset sees the same_as stored there');
        end
    end

    methods
        function [S, id] = readerSession(testCase)
            % one session: products P1 and P2 are one product (same_as), D1
            % and D2 its two units (instance_of each); worms W1 and W2 one
            % animal (same_as), W3 another
            sid = ndi.ido.unique_id();
            id = struct();
            for n = {'p1', 'p2', 'd1', 'd2', 'w1', 'w2', 'w3'}
                id.(n{1}) = ndi.ido.unique_id();
            end
            c = {'SessionId', sid};
            docs = [ ...
                ndi.setup.V2.entityDocuments('product', struct('name', 'Leica M165 FC'), struct(), c{:}, 'Id', id.p1), ...
                ndi.setup.V2.entityDocuments('product', struct('name', 'M165 FC stereo microscope'), struct(), c{:}, 'Id', id.p2), ...
                device(id.d1, 'scope_lab', sid), device(id.d2, 'scope_core', sid), ...
                organism(id.w1, 'worm_a', sid), organism(id.w2, 'worm_a_again', sid), ...
                organism(id.w3, 'worm_b', sid)];
            docs = [docs, { ...
                did2.build.directedRelation(id.d1, id.p1, ndi.v2.vocabTerm('relation', 'instance_of'), c{:}), ...
                did2.build.directedRelation(id.d2, id.p2, ndi.v2.vocabTerm('relation', 'instance_of'), c{:}), ...
                did2.build.undirectedRelation({id.p1, id.p2}, ndi.v2.vocabTerm('relation', 'same_as'), c{:}), ...
                did2.build.undirectedRelation({id.w1, id.w2}, ndi.v2.vocabTerm('relation', 'same_as'), c{:}), ...
                termAssertion(id.p1, did2.build.term('NCIT:C178920', 'Equipment Type'), ...
                    'stereo microscope', sid), ...
                termAssertion(id.p2, 'illumination', 'LED', sid), ...
                termAssertion(id.p1, 'objective', 'PlanApo 1.0x', sid), ...
                termAssertion(id.p2, 'objective', 'PlanApo 2.0x', sid), ...
                did2.build.statement('assertion', id.w1, did2.build.term('NCIT:C45293', 'Species'), ...
                    did2.build.term('NCBITaxon:6239', 'Caenorhabditis elegans'), c{:}, 'ValueKind', 'term')}];
            folder = fullfile(testCase.Dir, 'reader');
            mkdir(folder);
            S = ndi.setup.V2.createSession(folder, 'same_as reader', 'SessionId', sid, ...
                'Documents', docs);
        end

        function [ds, S2, id] = joinFixture(testCase)
            % a dataset recording N2 (with its WormBase id), a product (with a
            % catalog number), a microscope (serial number and manufacturer)
            % and CB4856 (no identifier); a session recording each again, plus
            % a second microscope with the same serial number and no
            % manufacturer, and a strain called N2 with another identifier
            dsid = ndi.ido.unique_id();
            sid = ndi.ido.unique_id();
            id = struct();
            for n = {'dN2', 'dProd', 'dScope', 'dCB', 'sN2', 'sProd', 'sScope', 'sScope2', ...
                    'sCB', 'sOther'}
                id.(n{1}) = ndi.ido.unique_id();
            end
            d = {'SessionId', dsid};
            s = {'SessionId', sid};
            % the dataset entity's id IS the dataset's session id
            % (V_eta_relation_inheritance_plan.md)
            dsIdArg = {'Id', dsid};
            wb = @(v) did2.build.list(struct('scheme', did2.build.label('WormBase'), 'value', v));
            dsDocs = [ ...
                ndi.setup.V2.entityDocuments('dataset', struct('name', 'same_as join'), struct(), d{:}, dsIdArg{:}), ...
                ndi.setup.V2.entityDocuments('strain', struct('name', 'N2', ...
                    'global_identifier', wb('WBStrain00000001')), struct(), d{:}, 'Id', id.dN2), ...
                ndi.setup.V2.entityDocuments('product', struct('name', 'OP50 stock', ...
                    'catalog_number', 'OP50-CGC'), struct(), d{:}, 'Id', id.dProd), ...
                device(id.dScope, 'zoom_ds', dsid), ...
                {termAssertion(id.dScope, 'serial number', 'SN-4471', dsid), ...
                 termAssertion(id.dScope, 'manufacturer', 'Zeiss', dsid)}, ...
                ndi.setup.V2.entityDocuments('strain', struct('name', 'CB4856'), struct(), d{:}, 'Id', id.dCB)];
            ndi.setup.V2.createDataset(fullfile(testCase.Dir, 'ds'), 'same_as join', dsid, ...
                dsDocs, {}, 'Progress', false);
            ds = ndi.dataset.dir(fullfile(testCase.Dir, 'ds'));

            sDocs = [ ...
                ndi.setup.V2.entityDocuments('strain', struct('name', 'Bristol N2', ...
                    'global_identifier', wb('WBStrain00000001')), struct(), s{:}, 'Id', id.sN2), ...
                ndi.setup.V2.entityDocuments('product', struct('name', 'E. coli OP50', ...
                    'catalog_number', 'OP50-CGC'), struct(), s{:}, 'Id', id.sProd), ...
                device(id.sScope, 'zoom_session', sid), ...
                {termAssertion(id.sScope, 'serial number', 'SN-4471', sid), ...
                 termAssertion(id.sScope, 'manufacturer', 'Zeiss', sid)}, ...
                device(id.sScope2, 'zoom_spare', sid), ...
                {termAssertion(id.sScope2, 'serial number', 'SN-4471', sid)}, ...
                ndi.setup.V2.entityDocuments('strain', struct('name', 'CB4856'), struct(), s{:}, 'Id', id.sCB), ...
                ndi.setup.V2.entityDocuments('strain', struct('name', 'N2', ...
                    'global_identifier', wb('WBStrain00000002')), struct(), s{:}, 'Id', id.sOther)];
            folder = fullfile(testCase.Dir, 'joining');
            mkdir(folder);
            S2 = ndi.setup.V2.createSession(folder, 'joining', 'SessionId', sid, 'Documents', sDocs);
        end
    end
end

function docs = device(docId, localId, sid)
% a device subject (an instrument)
arguments
    docId {mustBeText}
    localId {mustBeText}
    sid {mustBeText}
end
docs = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', localId, ...
    'type', did2.build.term('', 'device')), struct(), 'SessionId', sid, 'Id', docId);
end

function docs = organism(docId, localId, sid)
% an organism subject
arguments
    docId {mustBeText}
    localId {mustBeText}
    sid {mustBeText}
end
docs = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', localId, ...
    'type', did2.build.term('', 'organism')), struct(), 'SessionId', sid, 'Id', docId);
end

function d = termAssertion(entityId, variable, value, sid)
% VARIABLE (a term, or a name) of ENTITYID is the term named VALUE
arguments
    entityId {mustBeText}
    variable
    value {mustBeText}
    sid {mustBeText}
end
if ~isstruct(variable)
    variable = did2.build.term('', variable);
end
d = did2.build.statement('assertion', entityId, variable, ...
    did2.build.term('', value), 'SessionId', sid, 'ValueKind', 'term');
end

function ids = idsOf(entities)
% the document ids of a cell array of entities, a row cellstr
arguments
    entities cell
end
ids = reshape(cellfun(@(x) x.document_id, entities, 'UniformOutput', false), 1, []);
end

function t = termText(s)
% the name of a term statement's value
arguments
    s
end
[~, ~, t] = ndi.v2.statementValue(s.document_properties());
t = char(t);
end

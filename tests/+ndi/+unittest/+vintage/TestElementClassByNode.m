classdef TestElementClassByNode < matlab.unittest.TestCase
%TESTELEMENTCLASSBYNODE The element class variable is read by its node, and by its old name.
%
%   Decided by Jess Haley, 2026-11-19 [variable terms batch 1] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): the v1 'ndi element
%   class' variable becomes the registered node EMPTY:0000401 "software
%   class". DID-matlab's element migrator writes it through
%   did2.convert.registeredTerm, so a newly migrated assertion carries the
%   node (and the registry's label); a database migrated before then holds
%   the old name 'ndi element class' with no node. Every reader that finds
%   the class assertion matches the node first and still accepts the old
%   name (ndi.vintage.elementClassQuery, ndi.vintage.isElementClassVariable).
%
%   The session is ndi.unittest.vintage.FakeSearchSession, and unlike the
%   other vintage tests it EVALUATES each query against the documents (isa,
%   depends_on and or here, every other operation by
%   did.datastructures.fieldsearch), so a reader that still asks for the old
%   name only finds nothing for the node-only assertion and fails here.
%
%   UNVERIFIED: written without MATLAB; CI is the first run.

    methods (Test)

        function testTheVariableTestReadsTheNodeAndTheOldName(testCase)
            want = ndi.vintage.elementClassVariable();
            testCase.verifyEqual(want.node, 'EMPTY:0000401');
            testCase.verifyEqual(want.name, 'software class');
            isClass = @ndi.vintage.isElementClassVariable;
            testCase.verifyTrue(isClass(struct('node', 'EMPTY:0000401')), ...
                'only the node, no label');
            testCase.verifyTrue(isClass(struct('node', 'EMPTY:0000401', 'name', '')), ...
                'the node, an empty label');
            testCase.verifyTrue(isClass(struct('node', 'EMPTY:0000401', 'name', 'software class')), ...
                'the node and the registry label (what DID-matlab writes)');
            testCase.verifyTrue(isClass(struct('node', 'empty:0000401', 'name', '')), ...
                'prefix case aside');
            testCase.verifyTrue(isClass(struct('node', '', 'name', 'ndi element class')), ...
                'the old name (migrated databases)');
            testCase.verifyTrue(isClass(struct('name', 'ndi element class')), ...
                'the old name, no node field');
            testCase.verifyFalse(isClass(struct('node', 'NCIT:C178920', 'name', 'Equipment Type')));
            testCase.verifyFalse(isClass(struct('node', '', 'name', 'element type')));
            testCase.verifyFalse(isClass(struct('node', '', 'name', 'software class')), ...
                'the label alone is not the node');
            testCase.verifyFalse(isClass(struct('node', {}, 'name', {})));
            testCase.verifyFalse(isClass('ndi element class'), 'not a term struct');
        end

        function testTheQueryMatchesTheNodeAndTheOldName(testCase)
            q = ndi.vintage.elementClassQuery();
            testCase.verifyTrue(matches(nodeOnlyAssertion('a', 'e', 'c').statement, q.searchstructure, true), ...
                'only the node');
            testCase.verifyTrue(matches(oldNameAssertion('a', 'e', 'c').statement, q.searchstructure, true), ...
                'the old name');
            testCase.verifyFalse(matches(otherAssertion('a', 'e', 'c').statement, q.searchstructure, true), ...
                'another variable');
        end

        function testANodeOnlyAssertionIsRead(testCase)
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            S = session();
            % the entities a class assertion is about, in the database's order
            testCase.verifyEqual(ndi.vintage.elementAssertionIds(S), {'el_node', 'el_old'});
            testCase.verifyEqual(ndi.vintage.elementAssertionIds(S, 'probe'), {'el_node'}, ...
                'filtered by the class the node-only assertion names');
            testCase.verifyEqual(ndi.vintage.elementSubjectIds(S), {'el_node', 'el_old'});
            % the entity carrying only a node-only class assertion is an element
            nodeDoc = ndi.document(device('el_node'));
            testCase.verifyTrue(ndi.vintage.isEtaElement(nodeDoc, S));
            f = ndi.vintage.elementFields(nodeDoc, S);
            testCase.verifyEqual(char(f.ndi_element_class), 'ndi.probe.timeseries.mfdaq');
            testCase.verifyEqual(char(ndi.vintage.objectClass(nodeDoc, S)), ...
                'ndi.probe.timeseries.mfdaq');
        end

        function testAnOldNameAssertionIsStillRead(testCase)
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            S = session();
            oldDoc = ndi.document(device('el_old'));
            testCase.verifyTrue(ndi.vintage.isEtaElement(oldDoc, S));
            f = ndi.vintage.elementFields(oldDoc, S);
            testCase.verifyEqual(char(f.ndi_element_class), 'ndi.neuron');
            testCase.verifyEqual(char(ndi.vintage.objectClass(oldDoc, S)), 'ndi.neuron');
        end

        function testAnotherVariableIsNotAClass(testCase)
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
            S = session();
            otherDoc = ndi.document(device('el_other'));
            testCase.verifyFalse(ndi.vintage.isEtaElement(otherDoc, S), ...
                'an assertion under another variable does not make an element');
            testCase.verifyFalse(any(strcmp(ndi.vintage.elementAssertionIds(S), 'el_other')));
        end

    end
end

% ===================== the session =========================================

function S = session()
% three devices with no recording and no wiring (so the links say nothing),
% each with one term assertion about it: a node-only class assertion (what
% DID-matlab writes once it looks the variable up by node, with the label
% left out), an old-name class assertion (a database migrated before
% [variable terms batch 1]), and an assertion under another variable
docs = {device('el_node'), device('el_old'), device('el_other'), ...
    nodeOnlyAssertion('a_node', 'el_node', 'ndi.probe.timeseries.mfdaq'), ...
    oldNameAssertion('a_old', 'el_old', 'ndi.neuron'), ...
    otherAssertion('a_other', 'el_other', 'ndi.probe.timeseries.mfdaq')};
held = cellfun(@(p) ndi.document(p), docs, 'UniformOutput', false);
S = ndi.unittest.vintage.FakeSearchSession(@(q) answer(q, held));
end

function d = answer(q, held)
% the documents the query matches, in the order held
ss = q.searchstructure;
pick = cellfun(@(x) matches(x.document_properties, ss, false), held);
d = held(pick);
end

function tf = matches(p, ss, fieldsOnly)
% ss is a search-structure array (ANDed). isa, depends_on and or are
% evaluated here; every other operation by did.datastructures.fieldsearch.
% FIELDSONLY: P is a bare block (no document_class), for the query test.
tf = true;
for k = 1:numel(ss)
    e = ss(k);
    op = char(e.operation);
    neg = startsWith(op, '~');
    base = op(1 + neg:end);
    switch base
        case 'or'
            r = matches(p, e.param1, fieldsOnly) || matches(p, e.param2, fieldsOnly);
        case 'isa'
            r = ~fieldsOnly && isaDoc(p, char(e.param1));
        case 'depends_on'
            r = ~fieldsOnly && dependsOn(p, char(e.param1), e.param2);
        otherwise
            if fieldsOnly
                % the bare statement block stands at `statement`
                p2 = struct('statement', p);
                r = logical(did.datastructures.fieldsearch(p2, e));
            else
                r = logical(did.datastructures.fieldsearch(p, e));
            end
            neg = false;   % fieldsearch applies '~' itself
    end
    if neg
        r = ~r;
    end
    if ~r
        tf = false;
        return;
    end
end
end

function tf = isaDoc(p, cls)
tf = false;
if ~isfield(p, 'document_class'); return; end
dc = p.document_class;
if strcmp(char(dc.class_name), cls)
    tf = true;
    return;
end
if isfield(dc, 'superclasses')
    for k = 1:numel(dc.superclasses)
        if strcmp(char(dc.superclasses(k).class_name), cls)
            tf = true;
            return;
        end
    end
end
end

function tf = dependsOn(p, name, value)
tf = false;
if ~isfield(p, 'depends_on'); return; end
want = cellstr(value);
for k = 1:numel(p.depends_on)
    dep = p.depends_on(k);
    if ~isempty(name) && ~strcmp(name, '*') && ~strcmp(char(dep.name), name)
        continue;
    end
    v = '';
    if isfield(dep, 'value'); v = char(dep.value); end
    if isfield(dep, 'document_id'); v = char(dep.document_id); end
    if any(strcmp(v, want))
        tf = true;
        return;
    end
end
end

% ===================== the documents =======================================

function p = base(id, className, superNames, deps)
p = struct();
sup = struct('class_name', [{'base'}, superNames], 'class_version', '1.0.0');
p.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', sup, 'schema_version', 'did_v2');
p.depends_on = [struct('name', 'session_id', 'value', 'sess_1'), deps];
p.base = struct('id', id, 'creation_timestamp', '2026-01-01T00:00:00.000Z');
end

function p = device(id)
p = base(id, 'entity', {}, struct('name', {}, 'value', {}));
p.entity = struct('type', struct('node', 'COB:0001300', 'name', 'device'), ...
    'local_identifier', [id ' | 1'], 'name', id);
end

function p = termAssertion(id, entityId, variable, cls)
p = base(id, 'assertion', {'statement', 'term'}, ...
    struct('name', 'entity_id', 'value', entityId));
p.statement = struct('variable', variable);
p.term = struct('value', struct('node', '', 'name', cls));
end

function p = nodeOnlyAssertion(id, entityId, cls)
% the class variable by node only: no label at all
p = termAssertion(id, entityId, struct('node', 'EMPTY:0000401'), cls);
end

function p = oldNameAssertion(id, entityId, cls)
% the class variable as databases migrated before [variable terms batch 1] hold it
p = termAssertion(id, entityId, struct('node', '', 'name', 'ndi element class'), cls);
end

function p = otherAssertion(id, entityId, cls)
p = termAssertion(id, entityId, struct('node', 'NCIT:C178920', 'name', 'Equipment Type'), cls);
end

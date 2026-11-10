classdef TestElementRecognisedByLinks < matlab.unittest.TestCase
%TESTELEMENTRECOGNISEDBYLINKS v2 elements are found by their links, not by a label.
%
%   Decided by Jess Haley, 2026-11-10 [element recognised by its links]
%   (did-schema docs/plans/did_v2_go_forward_class_audit.md): an entity is
%   an element when data can be read through it. A `device` with a
%   recording observation or a wiring relation (`connected to`, RO:0002170)
%   is a probe; a `cell` or `Group` with a `derived_from` relation onto such
%   a probe is a sorted unit; a device with neither is not a probe.
%   [ensemble has members]: a Group with `member_of` relations into it is an
%   ensemble (ndi.element.ensemble, type `ensemble`); one with none is one
%   multi-unit (ndi.neuron, type `spikes`). [ndi element class not kept]:
%   the class is rebuilt from the entity type and device kind
%   (probetype2object.json for a probe).
%
%   None of these documents carries an "ndi element class" assertion: they
%   are the shape DID-matlab writes once it stops writing it, and the shape
%   of new v2 data. The session is ndi.unittest.vintage.FakeSearchSession,
%   answering each search from the documents below.
%
%   The risk the team discussed is pinned by
%   testAnImportedDeviceWithNoRecordingIsNotAProbe: a device an import
%   wrote with no recording (the Haley import's instruments) must not
%   become a probe.

    methods (TestMethodSetup)
        function needSchema(testCase)
            testCase.assumeTrue(~isempty(getenv('DID_SCHEMA_PATH')), ...
                'DID_SCHEMA_PATH is not set (ndi.v2.vocabQuery reads it)');
        end
    end

    methods (Test)

        function testADeviceWithARecordingIsAProbe(testCase)
            S = session({device('probe_rec'), observation('obs_1', 'specimen_1', 'probe_rec')});
            testCase.verifyEqual(ndi.vintage.elementLinkKind(device('probe_rec'), S), 'probe');
            testCase.verifyTrue(ndi.vintage.isEtaElement(ndi.document(device('probe_rec')), S));
        end

        function testADeviceWithAWiringRelationIsAProbe(testCase)
            S = session({device('probe_wired'), relation('rel_w', 'probe_wired', 'sys_1', 'RO:0002170', 'connected to')});
            testCase.verifyEqual(ndi.vintage.elementLinkKind(device('probe_wired'), S), 'probe');
        end

        function testAnImportedDeviceWithNoRecordingIsNotAProbe(testCase)
            % the Haley shape: an instrument entity, no observation made
            % with it in the session and no wiring
            cam = device('camera_1');
            S = session({cam, observation('obs_other', 'plate_1', '')});
            testCase.verifyEqual(ndi.vintage.elementLinkKind(cam, S), '');
            testCase.verifyFalse(ndi.vintage.isEtaElement(ndi.document(cam), S));
            testCase.verifyEmpty(ndi.vintage.elementSubjectIds(S));
            testCase.verifyEmpty(ndi.vintage.elementSubjectIds(S, 'probe'));
            % and in a call's scope (the session-wide answer)
            scope = ndi.vintage.elementFieldsScope('open'); %#ok<NASGU>
            L = ndi.vintage.linkedElements(S);
            testCase.verifyEmpty(L.ids);
            testCase.verifyFalse(ndi.vintage.isEtaElement(ndi.document(cam), S));
        end

        function testAUnitOnAnUnrecordedDeviceIsNotAnElement(testCase)
            S = session({device('dev_idle'), cellEntity('unit_x'), ...
                relation('rel_d', 'unit_x', 'dev_idle', 'prov:wasDerivedFrom', 'derived from')});
            testCase.verifyEqual(ndi.vintage.elementLinkKind(cellEntity('unit_x'), S), '');
        end

        function testACellDerivedFromAProbeIsAUnit(testCase)
            S = unitSession();
            testCase.verifyEqual(ndi.vintage.elementLinkKind(cellEntity('unit_c'), S), 'unit');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('unit', 'spikes'), 'ndi.neuron');
        end

        function testAGroupWithMembersIsAnEnsemble(testCase)
            S = unitSession();
            testCase.verifyEqual(ndi.vintage.elementLinkKind(groupEntity('ens_g'), S), 'ensemble');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('ensemble', 'ensemble'), ...
                'ndi.element.ensemble');
        end

        function testAGroupWithNoMembersIsAMultiUnit(testCase)
            S = unitSession();
            testCase.verifyEqual(ndi.vintage.elementLinkKind(groupEntity('mua_g'), S), 'unit');
        end

        function testTheSessionWideAnswerAgrees(testCase)
            S = unitSession();
            scope = ndi.vintage.elementFieldsScope('open'); %#ok<NASGU>
            L = ndi.vintage.linkedElements(S);
            testCase.verifyEqual(sort(L.ids), sort({'probe_u', 'unit_c', 'ens_g', 'mua_g'}));
            testCase.verifyEqual(L.kind('probe_u'), 'probe');
            testCase.verifyEqual(L.kind('unit_c'), 'unit');
            testCase.verifyEqual(L.kind('ens_g'), 'ensemble');
            testCase.verifyEqual(L.kind('mua_g'), 'unit');
            testCase.verifyFalse(isKey(L.kind, 'neuron_m1'), ...
                'a member neuron with no derived_from onto a probe is not a unit here');
            testCase.verifyEqual(ndi.vintage.elementLinkKind(groupEntity('ens_g'), S), 'ensemble');
        end

        function testElementSubjectIdsFindsTheLinkedElements(testCase)
            S = unitSession();
            testCase.verifyEqual(sort(ndi.vintage.elementSubjectIds(S)), ...
                sort({'probe_u', 'unit_c', 'ens_g', 'mua_g'}));
            testCase.verifyEqual(ndi.vintage.elementSubjectIds(S, 'probe'), {'probe_u'});
        end

        function testTheProbeClassComesFromTheProbeTypeTable(testCase)
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('probe', 'n-trode'), ...
                'ndi.probe.timeseries.mfdaq');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('probe', 'stimulator'), ...
                'ndi.probe.timeseries.stimulator');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('probe', 'two-photon-imaging'), ...
                'ndi.probe.image');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('probe', 'not-a-type'), '', ...
                'a type with no row cannot be rebuilt');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('probe', ''), '');
            testCase.verifyEqual(ndi.vintage.elementClassOfKind('', 'n-trode'), '');
        end

        function testElementFieldsRebuildsTheGroupTypeAndClass(testCase)
            S = unitSession();
            f = ndi.vintage.elementFields(ndi.document(groupEntity('ens_g')), S);
            testCase.verifyEqual(f.type, 'ensemble');
            testCase.verifyEqual(f.ndi_element_class, 'ndi.element.ensemble');
            f = ndi.vintage.elementFields(ndi.document(groupEntity('mua_g')), S);
            testCase.verifyEqual(f.type, 'spikes');
            testCase.verifyEqual(f.ndi_element_class, 'ndi.neuron');
            f = ndi.vintage.elementFields(ndi.document(cellEntity('unit_c')), S);
            testCase.verifyEqual(f.type, 'spikes');
            testCase.verifyEqual(f.ndi_element_class, 'ndi.neuron');
        end

    end
end

% ===================== the documents =======================================

function S = unitSession()
% a probe (recorded), a single unit (cell), an ensemble (Group with two
% member neurons) and a multi-unit (Group, no members), all derived_from it
docs = {device('probe_u'), observation('obs_u', 'specimen_1', 'probe_u'), ...
    cellEntity('unit_c'), groupEntity('ens_g'), groupEntity('mua_g'), cellEntity('neuron_m1'), ...
    relation('d1', 'unit_c', 'probe_u', 'prov:wasDerivedFrom', 'derived from'), ...
    relation('d2', 'ens_g', 'probe_u', 'prov:wasDerivedFrom', 'derived from'), ...
    relation('d3', 'mua_g', 'probe_u', 'prov:wasDerivedFrom', 'derived from'), ...
    relation('m1', 'neuron_m1', 'ens_g', 'RO:0002350', 'member of'), ...
    relation('m2', 'unit_c', 'ens_g', 'RO:0002350', 'member of')};
S = session(docs);
end

function S = session(docs)
docs = cellfun(@(p) ndi.document(p), docs, 'UniformOutput', false);
S = ndi.unittest.vintage.FakeSearchSession(@(q) answer(q, docs));
end

function d = answer(q, docs)
% answers by the values a query carries (as the other vintage tests do):
% the class assertions (none), observations, relations of one term, and
% documents by id
vals = queryValues(q.searchstructure);
held = docs;
docs = cellfun(@(x) x.document_properties, held, 'UniformOutput', false);
ids = cellfun(@(x) x.base.id, docs, 'UniformOutput', false);
named = vals(ismember(vals, ids));
d = {};
if any(ismember(vals, {'assertion', 'ndi element class', 'element type', 'Equipment Type'}))
    return;   % no assertion of any kind is stored
end
relNodes = {'RO:0002170', 'RO:0001000', 'prov:wasDerivedFrom', 'RO:0002350'};
if any(strcmp(vals, 'observation')) && any(strcmp(vals, 'instrument_id')) || ...
        (any(strcmp(vals, 'observation')) && ~any(strcmp(vals, 'directed_relation')))
    pick = cellfun(@(x) strcmp(x.document_class.class_name, 'observation'), docs);
elseif any(strcmp(vals, 'directed_relation'))
    want = vals(ismember(vals, relNodes));
    pick = cellfun(@(x) strcmp(x.document_class.class_name, 'directed_relation') && ...
        any(strcmp(x.directed_relation.relation.node, want)), docs);
else
    d = held(ismember(ids, named));
    return;
end
if ~isempty(named)
    % limited by an edge to one of the named ids
    pick = pick & cellfun(@(x) any(ismember({x.depends_on.value}, named)), docs);
end
d = held(pick);
end

function vals = queryValues(ss)
vals = {};
for k = 1:numel(ss)
    for f = {'param1', 'param2'}
        v = ss(k).(f{1});
        if ischar(v) || (isstring(v) && isscalar(v))
            vals{end+1} = char(v); %#ok<AGROW>
        elseif iscell(v)
            vals = [vals, cellfun(@char, v(cellfun(@(x) ischar(x) || isstring(x), v)), ...
                'UniformOutput', false)]; %#ok<AGROW>
        elseif isstruct(v) && isfield(v, 'param1')
            vals = [vals, queryValues(v)]; %#ok<AGROW>
        end
    end
end
end

function p = base(id, className, deps)
p = struct();
p.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
p.depends_on = [struct('name', 'session_id', 'value', 'sess_1'), deps];
p.base = struct('id', id, 'creation_timestamp', '2026-01-01T00:00:00.000Z');
end

function p = entity(id, node, name)
p = base(id, 'entity', struct('name', {}, 'value', {}));
p.entity = struct('type', struct('node', node, 'name', name), ...
    'local_identifier', [id ' | 1'], 'name', id);
end

function p = device(id)
p = entity(id, 'COB:0001300', 'device');
end

function p = cellEntity(id)
p = entity(id, 'CL:0000000', 'cell');
end

function p = groupEntity(id)
p = entity(id, 'NCIT:C43359', 'Group');
end

function p = observation(id, specimen, instrument)
deps = struct('name', 'entity_id', 'value', specimen);
if ~isempty(instrument)
    deps(end+1) = struct('name', 'instrument_id', 'value', instrument);
end
p = base(id, 'observation', deps);
end

function p = relation(id, child, parent, node, name)
p = base(id, 'directed_relation', struct('name', {'child_id', 'parent_id'}, ...
    'value', {child, parent}));
p.directed_relation = struct('relation', struct('node', node, 'name', name));
end

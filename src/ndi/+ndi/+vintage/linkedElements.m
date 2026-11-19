function L = linkedElements(S)
%LINKEDELEMENTS The session's elements, recognised by their links.
%
%   L = ndi.vintage.linkedElements(SESSION) finds every entity of SESSION
%   that no "ndi element class" assertion is about (while that assertion is
%   written it decides: Decided by Jess Haley, 2026-11-10 [assertion wins
%   while written]; ndi.vintage.elementAssertionIds) and that is an element
%   because data can be read through it, by its links and not by a label (Decided by Jess Haley, 2026-11-10 [element recognised by its
%   links], did-schema docs/plans/did_v2_go_forward_class_audit.md):
%
%     probe     a `device` entity that a recording observation names as its
%               `instrument_id`, or the child of a wiring relation (a
%               directed_relation `connected to`, RO:0002170)
%     unit      a `cell` or `Group` entity that is the child of a
%               `derived_from` relation whose parent is such a probe
%     ensemble  a unit of type `Group` that `member_of` relations point into
%               (Decided by Jess Haley, 2026-11-10 [ensemble has members]: a
%               Group with members is an ensemble, v1 ndi.element.ensemble,
%               type `ensemble`; one with none is one multi-unit, v1
%               ndi.neuron, type `spikes`)
%
%   A device with neither link is not a probe: a device an import wrote with
%   no recording (the Haley import's instruments before their recordings are
%   written, a plate reader, ...) is not an element. The same rule holds for
%   migrated and new v2 data.
%
%   L is a struct:
%     ids       cellstr, the elements: the probes in the order their links
%               were found, then the units in the order of their relations
%     kind      containers.Map, id -> 'probe' | 'unit' | 'ensemble'
%     evidence  containers.Map, id -> cellstr of the ids of the documents
%               that make it an element (for the derived index's
%               dependencies, ndi.vintage.prefetchElementFields)
%
%   The searches read edges and text values only where the database can (no
%   document decoded): the device, cell and Group entities, then, limited to
%   the ones with no class assertion by their edges (one SQL IN each), the
%   observations' instrument edges and each relation (`connected to`,
%   `derived_from`, `member_of`). Inside a call's scope (ndi.vintage.elementFieldsScope) the answer
%   is kept and every later question in the call is answered from it
%   (Jess Haley, 2026-11-06: "Speed can't be slower than v1").
%
%   See also ndi.vintage.elementLinkKind, ndi.vintage.isEtaElement,
%   ndi.vintage.elementSubjectIds, ndi.vintage.elementClassOfKind.

key = '';
if ndi.vintage.elementFieldsScope('isopen')
    try
        key = ['L|' char(S.id())];
    catch
        key = '';
    end
    if ~isempty(key)
        [L, hit] = ndi.vintage.elementFieldsScope('get', key);
        if hit
            return;
        end
    end
end

L = struct('ids', {{}}, ...
    'kind', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'evidence', containers.Map('KeyType', 'char', 'ValueType', 'any'));

% ---- the candidates: device, cell and Group entities with no class assertion
% While the "ndi element class" assertion is written it decides (Decided by
% Jess Haley, 2026-11-10 [assertion wins while written]), so only the
% entities without one are asked about their links; the searches below are
% limited to them by their edges (one SQL IN each), not run over every
% observation and relation of the session.
asserted = ndi.vintage.elementAssertionIds(S);
[typed, typeOf] = typedEntities(S);
free = typed(~ismember(typed, asserted));
devices = free(strcmp(values(typeOf, free), 'device'));
cellsGroups = free(ismember(values(typeOf, free), {'cell', 'group'}));

probes = {};
probeEvidence = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(devices)
    probeEvidence = probeLinks(S, devices);
    probes = devices(isKey(probeEvidence, devices));
    for k = 1:numel(probes)
        L.kind(probes{k}) = 'probe';
        L.evidence(probes{k}) = unique(probeEvidence(probes{k}), 'stable');
    end
end

% ---- units: cell / Group children of derived_from onto a probe ----------
units = {};
if ~isempty(cellsGroups)
    derived = edgeRows(S, elementRelationQuery('derived_from') & ...
        (ndi.vintage.edgeIn('child_id', cellsGroups) | ndi.vintage.edgeIn('child', cellsGroups)), ...
        {'child_id', 'child', 'parent_id', 'parent'});
    [childOf, parentOf, relIds] = relationEnds(derived);
    keep = ~cellfun(@isempty, childOf) & ~cellfun(@isempty, parentOf) & ismember(childOf, cellsGroups);
    % is each parent a probe by its links? (an asserted probe too: the rule
    % is about the parent's links)
    parents = unique(parentOf(keep), 'stable');
    parentDevices = {};
    if ~isempty(parents)
        [~, ptype] = typedEntities(S, parents);
        parentDevices = parents(strcmp(values(ptype, parents), 'device'));
    end
    parentEvidence = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if ~isempty(parentDevices)
        parentEvidence = probeLinks(S, parentDevices);
    end
    onProbe = keep & cellfun(@(p) ~isempty(p) && isKey(parentEvidence, p), parentOf);
    ev = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for r = find(onProbe)
        c = childOf{r};
        if isKey(ev, c)
            ev(c) = [ev(c), relIds(r), parentOf(r)];
        else
            ev(c) = [relIds(r), parentOf(r)];
        end
    end
    units = unique(childOf(onProbe), 'stable');
    for k = 1:numel(units)
        L.kind(units{k}) = 'unit';
        L.evidence(units{k}) = unique(ev(units{k}), 'stable');
    end
    % ---- ensembles: Group units with members ----------------------------
    groups = units(strcmp(values(typeOf, units), 'group'));
    if ~isempty(groups)
        members = edgeRows(S, elementRelationQuery('member_of') & ...
            (ndi.vintage.edgeIn('parent_id', groups) | ndi.vintage.edgeIn('parent', groups)), ...
            {'parent_id', 'parent'});
        into = groupDocs(containers.Map('KeyType', 'char', 'ValueType', 'any'), members);
        for k = 1:numel(groups)
            if isKey(into, groups{k})
                L.kind(groups{k}) = 'ensemble';
                L.evidence(groups{k}) = unique([L.evidence(groups{k}), ...
                    into(groups{k})], 'stable');
            end
        end
    end
end
L.ids = [probes, units];

if ~isempty(key)
    ndi.vintage.elementFieldsScope('put', key, L);
end
end

% ===================== helpers =============================================

function [childOf, parentOf, relIds] = relationEnds(rows)
% each relation's first child and first parent (child_id / parent_id, else
% the earlier child / parent), in the order the relations came; one pass
relIds = unique({rows.doc_id}, 'stable');
childOf = repmat({''}, 1, numel(relIds));
parentOf = repmat({''}, 1, numel(relIds));
if isempty(relIds)
    return;
end
pos = containers.Map(relIds, num2cell(1:numel(relIds)));
rank = containers.Map({'child_id', 'child', 'parent_id', 'parent'}, {1, 2, 1, 2});
cRank = inf(1, numel(relIds));
pRank = inf(1, numel(relIds));
for k = 1:numel(rows)
    i = pos(rows(k).doc_id);
    n = rows(k).name;
    if ~isKey(rank, n) || isempty(rows(k).document_id); continue; end
    r = rank(n);
    if startsWith(n, 'child')
        if r < cRank(i); childOf{i} = rows(k).document_id; cRank(i) = r; end
    elseif r < pRank(i)
        parentOf{i} = rows(k).document_id; pRank(i) = r;
    end
end
end

function m = groupDocs(m, rows)
% target id -> the ids of the documents whose edge names it, in row order
for k = 1:numel(rows)
    t = rows(k).document_id;
    if isempty(t); continue; end
    if isKey(m, t)
        m(t) = [m(t), {rows(k).doc_id}];
    else
        m(t) = {rows(k).doc_id};
    end
end
end

function m = probeLinks(S, devices)
% device id -> the ids of its recording observations and wiring relations,
% for the DEVICES that have any
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
obs = edgeRows(S, ndi.v2.isaQuery('observation') & ndi.vintage.edgeIn('instrument_id', devices), ...
    {'instrument_id'});
wiring = edgeRows(S, elementRelationQuery('connected_to') & ...
    (ndi.vintage.edgeIn('child_id', devices) | ndi.vintage.edgeIn('child', devices)), ...
    {'child_id', 'child'});
m = groupDocs(m, obs);
m = groupDocs(m, wiring);
for k = reshape(m.keys, 1, [])
    if ~any(strcmp(k{1}, devices))
        remove(m, k{1});
    end
end
end

function [ids, typeOf] = typedEntities(S, among)
% the session's device, cell and Group entities (or, with AMONG, those of
% the ids AMONG that are), and a map id -> NDI's type handle; '' for any
% other id asked about
typeOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
ids = {};
if nargin >= 2
    for k = 1:numel(among); typeOf(among{k}) = ''; end
    if isempty(among); return; end
    byId = ndi.vintage.docsById(S, among, 'RawBlocks', {'base', 'entity'}, 'LightClass', 'entity');
    for k = 1:numel(among)
        d = byId(among{k});
        if ~isempty(d)
            t = ndi.vintage.elementEntityType(d);
            typeOf(among{k}) = t;
            if any(strcmp(t, {'device', 'cell', 'group'})); ids{end+1} = among{k}; end %#ok<AGROW>
        end
    end
    return;
end
q = ndi.query('', 'isa', 'entity', '') & ...
    ndi.v2.vocabQuery('entity.type', 'entity_type', {'device', 'cell', 'group'});
rows = [];
if ismethod(S, 'database_search_values')
    rows = S.database_search_values(q, {'entity.type.node', 'entity.type.name'});
end
if isstruct(rows)
    for k = 1:numel(rows)
        t = char(ndi.v2.vocabHandle('entity_type', ...
            struct('node', char(rows(k).values{1}), 'name', char(rows(k).values{2}))));
        if any(strcmp(t, {'device', 'cell', 'group'})) && ~isKey(typeOf, rows(k).doc_id)
            ids{end+1} = char(rows(k).doc_id); %#ok<AGROW>
            typeOf(rows(k).doc_id) = t;
        end
    end
    return;
end
docs = S.database_search(q);
for k = 1:numel(docs)
    t = ndi.vintage.elementEntityType(docs{k});
    id = char(ndi.v2.props(docs{k}).base.id);
    if any(strcmp(t, {'device', 'cell', 'group'})) && ~isKey(typeOf, id)
        ids{end+1} = id; %#ok<AGROW>
        typeOf(id) = t;
    end
end
end

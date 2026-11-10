function L = linkedElements(S)
%LINKEDELEMENTS The session's elements, recognised by their links.
%
%   L = ndi.vintage.linkedElements(SESSION) finds every entity of SESSION that
%   is an element because data can be read through it, by its links and not
%   by a label (Decided by Jess Haley, 2026-11-10 [element recognised by its
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
%   The searches read edges only where the database can (no document
%   decoded): one for the observations' instrument edges, one per relation
%   (`connected to`, `derived_from`, `member_of`), and the candidate entities
%   by key. Inside a call's scope (ndi.vintage.elementFieldsScope) the answer
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

% ---- probe candidates: instruments of observations, children of wiring --
% (rows grouped by target in one pass: a session has thousands of
% observations and hundreds of elements)
obs = edgeRows(S, ndi.v2.isaQuery('observation'), {'instrument_id'});
wiring = edgeRows(S, elementRelationQuery('connected_to'), {'child_id', 'child'});
byTarget = containers.Map('KeyType', 'char', 'ValueType', 'any');
byTarget = groupDocs(byTarget, obs);
byTarget = groupDocs(byTarget, wiring);
candidates = unique([{obs.document_id}, {wiring.document_id}], 'stable');
candidates = candidates(~cellfun(@isempty, candidates));
types = entityTypes(S, candidates);
probes = {};
for k = 1:numel(candidates)
    id = candidates{k};
    if ~strcmp(types(id), 'device')
        continue;
    end
    probes{end+1} = id; %#ok<AGROW>
    L.kind(id) = 'probe';
    L.evidence(id) = unique(byTarget(id), 'stable');
end

% ---- units: cell / Group children of derived_from onto a probe ----------
units = {};
if ~isempty(probes)
    isProbe = containers.Map(probes, num2cell(true(1, numel(probes))));
    derived = edgeRows(S, elementRelationQuery('derived_from'), ...
        {'child_id', 'child', 'parent_id', 'parent'});
    [childOf, parentOf, relIds] = relationEnds(derived);
    onProbe = cellfun(@(p) ~isempty(p) && isKey(isProbe, p), parentOf) ...
        & ~cellfun(@isempty, childOf);
    childIds = unique(childOf(onProbe), 'stable');
    childTypes = entityTypes(S, childIds);
    ev = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for r = find(onProbe)
        c = childOf{r};
        if isKey(ev, c)
            ev(c) = [ev(c), relIds(r), parentOf(r)];
        else
            ev(c) = [relIds(r), parentOf(r)];
        end
    end
    for k = 1:numel(childIds)
        id = childIds{k};
        if ~any(strcmp(childTypes(id), {'cell', 'group'}))
            continue;
        end
        units{end+1} = id; %#ok<AGROW>
        L.kind(id) = 'unit';
        L.evidence(id) = unique(ev(id), 'stable');
    end
    % ---- ensembles: Group units with members ----------------------------
    groups = units(cellfun(@(u) strcmp(childTypes(u), 'group'), units));
    if ~isempty(groups)
        members = edgeRows(S, elementRelationQuery('member_of'), {'parent_id', 'parent'});
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

function m = entityTypes(S, ids)
% id -> NDI's handle for its entity.type ('device', 'cell', 'group', ...);
% '' for an id that is not an entity or is not found
m = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(ids)
    m(ids{k}) = '';
end
if isempty(ids)
    return;
end
byId = ndi.vintage.docsById(S, ids, 'RawBlocks', {'base', 'entity'}, 'LightClass', 'entity');
for k = 1:numel(ids)
    d = byId(ids{k});
    if isempty(d)
        continue;
    end
    m(ids{k}) = ndi.vintage.elementEntityType(d);
end
end

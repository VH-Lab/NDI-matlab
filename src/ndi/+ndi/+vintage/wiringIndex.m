function W = wiringIndex(rels)
%WIRINGINDEX Directed relations read ahead, filed by (child, parent) for ndi.vintage.wiredDeviceString.
%
%   W = ndi.vintage.wiringIndex(RELS). RELS is a cell of directed_relation
%   documents in the order a search returned them. W is a struct:
%
%     docs     RELS
%     anchors  for each, its `time_reference_id` targets (cellstr)
%     byPair   containers.Map, [child char(0) parent] -> the positions in
%              DOCS of the relations with that child and parent, ascending
%
%   ndi.vintage.wiredDeviceString takes, for a probe, a system and the
%   statement's anchors, the relations of that pair timed by any of the
%   anchors, in DOCS order: what its own search
%   (isa directed_relation & child & parent & any anchor) returns.
%
%   See also ndi.vintage.wiredDeviceString, ndi.vintage.ingestedEpochs.

arguments
    rels cell
end

W = struct('docs', {rels}, 'anchors', {cell(1, numel(rels))}, ...
    'byPair', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'firstWiring', containers.Map('KeyType', 'char', 'ValueType', 'double'));
% firstWiring: [child char(0) parent char(0) anchor] -> the first position
% in DOCS of a WIRING relation (a directed_relation `connected to`,
% RO:0002170) of that child and parent timed by that anchor. The relations
% wiredDeviceString would skip (no directed_relation block, another
% relation term) are not filed, so the first wiring relation of a pair over
% several anchors is the least of the anchors' entries.
for r = 1:numel(rels)
    W.anchors{r} = ndi.vintage.edgeTargets(rels{r}, 'time_reference_id');
    children = unique(ndi.vintage.edgeTargets(rels{r}, 'child_id'));
    parents = unique(ndi.vintage.edgeTargets(rels{r}, 'parent_id'));
    wiring = isWiring(rels{r});
    for c = 1:numel(children)
        for p = 1:numel(parents)
            key = [children{c} char(0) parents{p}];
            if isKey(W.byPair, key)
                W.byPair(key) = [W.byPair(key), r];
            else
                W.byPair(key) = r;
            end
            if ~wiring; continue; end
            for a = 1:numel(W.anchors{r})
                k3 = [key char(0) W.anchors{r}{a}];
                if ~isKey(W.firstWiring, k3)
                    W.firstWiring(k3) = r;
                end
            end
        end
    end
end
end

function tf = isWiring(d)
% what ndi.vintage.wiredDeviceString keeps: a directed_relation whose
% relation term's node is RO:0002170
tf = false;
p = d.document_properties;
if ~isfield(p, 'directed_relation'); return; end
dr = p.directed_relation;
tf = isfield(dr, 'relation') && isstruct(dr.relation) && isfield(dr.relation, 'node') ...
    && strcmpi(char(dr.relation.node), 'RO:0002170');
end

function others = sameAs(container, ids)
%SAMEAS The other records of one thing: the `same_as` groups of some entities.
%
%   OTHERS = ndi.v2.sameAs(CONTAINER, IDS) reads the undirected relations
%   named `same_as` that reach the entity ids IDS, step after step (a `same_as`
%   b and b `same_as` c make one group of three), and returns a
%   containers.Map from each id of IDS to the other ids of its group (a row
%   cellstr; {} when the entity is recorded once). One search per step for
%   every 200 ids.
%
%   V_eta tenet T18 (did-schema V_eta_duplicate_entities_plan.md, signed
%   2026-10-19): two entity documents are `same_as` when they record the very
%   same thing (two N2 strain records, two records of one microscope). Both
%   documents keep their ids; a reader treats the group as one entity. The
%   relation is stored in the dataset, so a session opened from its dataset
%   also searches the dataset's documents (ndi.session/
%   database_search_with_dataset); a session opened on its own sees none.
%
%   See also ndi.entity, ndi.v2.sameAsMatches.

arguments
    container
    ids
end

ids = unique(cellstr(ids), 'stable');
ids = reshape(ids, 1, []);
others = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(ids)
    others(ids{k}) = {};
end
if isempty(ids), return; end

% the neighbours of each id reached, read a step at a time
adj = containers.Map('KeyType', 'char', 'ValueType', 'any');
seen = ids;
frontier = ids;
while ~isempty(frontier)
    next = {};
    for c = 1:200:numel(frontier)
        part = frontier(c:min(c + 199, numel(frontier)));
        q = ndi.query('', 'isa', 'undirected_relation', '') & ...
            ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', 'entity_id', i), part, ...
            'UniformOutput', false));
        docs = searchAll(container, q);
        for i = 1:numel(docs)
            p = ndi.v2.props(docs{i});
            r = ndi.v2.termName(ndi.v2.blockOf(p, 'undirected_relation', 'relation', ''));
            if ~strcmp(r, 'same_as'), continue; end
            members = unique(ndi.v2.edgeIds(p, 'entity_id'), 'stable');
            for a = 1:numel(members)
                rest = members([1:a-1, a+1:end]);
                if isKey(adj, members{a})
                    adj(members{a}) = unique([adj(members{a}), rest], 'stable');
                else
                    adj(members{a}) = rest;
                end
            end
            new = members(~ismember(members, seen));
            seen = [seen, new]; %#ok<AGROW>
            next = [next, new]; %#ok<AGROW>
        end
    end
    frontier = unique(next, 'stable');
end

% each id's group: everything connected to it
for k = 1:numel(ids)
    group = ids(k);
    todo = ids(k);
    while ~isempty(todo)
        at = todo{1};
        todo(1) = [];
        if ~isKey(adj, at), continue; end
        n = adj(at);
        n = n(~ismember(n, group));
        group = [group, n]; %#ok<AGROW>
        todo = [todo, n]; %#ok<AGROW>
    end
    others(ids{k}) = group(2:end);
end
end

function docs = searchAll(container, q)
% the documents matching Q: a session's own and, for a session opened from
% its dataset, the dataset's, where a `same_as` is stored
arguments
    container
    q
end
if isa(container, 'ndi.session')
    docs = container.database_search_with_dataset(q);
else
    docs = container.database_search(q);
end
docs = reshape(docs, 1, []);
end

function docs = getDocuments(container, ids, cache)
%GETDOCUMENTS The documents with these ids, a few searches in all.
%
%   DOCS = ndi.v2.getDocuments(CONTAINER, IDS) returns a containers.Map,
%   id -> ndi.document, for the ids found in CONTAINER (an ndi.session or
%   ndi.dataset); 200 ids per search. With a CACHE (a containers.Map), the
%   documents found are also stored in it under 'doc:<id>', and ids already
%   there are not searched again.
%
%   See also ndi.v2.getDocument, ndi.v2.timesOf.

if nargin < 3, cache = []; end
docs = containers.Map('KeyType', 'char', 'ValueType', 'any');
ids = unique(cellstr(ids), 'stable');
todo = {};
for k = 1:numel(ids)
    if ~isempty(cache) && isKey(cache, ['doc:' ids{k}])
        docs(ids{k}) = cache(['doc:' ids{k}]);
    elseif ~isempty(ids{k})
        todo{end+1} = ids{k}; %#ok<AGROW>
    end
end
for c = 1:200:numel(todo)
    part = todo(c:min(c + 199, numel(todo)));
    qs = cellfun(@(i) ndi.query('base.id', 'exact_string', i, ''), part, 'UniformOutput', false);
    while numel(qs) > 1          % a balanced OR: nested log2(N) deep
        n = floor(numel(qs) / 2);
        nx = cell(1, ceil(numel(qs) / 2));
        for i = 1:n, nx{i} = qs{2*i - 1} | qs{2*i}; end
        if mod(numel(qs), 2), nx{end} = qs{end}; end
        qs = nx;
    end
    found = container.database_search(qs{1});
    for i = 1:numel(found)
        p = ndi.v2.props(found{i});
        id = char(p.base.id);
        docs(id) = found{i};
        if ~isempty(cache), cache(['doc:' id]) = found{i}; end
    end
end
end

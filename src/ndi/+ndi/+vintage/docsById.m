function m = docsById(S, ids)
%DOCSBYID The session's documents with the ids IDS, read in a few searches.
%
%   M = ndi.vintage.docsById(SESSION, IDS) is a containers.Map from each id
%   in IDS (a cellstr; empty ids are ignored) to its ndi.document, or to []
%   when SESSION.database_search finds no document with that id -- the same
%   answer, id by id, as SESSION.database_search(ndi.query('base.id',
%   'exact_string', ID, '')){1}, without one search per id: the ids are read
%   200 to a search, as one `or` of `base.id` tests.
%
%   See also ndi.vintage.edgeIn, ndi.v2.anyOf.

arguments
    S
    ids
end

m = containers.Map('KeyType', 'char', 'ValueType', 'any');
ids = unique(reshape(cellstr(ids), 1, []), 'stable');
ids = ids(~cellfun(@isempty, ids));
for c = 1:200:numel(ids)
    part = ids(c:min(c + 199, numel(ids)));
    found = S.database_search(ndi.v2.anyOf(cellfun(@(i) ndi.query('base.id', 'exact_string', i, ''), ...
        part, 'UniformOutput', false)));
    for k = 1:numel(found)
        id = char(ndi.v2.props(found{k}).base.id);   % an ndi.document or a struct
        if ~isKey(m, id)
            m(id) = found{k};
        end
    end
end
for k = 1:numel(ids)
    if ~isKey(m, ids{k})
        m(ids{k}) = [];
    end
end
end

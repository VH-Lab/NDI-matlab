function rows = edgeRows(S, q, names)
%EDGEROWS The named edges of the documents a search matches, as rows.
%
%   ROWS = edgeRows(S, Q, NAMES) is a struct array with fields doc_id, name
%   and document_id: for each document S.database_search(Q) returns, in its
%   order, each of its depends_on entries whose name is in NAMES. Read as
%   edges without decoding the documents where the database can
%   (ndi.session/database_search_edges), else from the documents
%   (ndi.vintage.edgeTargets), so a mock or v1 session answers the same.

rows = struct('doc_id', {}, 'name', {}, 'document_id', {});
names = cellstr(names);
edges = [];
if ismethod(S, 'database_search_edges')
    edges = S.database_search_edges(q, names);
end
if isstruct(edges)
    % the same rows, built at once rather than grown one by one (8,320 rows
    % for one migrated Dab getelements; NDI-matlab run 44602160692)
    if ~isempty(edges)
        rows = struct('doc_id', cellfun(@char, {edges.doc_id}, 'UniformOutput', false), ...
            'name', cellfun(@char, {edges.name}, 'UniformOutput', false), ...
            'document_id', cellfun(@char, {edges.document_id}, 'UniformOutput', false));
    end
    return;
end
docs = S.database_search(q);
if ~iscell(docs); docs = num2cell(docs); end
for d = 1:numel(docs)
    p = ndi.v2.props(docs{d});
    id = char(p.base.id);
    for n = 1:numel(names)
        t = ndi.vintage.edgeTargets(docs{d}, names{n});
        for j = 1:numel(t)
            rows(end+1) = struct('doc_id', id, 'name', names{n}, 'document_id', char(t{j})); %#ok<AGROW>
        end
    end
end
end

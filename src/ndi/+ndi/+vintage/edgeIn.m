function q = edgeIn(name, ids)
%EDGEIN A query for documents whose edge NAME points at any of IDS, in one search.
%
%   Q = ndi.vintage.edgeIn(NAME, IDS) is an ndi.query: a `depends_on` NAME
%   whose target is any one of IDS (a cellstr). did2 (a v2 database, the
%   did2sqlite backend) compiles the list to ONE `IN` over the edge index,
%   bound as one JSON array, so a list of any length is one search and its
%   answer comes back in the database's own order (rowid), as the same search
%   for one id at a time would give it, merged.
%
%   For a v2 database only: the v1 backends take one target per depends_on.
%   ndi.vintage.ingestedEpochs and ndi.vintage.ingestedArchives use it to
%   read a whole session's migrated ingested epochs in a few searches.
%
%   The list cannot go through ndi.query's four-argument constructor, which
%   hands its parameters to struct() and would make one search term per id;
%   it is set on the search structure instead.
%
%   See also ndi.vintage.docsById, ndi.vintage.edgeTargets, did2.query.

arguments
    name (1,:) char
    ids
end

ids = reshape(cellstr(ids), 1, []);
ss = struct('field', '', 'operation', 'depends_on', 'param1', name, 'param2', {ids});
q = ndi.query(ss);
end

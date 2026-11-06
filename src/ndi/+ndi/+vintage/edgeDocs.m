function docs = edgeDocs(S, q, names, className)
%EDGEDOCS The documents a search matches, as light documents holding only some edges.
%
%   DOCS = ndi.vintage.edgeDocs(SESSION, Q, NAMES, CLASSNAME) is, in the
%   order SESSION.database_search(Q) returns them, one ndi.document per
%   matching document that has at least one depends_on entry named in NAMES,
%   holding only its base.id, document_class.class_name = CLASSNAME and those
%   entries, read as edges without decoding the documents
%   (ndi.session/database_search_edges). DOCS is [] (not {}) when the
%   database cannot answer as edges; the caller then searches as before.
%
%   For readers that use nothing of a document but those edges: dependency_value,
%   ndi.vintage.edgeTargets and ndi.v2.edgeIds read the light documents as
%   they read the full ones. A document with none of NAMES is left out, so
%   use it where the query itself requires one of them. Jess Haley,
%   2026-11-06: "Speed can't be slower than v1."

docs = [];
if ~ismethod(S, 'database_search_edges')
    return;
end
edges = S.database_search_edges(q, names);
if ~isstruct(edges)
    return;
end
docs = {};
if isempty(edges)
    return;
end
[order, ~, which] = unique({edges.doc_id}, 'stable');
docs = cell(1, numel(order));
for d = 1:numel(order)
    rows = edges(which == d);
    p = struct('base', struct('id', order{d}), ...
        'document_class', struct('class_name', className), ...
        'depends_on', struct('name', {rows.name}, 'value', {rows.document_id}));
    docs{d} = ndi.document(p);
end
end

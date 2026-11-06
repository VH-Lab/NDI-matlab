function docs = valueDocs(S, q, paths, className)
%VALUEDOCS The documents a search matches, as light documents holding only some text fields.
%
%   DOCS = ndi.vintage.valueDocs(SESSION, Q, PATHS, CLASSNAME) is, in the
%   order SESSION.database_search(Q) returns them, one ndi.document per
%   matching document, holding only its base.id, document_class.class_name =
%   CLASSNAME and the text at each plain dot-path of PATHS ('' where it has
%   none), read from the database's text index without decoding the
%   documents (ndi.session/database_search_values). DOCS is [] (not {}) when
%   the database cannot answer this way; the caller then searches as before.
%
%   For readers that use nothing of a document but those fields and its id.
%   Jess Haley, 2026-11-06: "Speed can't be slower than v1."

docs = [];
if ~ismethod(S, 'database_search_values')
    return;
end
rows = S.database_search_values(q, paths);
if ~isstruct(rows)
    return;
end
docs = cell(1, numel(rows));
for k = 1:numel(rows)
    p = struct('base', struct('id', rows(k).doc_id), ...
        'document_class', struct('class_name', className));
    for j = 1:numel(paths)
        parts = strsplit(paths{j}, '.');
        p = setfield(p, parts{:}, rows(k).values{j}); %#ok<SFLD>
    end
    docs{k} = ndi.document(p);
end
end

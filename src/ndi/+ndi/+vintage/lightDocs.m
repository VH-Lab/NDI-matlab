function docs = lightDocs(S, q, paths, edgeNames, className, options)
%LIGHTDOCS The documents a search matches, as light documents holding some fields and edges.
%
%   DOCS = ndi.vintage.lightDocs(SESSION, Q, PATHS, EDGENAMES, CLASSNAME) is,
%   in the order SESSION.database_search(Q) returns them, one ndi.document
%   per matching document holding only its base.id, its
%   document_class.class_name (read from the database, else CLASSNAME), the
%   values at PATHS and its depends_on entries named in EDGENAMES, read from
%   the database's indexes without decoding the documents
%   (ndi.session/database_search_values and database_search_edges). A path
%   may have one `[*]` level ('data.dimensions[*].n'): with 'AllElements',
%   true every element is kept, as a struct array, else the first. A value
%   the document does not have is left out of the light document, as it is
%   absent from the full one. DOCS is [] (not {}) when the database cannot
%   answer this way; the caller then searches as before.
%
%   For readers that use nothing but those fields and edges. Jess Haley,
%   2026-11-06: "Speed can't be slower than v1."

arguments
    S
    q
    paths
    edgeNames
    className (1,:) char
    options.AllElements (1,1) logical = false
end
docs = [];
paths = reshape(cellstr(paths), 1, []);
if ~ismethod(S, 'database_search_values') || ~ismethod(S, 'database_search_edges')
    return;
end
rows = S.database_search_values(q, [{'document_class.class_name'}, paths], ...
    'AllElements', options.AllElements);
if ~isstruct(rows)
    return;
end
edgesOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(edgeNames)
    edges = S.database_search_edges(q, edgeNames);
    if ~isstruct(edges)
        docs = [];
        return;
    end
    for k = 1:numel(edges)
        d = edges(k).doc_id;
        e = struct('name', edges(k).name, 'value', edges(k).document_id);
        if isKey(edgesOf, d); edgesOf(d) = [edgesOf(d), e]; else; edgesOf(d) = e; end
    end
end
docs = cell(1, numel(rows));
for k = 1:numel(rows)
    cn = rows(k).values{1};
    if isempty(cn); cn = className; end
    p = struct('base', struct('id', rows(k).doc_id), ...
        'document_class', struct('class_name', cn));
    for j = 1:numel(paths)
        p = place(p, paths{j}, rows(k).values{j + 1}, options.AllElements);
    end
    if isKey(edgesOf, rows(k).doc_id)
        p.depends_on = edgesOf(rows(k).doc_id);
    else
        p.depends_on = struct('name', {}, 'value', {});
    end
    docs{k} = ndi.document(p);
end
end

function p = place(p, path, v, allElements)
% put value V at PATH in struct P; a missing value ('' or []) is left out
star = strfind(path, '[*]');
if isempty(star)
    if isempty(v); return; end
    parts = strsplit(path, '.');
    p = setfield(p, parts{:}, v); %#ok<SFLD>
    return;
end
parent = strsplit(path(1:star(1) - 1), '.');
sub = strsplit(path(star(1) + 4:end), '.');
if ~allElements
    v = {v};
end
arr = [];
try
    arr = getfield(p, parent{:}); %#ok<GFLD>
catch
end
for i = 1:numel(v)
    if isempty(v{i}); continue; end
    if isempty(arr)
        el = struct();
    elseif numel(arr) >= i
        el = arr(i);
    else
        el = struct();
    end
    el = setfield(el, sub{:}, v{i}); %#ok<SFLD>
    if isempty(arr)
        arr = el;
        arr(i) = el;
        if i > 1; arr(1:i-1) = repmat(emptyLike(el), 1, i - 1); end
    else
        [arr, el] = sameFields(arr, el);
        arr(i) = el;
    end
end
if ~isempty(arr)
    p = setfield(p, parent{:}, arr); %#ok<SFLD>
end
end

function e = emptyLike(s)
e = s;
f = fieldnames(s);
for k = 1:numel(f); e.(f{k}) = []; end
end

function [a, b] = sameFields(a, b)
% give struct array A and struct B the same fields (missing ones empty)
fa = fieldnames(a); fb = fieldnames(b);
for k = 1:numel(fb)
    if ~isfield(a, fb{k}); [a.(fb{k})] = deal([]); end
end
for k = 1:numel(fa)
    if ~isfield(b, fa{k}); b.(fa{k}) = []; end
end
b = orderfields(b, a);
end

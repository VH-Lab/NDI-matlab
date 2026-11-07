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
% the paths split once: plain paths, and [*] paths grouped by their array
plain = find(~contains(paths, '[*]'));
plainParts = cellfun(@(x) strsplit(x, '.'), paths(plain), 'UniformOutput', false);
arr = find(contains(paths, '[*]'));
parentOf = cell(1, numel(arr));
subParts = cell(1, numel(arr));
for t = 1:numel(arr)
    star = strfind(paths{arr(t)}, '[*]');
    parentOf{t} = paths{arr(t)}(1:star(1) - 1);
    subParts{t} = strsplit(paths{arr(t)}(star(1) + 4:end), '.');
end
[parents, ~, groupOf] = unique(parentOf, 'stable');
parentParts = cellfun(@(x) strsplit(x, '.'), parents, 'UniformOutput', false);
docs = cell(1, numel(rows));
for k = 1:numel(rows)
    vals = rows(k).values;
    cn = vals{1};
    if isempty(cn); cn = className; end
    p = struct('base', struct('id', rows(k).doc_id), ...
        'document_class', struct('class_name', cn));
    for t = 1:numel(plain)
        v = vals{plain(t) + 1};
        if ~isempty(v)
            p = setNested(p, plainParts{t}, v);
        end
    end
    for g = 1:numel(parents)
        members = find(groupOf == g);
        lists = cell(1, numel(members));
        n = 0;
        for t = 1:numel(members)
            v = vals{arr(members(t)) + 1};
            if ~options.AllElements; v = {v}; end
            lists{t} = v;
            n = max(n, numel(v));
        end
        if n == 0; continue; end
        % one element per index, every element with the same top fields
        tops = unique(cellfun(@(x) x{1}, subParts(members), 'UniformOutput', false), 'stable');
        template = cell2struct(cell(numel(tops), 1), tops, 1);
        els = repmat(template, 1, n);
        any_ = false(1, n);
        for i = 1:n
            el = template;
            for t = 1:numel(members)
                if i <= numel(lists{t}) && ~isempty(lists{t}{i})
                    el = setNested(el, subParts{members(t)}, lists{t}{i});
                    any_(i) = true;
                end
            end
            els(i) = el;
        end
        last = find(any_, 1, 'last');
        if isempty(last); continue; end
        p = setNested(p, parentParts{g}, els(1:last));
    end
    if isKey(edgesOf, rows(k).doc_id)
        p.depends_on = edgesOf(rows(k).doc_id);
    else
        p.depends_on = struct('name', {}, 'value', {});
    end
    docs{k} = ndi.document(p);
end
end

function s = setNested(s, parts, v)
% s.(parts{1}).(parts{2})... = v, creating structs on the way
if isscalar(parts)
    s.(parts{1}) = v;
    return;
end
if isfield(s, parts{1}) && isstruct(s.(parts{1})) && isscalar(s.(parts{1}))
    sub = s.(parts{1});
else
    sub = struct();
end
s.(parts{1}) = setNested(sub, parts(2:end), v);
end

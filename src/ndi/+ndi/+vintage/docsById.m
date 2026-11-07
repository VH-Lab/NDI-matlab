function m = docsById(S, ids, options)
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
    options.LightPaths = {}     % read light documents of these paths (valueDocs)
    options.LightClass = 'entity'   % ... for documents of this class only
    options.RawBlocks = {}      % read these top-level blocks as stored, not rebuilt (database_search_json)
end

m = containers.Map('KeyType', 'char', 'ValueType', 'any');
ids = unique(reshape(cellstr(ids), 1, []), 'stable');
ids = ids(~cellfun(@isempty, ids));
for c = 1:200:numel(ids)
    part = ids(c:min(c + 199, numel(ids)));
    q = ndi.v2.anyOf(cellfun(@(i) ndi.query('base.id', 'exact_string', i, ''), ...
        part, 'UniformOutput', false));
    found = [];
    if ~isempty(options.RawBlocks)
        % 'RawBlocks': documents of LightClass made of these top-level
        % blocks as jsondecode reads them from the stored document, not
        % rebuilt (ndi.session/database_search_json); for a reader that
        % reads leaf values and accepts either shape. Any other is read
        % whole.
        found = rawDocs(S, q, cellstr(options.RawBlocks), options.LightClass, part);
    elseif ~isempty(options.LightPaths)
        % 'LightPaths': light documents holding only base.id and these text
        % fields, from the database's text index (ndi.vintage.valueDocs), for
        % a reader that needs nothing else; the documents where it cannot
        found = ndi.vintage.valueDocs(S, q, cellstr(options.LightPaths), options.LightClass);
        if iscell(found)
            % only a document OF LightClass is answered light (its reader
            % reads that class's fields); any other is read whole
            isLight = cellfun(@(d) strcmp(char(d.document_properties.document_class.class_name), ...
                options.LightClass), found);
            found = found(isLight);
            got = cellfun(@(d) char(d.document_properties.base.id), found, 'UniformOutput', false);
            rest = part(~ismember(part, got));
            if ~isempty(rest)
                found = [found(:); reshape(S.database_search(ndi.v2.anyOf(cellfun(@(i) ...
                    ndi.query('base.id', 'exact_string', i, ''), rest, 'UniformOutput', false))), [], 1)];
            end
        end
    end
    if ~iscell(found)
        found = S.database_search(q);
    end
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

function found = rawDocs(S, q, blocks, className, part)
found = [];
if ~ismethod(S, 'database_search_json')
    return;
end
rows = S.database_search_json(q, [{'document_class'}, blocks]);
if ~isstruct(rows)
    return;
end
found = {};
for k = 1:numel(rows)
    v = rows(k).values;
    dc = v{1};
    if ~(isstruct(dc) && isfield(dc, 'class_name') && strcmp(char(dc.class_name), className))
        continue;
    end
    p = struct('document_class', dc);
    for b = 1:numel(blocks)
        if ~isempty(v{b + 1}) || strcmp(blocks{b}, 'depends_on')
            p.(blocks{b}) = v{b + 1};
        end
    end
    if ~isfield(p, 'base') || ~isstruct(p.base)
        continue;
    end
    if isempty(p.depends_on)
        p.depends_on = struct('name', {}, 'value', {});
    end
    found{end+1, 1} = ndi.document(p); %#ok<AGROW>
end
got = cellfun(@(d) char(d.document_properties.base.id), found, 'UniformOutput', false);
rest = part(~ismember(part, got));
if ~isempty(rest)
    found = [found; reshape(S.database_search(ndi.v2.anyOf(cellfun(@(i) ...
        ndi.query('base.id', 'exact_string', i, ''), rest, 'UniformOutput', false))), [], 1)];
end
end

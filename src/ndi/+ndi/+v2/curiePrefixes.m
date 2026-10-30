function ix = curiePrefixes(schemaPath)
%CURIEPREFIXES Every name a reader accepts for each CURIE prefix, and how each is written.
%
%   IX = ndi.v2.curiePrefixes(SCHEMAPATH) (SCHEMAPATH defaults to
%   DID_SCHEMA_PATH) reads SCHEMAPATH/CURIE_lookups_meta.json. did-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19: "a CURIE's prefix is
%   written as its issuer cites it (the registry entry's spelling ...);
%   readers match a prefix by key, spelling or synonym, ignoring case;
%   registry keys stay the lowercase Bioregistry prefixes."
%
%   IX is a struct of four containers.Map:
%     names      lower(name) -> registry key, for the entry's key, its
%                `spelling` and its `synonyms`
%     spelling   registry key -> the prefix as a document writes it
%     legacy     lower(old prefix) -> {registry key, id prefix}: an old
%                prefix that splits the id differently (`WBStrain:00004246`
%                is `WormBase:WBStrain00004246`, `format:1929` is
%                `EDAM:format_1929`)
%     writtenAs  registry key -> {registry key, id prefix}: an entry cited
%                through another (`cellosaurus:0030` is `RRID:CVCL_0030`)
%     uriBase    registry key -> the entry's `uri_base`, which the local id
%                is appended to to make the term's IRI (ndi.v2.curieIri)
%
%   A schema built before the spellings (no `spelling` on its entries) gives
%   an index that knows each entry by its key and writes it as its key, the
%   lowercase prefix such a schema expects. No registry file gives an empty
%   index: prefixes are then compared ignoring case and written as given.
%
%   jsondecode turns a key that is not a MATLAB name into one that is
%   (`pubchem.compound` -> `pubchem_compound`); those are the keys here.
%
%   The same rules as DID-matlab's did2.schema.curiePrefixIndex, read here
%   from the schema file so the import does not need that DID-matlab version.
%   Read once per file path and kept for the MATLAB session (matchTerm asks
%   for it once per document); `clear ndi.v2.curiePrefixes` drops it.
%
%   See also ndi.v2.curieKey, ndi.v2.curieSpelling, ndi.v2.curieForms.

arguments
    schemaPath = getenv('DID_SCHEMA_PATH')
end

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
f = '';
if ~isempty(schemaPath)
    f = ndi.v2.schemaFile(char(schemaPath), 'CURIE_lookups_meta.json');   % by name, any layout
end
if isempty(f) || ~isfile(f)
    ix = buildIndex(struct());
    return;
end
if isKey(cache, f)
    ix = cache(f);
    return;
end
try
    reg = jsondecode(fileread(f));
catch
    reg = struct();
end
ix = buildIndex(reg);
cache(f) = ix;
end

% ===================== helpers =============================================

function ix = buildIndex(registry)
arguments
    registry % a parsed CURIE_lookups_meta.json
end

ix = struct( ...
    'names', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'spelling', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'legacy', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'writtenAs', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'uriBase', containers.Map('KeyType', 'char', 'ValueType', 'char'));
if ~isstruct(registry) || ~isscalar(registry) || ~isfield(registry, 'prefixes') ...
        || ~isstruct(registry.prefixes)
    return;
end
keys = fieldnames(registry.prefixes);
for i = 1:numel(keys)
    k = keys{i};
    e = registry.prefixes.(k);
    sp = textOf(e, 'spelling');
    if isempty(sp)
        sp = k;
    end
    ix.spelling(k) = sp;
    base = textOf(e, 'uri_base');
    if ~isempty(base)
        ix.uriBase(k) = base;
    end
    names = [{k}, textList(e, 'synonyms')];
    if isfield(e, 'written_as') && isstruct(e.written_as)
        % spelled through another entry, so its spelling names that entry
        ix.writtenAs(k) = {matlab.lang.makeValidName(textOf(e.written_as, 'prefix')), ...
            textOf(e.written_as, 'id_prefix')};
    else
        names{end+1} = sp; %#ok<AGROW>
    end
    if isfield(e, 'legacy_rewrite') && isstruct(e.legacy_rewrite)
        old = textOf(e.legacy_rewrite, 'legacy_prefix');
        if ~isempty(old)
            ix.legacy(lower(old)) = {k, textOf(e.legacy_rewrite, 'id_prefix')};
        end
    end
    for n = 1:numel(names)
        nm = lower(names{n});
        if ~isempty(nm) && ~isKey(ix.names, nm)
            ix.names(nm) = k;
        end
    end
end
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end

v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = char(s.(f));
end
end

function list = textList(s, f)
arguments
    s struct
    f {mustBeText}
end

list = {};
if ~isfield(s, f) || isempty(s.(f))
    return;
end
v = s.(f);
if ischar(v) || isstring(v)
    list = cellstr(v);
elseif iscell(v)
    list = v(cellfun(@(x) ischar(x) || isstring(x), v));
    list = cellfun(@char, list, 'UniformOutput', false);
end
list = reshape(list, 1, []);
end

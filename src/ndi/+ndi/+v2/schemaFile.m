function f = schemaFile(schemaPath, fileName)
%NDI.V2.SCHEMAFILE A did-schema file found by its basename, in any layout.
%
%   F = NDI.V2.SCHEMAFILE(SCHEMAPATH, FILENAME) returns the path of FILENAME
%   (e.g. 'base.json', 'binding_registry_meta.json') for the schema set at
%   SCHEMAPATH (normally getenv('DID_SCHEMA_PATH')). When no such file exists
%   it returns fullfile(SCHEMAPATH, FILENAME), so a caller's isfile() check
%   and its message behave as before.
%
%   Decided by Jess Haley, 2026-10-30 [schema folders by family] (did-schema
%   V_eta_go_forward_class_audit.md): schemas/did_v2/ holds class files only,
%   in family subfolders (core classes at the top; value/, calculation/,
%   data_body/, time_reference/, retiring/); the non-class JSON moves to
%   schemas/registry/ (authored) and schemas/generated/ (written by tools).
%   Siblings first: NDI reads both layouts before did-schema moves. The exact
%   folders are not final, so a file is found by NAME:
%
%     a class file   at any depth under SCHEMAPATH, outside folders named
%                    `registry` or `generated` and hidden folders;
%     anything else  (a *_meta.json registry, ndi_reserved_keys.json, a
%                    did_v2_* data file) at any depth under did-schema's
%                    `schemas` folder when SCHEMAPATH is inside one
%                    (schemas/did_v2, schemas/did_v2/stable), else under
%                    SCHEMAPATH itself (the flat folder CI assembles). A
%                    did_v2_* name is also looked for as V_eta_*
%                    ([markdown cleanup and rename] item 6), new name first.
%
%   Two files with the looked-up basename are the error
%   NDI:v2:duplicateSchemaFile: class names are unique across the tree, and a
%   registry read by its name must be one file. The same rules as DID-matlab's
%   did2.schema.cache.classFilesIn / registryFileIn.
%
%   A file found is remembered per (SCHEMAPATH, FILENAME) while it still
%   exists, because the registry readers ask once per document; a file not
%   found is looked for again on the next call. `clear ndi.v2.schemaFile`
%   forgets.
%
%   See also ndi.v2.schemaClassFiles, ndi.schemas.setFiles.

schemaPath = char(schemaPath);   % '' (an unset DID_SCHEMA_PATH) is allowed
fileName = char(fileName);
persistent memo
if isempty(memo)
    memo = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
key = [schemaPath '|' fileName];
if memo.isKey(key) && isfile(memo(key))
    f = memo(key);
    return;
end
f = lookUp(schemaPath, fileName);
if isfile(f)
    memo(key) = f;
end
end

function f = lookUp(schemaPath, fileName)
f = fullfile(schemaPath, fileName);
if isempty(schemaPath) || ~isfolder(schemaPath)
    return;
end
[~, stem] = fileparts(fileName);
if ndi.v2.schemaClassFiles('-isClass', stem)
    files = ndi.v2.schemaClassFiles(schemaPath);
    if files.isKey(stem)
        f = files(stem);
    end
    return;
end

root = searchRoot(schemaPath);
names = {fileName};
if startsWith(fileName, 'did_v2_')
    names{end+1} = ['V_eta_' fileName(numel('did_v2_')+1:end)];
end
here = dir(root);
rootAbs = here(1).folder;
for n = 1:numel(names)
    hits = dir(fullfile(root, '**', names{n}));
    hits = hits(~[hits.isdir]);
    keep = true(1, numel(hits));
    for k = 1:numel(hits)
        keep(k) = ~any(startsWith(ndi.v2.schemaClassFiles('-below', hits(k).folder, rootAbs), '.'));
    end
    hits = hits(keep);
    if numel(hits) > 1
        error('NDI:v2:duplicateSchemaFile', ...
            ['%d files named %s under %s (%s). A did-schema file is read by ' ...
             'its basename, so the name must be unique ([schema folders by ' ...
             'family]).'], numel(hits), names{n}, root, ...
            strjoin(arrayfun(@(h) fullfile(h.folder, h.name), hits(:)', ...
            'UniformOutput', false), ', '));
    end
    if isscalar(hits)
        f = fullfile(hits.folder, hits.name);
        return;
    end
end
end

function root = searchRoot(schemaPath)
% did-schema's `schemas` folder when SCHEMAPATH is in one (up to two levels
% up), else SCHEMAPATH
root = schemaPath;
probe = regexprep(char(schemaPath), '[\\/]+$', '');
for up = 0:2
    [parent, leaf] = fileparts(probe);
    if strcmp(leaf, 'schemas')
        root = probe;
        return;
    end
    if isempty(parent) || strcmp(parent, probe)
        return;
    end
    probe = parent;
end
end

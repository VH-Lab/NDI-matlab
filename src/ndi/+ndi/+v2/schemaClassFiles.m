function out = schemaClassFiles(setDir, varargin)
%NDI.V2.SCHEMACLASSFILES Class name -> schema file, at any depth of a schema set.
%
%   FILES = NDI.V2.SCHEMACLASSFILES(SETDIR) returns a containers.Map from
%   class name to the full path of its schema file, for every class file under
%   SETDIR at any depth: did-schema's family layout (schemas/did_v2/ with
%   value/, calculation/, data_body/, time_reference/, retiring/ subfolders;
%   Decided by Jess Haley, 2026-10-30 [schema folders by family]), the old
%   tiers (schemas/did_v2/stable, draft) and a flat assembled folder alike.
%
%   Skipped: folders named `registry` or `generated`, hidden folders, and
%   files that are not classes (TF = NDI.V2.SCHEMACLASSFILES('-isClass', STEM):
%   *_meta, ndi_reserved_keys, index, topics, did_v2_*, V_eta_*). A class held
%   twice is the error NDI:v2:duplicateSchemaFile.
%
%   PARTS = NDI.V2.SCHEMACLASSFILES('-below', FOLDER, ROOT): the folder names
%   of FOLDER below ROOT (both as dir() reports them).
%
%   Mirrors DID-matlab's did2.schema.cache.classFilesIn / isClassFileName.
%
%   See also ndi.v2.schemaFile, ndi.schemas.setFiles.

if ischar(setDir) && strcmp(setDir, '-isClass')
    out = isClassName(char(varargin{1}));
    return;
end
if ischar(setDir) && strcmp(setDir, '-below')
    out = below(char(varargin{1}), char(varargin{2}));
    return;
end

out = containers.Map('KeyType', 'char', 'ValueType', 'char');
setDir = char(setDir);
if isempty(setDir) || ~isfolder(setDir)
    return;
end
here = dir(setDir);
root = here(1).folder;
entries = dir(fullfile(setDir, '**', '*.json'));
for k = 1:numel(entries)
    if entries(k).isdir
        continue;
    end
    [~, name] = fileparts(entries(k).name);
    if ~isClassName(name)
        continue;
    end
    parts = below(entries(k).folder, root);
    if any(ismember(parts, {'registry', 'generated'})) || any(startsWith(parts, '.'))
        continue;
    end
    p = fullfile(entries(k).folder, entries(k).name);
    if out.isKey(name)
        error('NDI:v2:duplicateSchemaFile', ...
            ['Class "%s" has two schema files: %s and %s. Class names are ' ...
             'unique across the schema tree ([schema folders by family]).'], ...
            name, out(name), p);
    end
    out(name) = p;
end
end

function tf = isClassName(name)
tf = ~(endsWith(name, '_meta') ...
    || any(strcmp(name, {'index', 'topics', 'ndi_reserved_keys'})) ...
    || startsWith(name, 'did_v2_') || startsWith(name, 'V_eta_'));
end

function parts = below(folder, root)
if startsWith(folder, root)
    folder = folder(numel(root)+1:end);
end
parts = strsplit(folder, {'/', '\'});
parts = parts(~cellfun(@isempty, parts));
end

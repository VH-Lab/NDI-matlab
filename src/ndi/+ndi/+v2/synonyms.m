function names = synonyms(node, options)
%SYNONYMS The names an ontology term goes by: its label and its synonyms.
%
%   NAMES = ndi.v2.synonyms(NODE) is a cell array of the names of the term
%   NODE ('NCBITaxon:6239' gives 'Caenorhabditis elegans', 'C. elegans',
%   ...), from ndi.ontology.lookup (VH-Lab ndi-ontology-matlab). Each node
%   is looked up once and kept on disk, one file per node, in FOLDER (by
%   default ndi.v2.synonymFolder()), so a later search, in this or any MATLAB
%   session, reads the file. {} when the node is not a CURIE, when
%   ndi.ontology is not installed, or when the lookup fails (offline, an
%   unknown prefix): a failure is not kept on disk, so the node is asked
%   for again in a new session, but not again in this one.
%
%   Options:
%     'Refresh'  true: look the node up again and rewrite its file
%     'Folder'   where the files are
%
%   See also ndi.v2.synonymFolder, ndi.v2.searchStatements, ndi.entity.search.

arguments
    node (1,:) char
    options.Refresh (1,1) logical = false
    options.Folder (1,:) char = ndi.v2.synonymFolder()
end
persistent failed
if isempty(failed), failed = containers.Map('KeyType', 'char', 'ValueType', 'logical'); end
names = {};
if isempty(regexp(node, '^[A-Za-z][\w.-]*:\S+$', 'once')), return; end
file = fullfile(options.Folder, [regexprep(lower(node), '[^a-z0-9_.-]', '_') '.json']);
if ~options.Refresh && isfile(file)
    try
        c = jsondecode(fileread(file));
        names = asNames(c.names);
        return;
    catch
        % an unreadable file is looked up again and rewritten
    end
end
if ~options.Refresh && isKey(failed, lower(node)), return; end
if isempty(which('ndi.ontology.lookup'))
    failed(lower(node)) = true;
    return;
end
try
    [~, name, ~, ~, syn] = ndi.ontology.lookup(node);
catch
    failed(lower(node)) = true;
    return;
end
names = asNames([{name}, reshape(cellstr(syn), 1, [])]);
try
    if ~isfolder(options.Folder), mkdir(options.Folder); end
    c = struct('node', node, 'names', {names}, ...
        'looked_up', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
    fid = fopen(file, 'w');
    if fid > 0
        fwrite(fid, jsonencode(c), 'char');
        fclose(fid);
    end
catch
    % a folder that cannot be written: the names are still returned
end
end

function n = asNames(x)
% a row cell array of the non-empty, distinct names in X
if isempty(x), n = {}; return; end
n = cellstr(x);
n = reshape(n(~cellfun(@isempty, n)), 1, []);
n = unique(n, 'stable');
end

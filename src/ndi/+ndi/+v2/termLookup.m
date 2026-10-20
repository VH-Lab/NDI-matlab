function L = termLookup(node, options)
%TERMLOOKUP What an ontology says about a term, looked up once per machine.
%
%   L = ndi.v2.termLookup(NODE) is a struct of ndi.ontology.lookup's answer
%   for the CURIE NODE (VH-Lab ndi-ontology-matlab):
%
%     found       true when the ontology answered (now or in the cache)
%     id          the id the ontology gives, e.g. 'WBls:0000038'
%     label       the ontology's own name, e.g. 'L4 larva Ce'
%     definition  its definition ('' when it has none)
%     synonyms    a row cell array of its other names
%
%   Each node is looked up once and kept on disk, one file per node, in
%   FOLDER (ndi.v2.synonymFolder() by default; the same files as
%   ndi.v2.synonyms), so a later call, in this or any MATLAB session, reads
%   the file. A file written before the definition was kept (it holds only
%   `names`) gives its first name as the label, the rest as synonyms and no
%   definition, until 'Refresh' looks the node up again. found is false when
%   NODE is not a CURIE, when ndi.ontology is not installed, or when the
%   lookup fails (offline, an unknown prefix); a failure is not kept on disk,
%   so the node is asked for again in a new session, but not again in this
%   one.
%
%   Options:
%     'Refresh'  true: look the node up again and rewrite its file
%     'Folder'   where the files are
%
%   See also ndi.term, ndi.v2.synonyms, ndi.v2.synonymFolder.

arguments
    node {mustBeText}
    options.Refresh (1,1) logical = false
    options.Folder (1,:) char = ndi.v2.synonymFolder()
end
persistent failed
if isempty(failed), failed = containers.Map('KeyType', 'char', 'ValueType', 'logical'); end
node = strtrim(char(node));
L = struct('found', false, 'id', '', 'label', '', 'definition', '', 'synonyms', {{}});
if isempty(regexp(node, '^[A-Za-z][\w.-]*:\S+$', 'once')), return; end
file = fullfile(options.Folder, [regexprep(lower(node), '[^a-z0-9_.-]', '_') '.json']);
if ~options.Refresh && isfile(file)
    try
        c = jsondecode(fileread(file));
        if isfield(c, 'label')
            L = struct('found', true, 'id', textOf(c, 'id'), 'label', textOf(c, 'label'), ...
                'definition', textOf(c, 'definition'), 'synonyms', {asNames(fieldOr(c, 'synonyms'))});
            return;
        end
        % a names-only file (written by ndi.v2.synonyms before 2026-10-20):
        % its first name is the label, the rest synonyms, no definition;
        % 'Refresh' looks the node up again for the definition
        names = asNames(fieldOr(c, 'names'));
        if ~isempty(names)
            L = struct('found', true, 'id', node, 'label', names{1}, 'definition', '', ...
                'synonyms', {names(2:end)});
            return;
        end
    catch
        % an unreadable file is looked up again and rewritten
    end
end
if (~options.Refresh && isKey(failed, lower(node))) || isempty(which('ndi.ontology.lookup'))
    return;
end
try
    [id, label, ~, definition, syn] = ndi.ontology.lookup(node);
catch
    failed(lower(node)) = true;
    return;
end
syn = asNames(syn);
syn = syn(~strcmp(syn, char(label)));
L = struct('found', true, 'id', char(id), 'label', char(label), 'definition', char(definition), ...
    'synonyms', {syn});
try
    if ~isfolder(options.Folder), mkdir(options.Folder); end
    c = struct('node', node, 'names', {asNames([{L.label}, L.synonyms])}, 'id', L.id, ...
        'label', L.label, 'definition', L.definition, 'synonyms', {L.synonyms}, ...
        'looked_up', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
    fid = fopen(file, 'w');
    if fid > 0
        fwrite(fid, jsonencode(c), 'char');
        fclose(fid);
    end
catch
    % a folder that cannot be written: the answer is still returned
end
end

function n = asNames(x)
% a row cell array of the non-empty, distinct names in X
arguments
    x
end
if isempty(x), n = {}; return; end
n = cellstr(x);
n = reshape(n(~cellfun(@isempty, n)), 1, []);
n = unique(n, 'stable');
end

function v = fieldOr(s, f)
arguments
    s struct
    f {mustBeText}
end
v = {};
if isfield(s, f), v = s.(f); end
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end
v = '';
if isfield(s, f) && (ischar(s.(f)) || isstring(s.(f))), v = char(s.(f)); end
end

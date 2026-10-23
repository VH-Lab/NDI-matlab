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
%   The lookup and its cache are ndi.v2.termLookup's; this is its label and
%   synonyms.
%
%   See also ndi.v2.termLookup, ndi.v2.synonymFolder, ndi.v2.searchStatements,
%   ndi.entity.search.

arguments
    node (1,:) char
    options.Refresh (1,1) logical = false
    options.Folder (1,:) char = ndi.v2.synonymFolder()
end
L = ndi.v2.termLookup(node, 'Refresh', options.Refresh, 'Folder', options.Folder);
names = {};
if L.found
    names = asNames([{L.label}, L.synonyms]);
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

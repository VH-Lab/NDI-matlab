function f = synonymFolder()
%SYNONYMFOLDER Where ndi.v2.synonyms keeps the names it has looked up.
%
%   F = ndi.v2.synonymFolder() is the folder named by the environment
%   variable NDI_SYNONYM_CACHE when it is set, else 'ontology-synonyms'
%   beside NDI's file cache (ndi.common.PathConstants.FileCacheFolder), or
%   in tempdir when MATLAB has no userpath.
%
%   See also ndi.v2.synonyms.

f = getenv('NDI_SYNONYM_CACHE');
if ~isempty(f), return; end
if ~isempty(userpath)
    f = fullfile(userpath, 'Documents', 'NDI', 'ontology-synonyms');
else
    f = fullfile(tempdir, 'NDI', 'ontology-synonyms');
end
end

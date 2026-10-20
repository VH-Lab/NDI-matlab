function iri = curieIri(curie, index)
%CURIEIRI The IRI a CURIE stands for ('' when it cannot be made).
%
%   IRI = ndi.v2.curieIri(CURIE) appends the CURIE's local id to its
%   registry entry's `uri_base` (did-schema CURIE_lookups_meta.json):
%
%     'WBls:0000038'          -> 'http://purl.obolibrary.org/obo/WBls_0000038'
%     'time:intervalDuring'   -> 'http://www.w3.org/2006/time#intervalDuring'
%     'WBStrain:00004246'     -> 'https://www.wormbase.org/get?name=WBStrain00004246'
%
%   The prefix is read as ndi.v2.curieKey reads it (key, spelling or
%   synonym, ignoring case; a legacy prefix is rewritten first). '' when
%   CURIE is not a CURIE, its prefix is not in the registry, or the entry
%   has no `uri_base`.
%
%   INDEX defaults to ndi.v2.curiePrefixes() (the schema on DID_SCHEMA_PATH).
%
%   See also ndi.v2.curieKey, ndi.term.

arguments
    curie {mustBeText}
    index = []   % an ndi.v2.curiePrefixes, or [] for DID_SCHEMA_PATH's
end

if isempty(index)
    index = ndi.v2.curiePrefixes();
end
iri = '';
s = strtrim(char(curie));
if isempty(s) || ~isfield(index, 'uriBase')
    return;
end
[k, local, ~, ok] = resolveCurie(s, index);
if ok && ~isempty(k) && isKey(index.uriBase, k)
    iri = [index.uriBase(k) local];
end
end

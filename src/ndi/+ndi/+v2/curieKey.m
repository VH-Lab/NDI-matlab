function key = curieKey(curie, index)
%CURIEKEY The form in which two CURIEs are compared.
%
%   KEY = ndi.v2.curieKey(CURIE) is '<registry key>:<local id>', so two
%   CURIEs name the same thing exactly when their keys are equal: a prefix is
%   read by key, spelling or synonym, ignoring case (did-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19).
%
%     'NCBITaxon:6239', 'ncbitaxon:6239', 'NCBIT:6239'  -> 'ncbitaxon:6239'
%     'PMID:123', 'pubmed:123'                          -> 'pubmed:123'
%     'WBStrain:00004246', 'WormBase:WBStrain00004246'  -> 'wormbase:WBStrain00004246'
%
%   The local id keeps its case. A prefix the registry does not know is
%   compared ignoring case. Text that is not a CURIE comes back trimmed.
%
%   INDEX defaults to ndi.v2.curiePrefixes() (the schema on DID_SCHEMA_PATH).
%
%   See also ndi.v2.curieSpelling, ndi.v2.curieForms, ndi.v2.matchTerm.

arguments
    curie {mustBeText}
    index = []   % an ndi.v2.curiePrefixes, or [] for DID_SCHEMA_PATH's
end

if isempty(index)
    index = ndi.v2.curiePrefixes();
end
s = strtrim(char(curie));
if isempty(s)
    key = s;
    return;
end
[k, local, ~, ok] = resolveCurie(s, index);
if ~ok
    key = s;
elseif isempty(k)
    p = regexp(s, '^[^:]*', 'match', 'once');
    key = [lower(p) ':' local];
else
    key = [k ':' local];
end
end

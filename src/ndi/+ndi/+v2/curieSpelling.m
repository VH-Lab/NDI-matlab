function out = curieSpelling(curie, index)
%CURIESPELLING A CURIE written the way its issuer cites it.
%
%   OUT = ndi.v2.curieSpelling(CURIE) rewrites CURIE's prefix to its registry
%   entry's `spelling` (did-schema V_eta_prefix_spelling_plan.md, signed
%   2026-10-19): 'pmid:123' -> 'PMID:123', 'WBStrain:00004246' ->
%   'WormBase:WBStrain00004246', 'cellosaurus:0030' -> 'RRID:CVCL_0030'.
%   A prefix the registry does not know, and text that is not a CURIE, come
%   back unchanged (trimmed).
%
%   INDEX defaults to ndi.v2.curiePrefixes() (the schema on DID_SCHEMA_PATH).
%
%   See also ndi.v2.curieKey, ndi.v2.curiePrefixes.

arguments
    curie {mustBeText}
    index = []   % an ndi.v2.curiePrefixes, or [] for DID_SCHEMA_PATH's
end

if isempty(index)
    index = ndi.v2.curiePrefixes();
end
s = strtrim(char(curie));
if isempty(s)
    out = s;
    return;
end
[k, local, sp, ok] = resolveCurie(s, index);
if ~ok || isempty(k)
    out = s;
else
    out = [sp ':' local];
end
end

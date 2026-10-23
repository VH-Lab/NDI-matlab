function forms = curieForms(curie, index)
%CURIEFORMS Every way of writing a CURIE that names the same thing.
%
%   FORMS = ndi.v2.curieForms(CURIE) is a cell array of CURIE strings a
%   reader takes as CURIE: its prefix as the entry's key, its `spelling` and
%   each of its `synonyms`, plus the old form of a `legacy_rewrite` entry
%   (`WBStrain:00004246` beside `WormBase:WBStrain00004246`). A database
%   query matches a stored node against all of them, ignoring case, since a
%   dataset may have been written before the spellings (did-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19). {CURIE} when the
%   prefix is not registered or CURIE is not a CURIE.
%
%   INDEX defaults to ndi.v2.curiePrefixes() (the schema on DID_SCHEMA_PATH).
%
%   See also ndi.v2.curieKey, ndi.v2.termQuery.

arguments
    curie {mustBeText}
    index = []   % an ndi.v2.curiePrefixes, or [] for DID_SCHEMA_PATH's
end

if isempty(index)
    index = ndi.v2.curiePrefixes();
end
s = strtrim(char(curie));
forms = {s};
[k, local, ~, ok] = resolveCurie(s, index);
if ~ok || isempty(k)
    return;
end
names = index.names.keys();
vals = index.names.values();
prefixes = names(strcmp(vals, k));
if isKey(index.spelling, k)
    prefixes{end+1} = index.spelling(k);
end
for n = 1:numel(prefixes)
    forms{end+1} = [prefixes{n} ':' local]; %#ok<AGROW>
end
% the old form, where the entry has one and the local id carries its id prefix
lk = index.legacy.keys();
for j = 1:numel(lk)
    rw = index.legacy(lk{j});
    if strcmp(rw{1}, k) && startsWith(local, rw{2})
        forms{end+1} = [lk{j} ':' local(numel(rw{2}) + 1:end)]; %#ok<AGROW>
    end
end
% an entry written through this one (`cellosaurus:0030` beside `RRID:CVCL_0030`)
wk = index.writtenAs.keys();
for j = 1:numel(wk)
    wa = index.writtenAs(wk{j});
    if strcmp(wa{1}, k) && startsWith(local, wa{2})
        forms{end+1} = [wk{j} ':' local(numel(wa{2}) + 1:end)]; %#ok<AGROW>
    end
end
[~, first] = unique(lower(forms), 'stable');
forms = forms(first);
end

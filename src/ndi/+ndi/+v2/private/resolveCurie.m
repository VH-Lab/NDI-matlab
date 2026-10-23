function [key, local, spelling, ok] = resolveCurie(s, index)
%RESOLVECURIE Split a CURIE and find its registry entry.
%
%   [KEY, LOCAL, SPELLING, OK] = resolveCurie(S, INDEX). OK is false when S
%   is not a CURIE (no `prefix:` in front). Otherwise KEY is the registry key
%   the prefix names ('' when the registry does not know it), LOCAL is the
%   local id as the entry writes it, and SPELLING is the prefix as a document
%   writes it. The prefix is matched by the entry's key, `spelling` or
%   `synonyms`, ignoring case; a `legacy_rewrite` or `written_as` moves part
%   of the meaning into the local id (did-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19).

arguments
    s char         % one CURIE, trimmed
    index struct   % an ndi.v2.curiePrefixes
end

key = ''; local = ''; spelling = '';
tok = regexp(s, '^([A-Za-z][A-Za-z0-9_.\-]*):(.*)$', 'tokens', 'once');
ok = ~isempty(tok);
if ~ok
    return;
end
p = tok{1};
local = tok{2};
spelling = p;
lp = lower(p);
if isKey(index.legacy, lp)
    rw = index.legacy(lp);
    key = rw{1};
    local = [rw{2} local];
elseif isKey(index.names, lp)
    key = index.names(lp);
else
    lv = lower(matlab.lang.makeValidName(p));
    if isKey(index.names, lv)
        key = index.names(lv);
    end
end
if isempty(key)
    return;
end
if isKey(index.writtenAs, key)
    wa = index.writtenAs(key);
    if ~startsWith(local, wa{2})
        local = [wa{2} local];
    end
    key = wa{1};
end
if isKey(index.spelling, key)
    spelling = index.spelling(key);
end
end

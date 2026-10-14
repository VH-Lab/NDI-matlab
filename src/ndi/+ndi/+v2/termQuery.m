function q = termQuery(path, patterns)
%TERMQUERY An ndi.query for a term field matching any of PATTERNS.
%
%   Q = ndi.v2.termQuery(PATH, PATTERNS): PATH is a term field (e.g.
%   'subject_statement.variable'); each pattern matches PATH.name ignoring
%   case or PATH.node exactly ('*' a wildcard, '\*' a literal star). Q is []
%   when nothing can be sent to the database: no text patterns, or a
%   wildcard and no `wildcard` operator in did2 (ndi.v2.hasWildcardOperator).
%   The database answer is a superset to recheck with ndi.v2.matchTerm (a
%   wildcard ignores case on the node too).

q = [];
patterns = cellstr(patterns);
if any(cellfun(@ndi.v2.hasWildcard, patterns)) && ~ndi.v2.hasWildcardOperator()
    return;
end
% a block renamed 2026-10-08 is searched under both names (ndi.v2.vetaAliases)
parts = strsplit(char(path), '.');
paths = cellfun(@(b) strjoin([{b}, parts(2:end)], '.'), ndi.v2.vetaAliases(parts{1}), ...
    'UniformOutput', false);
for k = 1:numel(patterns)
    for j = 1:numel(paths)
        one = termOne(paths{j}, patterns{k});
        if isempty(q), q = one; else, q = q | one; end
    end
end
end

function one = termOne(path, p)
% one pattern on one path: by name (ignoring case) or by node
if ndi.v2.hasWildcard(p)
    one = ndi.query([path '.name'], 'wildcard', p, '') | ndi.query([path '.node'], 'wildcard', p, '');
else
    p = strrep(p, '\*', '*');
    % a node's CURIE prefix ignores case (CURIE_lookups_meta.json); the
    % local part is rechecked exactly by ndi.v2.matchTerm
    one = ndi.query([path '.name'], 'exact_string_anycase', p, '') | ...
        ndi.query([path '.node'], 'exact_string_anycase', p, '');
end
end

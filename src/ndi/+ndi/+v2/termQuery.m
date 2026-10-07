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
for k = 1:numel(patterns)
    p = patterns{k};
    if ndi.v2.hasWildcard(p)
        one = ndi.query([path '.name'], 'wildcard', p, '') | ndi.query([path '.node'], 'wildcard', p, '');
    else
        p = strrep(p, '\*', '*');
        one = ndi.query([path '.name'], 'exact_string_anycase', p, '') | ...
            ndi.query([path '.node'], 'exact_string', p, '');
    end
    if isempty(q), q = one; else, q = q | one; end
end
end

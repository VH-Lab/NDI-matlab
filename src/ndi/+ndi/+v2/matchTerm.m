function tf = matchTerm(t, pattern)
%MATCHTERM Does the term T match PATTERN.
%
%   TF = ndi.v2.matchTerm(T, PATTERN): T is a term ({name, node}) or text
%   (a name). PATTERN matches the name ignoring case or the node exactly;
%   '*' in it is a wildcard (any run of characters), '\*' a literal star.
%   A cell array PATTERN matches when any of its patterns does. A node's
%   CURIE prefix ignores case ('NCBITaxon:6239' is 'ncbitaxon:6239'):
%   CURIE_lookups_meta.json, "Prefixes are matched case-insensitively".
%   The local part stays exact.
%
%   See also ndi.v2.hasWildcard, ndi.entity.search.

if iscell(pattern)
    tf = any(cellfun(@(x) ndi.v2.matchTerm(t, x), pattern));
    return;
end
name = ''; node = '';
if iscell(t) && ~isempty(t), t = t{1}; end
if isstruct(t) && ~isempty(t)
    t = t(1);
    if isfield(t, 'name'), name = char(t.name); end
    if isfield(t, 'node'), node = char(t.node); end
elseif ischar(t) || isstring(t)
    name = char(t);
end
pattern = char(pattern);
node = lowerPrefix(node);
if ~ndi.v2.hasWildcard(pattern)
    pattern = strrep(pattern, '\*', '*');
    tf = strcmpi(name, pattern) || (~isempty(node) && strcmp(node, lowerPrefix(pattern)));
    return;
end
parts = regexp(pattern, '(?<!\\)\*', 'split');
parts = cellfun(@(x) regexptranslate('escape', strrep(x, '\*', '*')), parts, 'UniformOutput', false);
re = ['^' strjoin(parts, '.*') '$'];
tf = ~isempty(regexp(name, re, 'once', 'ignorecase'));
if ~tf && ~isempty(node)
    parts = regexp(lowerPrefix(pattern), '(?<!\\)\*', 'split');
    parts = cellfun(@(x) regexptranslate('escape', strrep(x, '\*', '*')), parts, 'UniformOutput', false);
    tf = ~isempty(regexp(node, ['^' strjoin(parts, '.*') '$'], 'once'));
end
end

function s = lowerPrefix(s)
% the CURIE prefix of S lowercased, when S has one (a ':' with no '*' before it)
k = find(s == ':', 1);
if ~isempty(k) && ~any(s(1:k) == '*')
    s = [lower(s(1:k)) s(k+1:end)];
end
end

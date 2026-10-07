function tf = matchTerm(t, pattern)
%MATCHTERM Does the term T match PATTERN.
%
%   TF = ndi.v2.matchTerm(T, PATTERN): T is a term ({name, node}) or text
%   (a name). PATTERN matches the name ignoring case or the node exactly;
%   '*' in it is a wildcard (any run of characters), '\*' a literal star.
%   A cell array PATTERN matches when any of its patterns does.
%
%   See also ndi.v2.hasWildcard, ndi.subject.find.

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
if ~ndi.v2.hasWildcard(pattern)
    pattern = strrep(pattern, '\*', '*');
    tf = strcmpi(name, pattern) || (~isempty(node) && strcmp(node, pattern));
    return;
end
parts = regexp(pattern, '(?<!\\)\*', 'split');
parts = cellfun(@(x) regexptranslate('escape', strrep(x, '\*', '*')), parts, 'UniformOutput', false);
re = ['^' strjoin(parts, '.*') '$'];
tf = ~isempty(regexp(name, re, 'once', 'ignorecase')) || ...
    (~isempty(node) && ~isempty(regexp(node, re, 'once')));
end

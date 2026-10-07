function tf = hasWildcard(pattern)
%HASWILDCARD Does PATTERN carry a '*' that is not escaped as '\*'.
%
%   See also ndi.v2.matchTerm.

tf = ischar(pattern) && ~isempty(regexp(pattern, '(?<!\\)\*', 'once'));
end

function v = blockOf(p, block, field, default)
%BLOCKOF P.(BLOCK).(FIELD), or DEFAULT when either is absent.

if nargin < 4, default = []; end
v = default;
if isfield(p, block) && isstruct(p.(block)) && isfield(p.(block), field)
    v = p.(block).(field);
end
end

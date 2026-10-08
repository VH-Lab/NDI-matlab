function v = blockOf(p, block, field, default)
%BLOCKOF P.(BLOCK).(FIELD), or DEFAULT when either is absent.

if nargin < 4, default = []; end
v = default;
% a block renamed 2026-10-08 is read under either name (ndi.v2.vetaAliases)
names = ndi.v2.vetaAliases(block);
for k = 1:numel(names)
    if isfield(p, names{k}) && isstruct(p.(names{k})) && isfield(p.(names{k}), field)
        v = p.(names{k}).(field);
        return;
    end
end
end

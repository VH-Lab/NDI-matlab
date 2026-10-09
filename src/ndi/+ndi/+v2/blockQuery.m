function q = blockQuery(path, op, param1, param2)
%BLOCKQUERY An ndi.query on a block field under every name the block has had.
%
%   Q = ndi.v2.blockQuery(PATH, OP, PARAM1, PARAM2) is ndi.query(PATH, OP,
%   PARAM1, PARAM2) ORed with the same query on each other name of PATH's
%   first part: a block renamed 2026-10-08 (ndi.v2.vetaAliases), and for an
%   entity class merged into `entity` that day (ndi.v2.entityTypesFor) the
%   `entity` block, so 'subject.local_identifier' also matches
%   'entity.local_identifier'.
%
%   See also ndi.v2.blockOf, ndi.v2.isaQuery.

if nargin < 4, param2 = ''; end
parts = strsplit(char(path), '.');
names = ndi.v2.vetaAliases(parts{1});
if ~isempty(ndi.v2.entityTypesFor(parts{1}))
    names{end+1} = 'entity';
end
q = [];
for k = 1:numel(names)
    one = ndi.query(strjoin([names(k), parts(2:end)], '.'), op, param1, param2);
    if isempty(q), q = one; else, q = q | one; end
end
end

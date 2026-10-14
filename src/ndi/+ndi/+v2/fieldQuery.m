function q = fieldQuery(path, op, value)
%FIELDQUERY A field query on a V_eta block under its current or its old name.
%
%   Q = ndi.v2.fieldQuery('statement.variable.name', 'exact_string', V) is the
%   ndi.query on that path OR on 'subject_statement.variable.name', the
%   block's name until 2026-10-08 (ndi.v2.vetaAliases on the first segment).
%
%   See also ndi.v2.termQuery, ndi.v2.isaQuery.

parts = strsplit(char(path), '.');
names = ndi.v2.vetaAliases(parts{1});
q = [];
for k = 1:numel(names)
    p = strjoin([names(k), parts(2:end)], '.');
    one = ndi.query(p, op, value, '');
    if isempty(q), q = one; else, q = q | one; end
end
end

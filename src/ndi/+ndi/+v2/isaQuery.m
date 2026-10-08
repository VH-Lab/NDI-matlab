function q = isaQuery(className)
%ISAQUERY An `isa` query for a V_eta class under its current or its old name.
%
%   Q = ndi.v2.isaQuery(CLASSNAME): ndi.query('', 'isa', CLASSNAME, '') OR the
%   same for the name it had before 2026-10-08 (ndi.v2.vetaAliases), so
%   'assertion' also finds documents written as `subject_assertion`.
%
%   See also ndi.v2.vetaAliases, ndi.v2.entityQuery.

names = ndi.v2.vetaAliases(className);
q = ndi.query('', 'isa', names{1}, '');
for k = 2:numel(names)
    q = q | ndi.query('', 'isa', names{k}, '');
end
end

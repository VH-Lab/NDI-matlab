function q = statementQuery(direction, kind)
%STATEMENTQUERY Find statements by DIRECTION and value KIND, in either shape.
%
%   Q = ndi.v2.statementQuery(DIRECTION, KIND), e.g.
%   ndi.v2.statementQuery('assertion', 'term'), matches
%     - did-schema #88: a DIRECTION document (or its pre-2026-10-08 alias,
%       ndi.v2.vetaAliases) that lists the value kind KIND among its
%       superclasses -- a statement is a direction plus ONE value-kind mixin;
%     - before #88: the per-kind leaf class, whose name is composed here from
%       the two parts so no caller writes it.
%
%   See also ndi.v2.isaQuery, ndi.v2.vetaAliases, ndi.v2.leafName.

arguments
    direction {mustBeTextScalar}
    kind {mustBeTextScalar}
end

direction = char(direction);
kind = char(kind);
names = ndi.v2.vetaAliases(direction);
d = ndi.query('', 'isa', names{1}, '');
for k = 2:numel(names)
    d = d | ndi.query('', 'isa', names{k}, '');
end
q = (d & ndi.query('', 'isa', kind, '')) | ...
    ndi.query('', 'isa', [kind '_' direction], '');
end

function q = elementClassQuery()
%ELEMENTCLASSQUERY The query part that finds a migrated element's class variable.
%
%   Q = ndi.vintage.elementClassQuery() matches a statement whose variable
%   node is EMPTY:0000401 "software class" (ndi.vintage.elementClassVariable),
%   OR whose variable name is the old phrase 'ndi element class'
%   (ndi.vintage.elementLabel('class')): Decided by Jess Haley, 2026-11-19
%   [variable terms batch 1] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md) moves the variable to the
%   node; databases migrated before then hold the old name. Combine it with
%   ndi.v2.statementQuery('assertion', 'term') and an entity edge, as the
%   readers do. The in-memory test is ndi.vintage.isElementClassVariable.
%
%   See also ndi.vintage.isElementClassVariable, ndi.v2.fieldQuery.

want = ndi.vintage.elementClassVariable();
q = ndi.v2.fieldQuery('statement.variable.node', 'exact_string', want.node) | ...
    ndi.v2.fieldQuery('statement.variable.name', 'exact_string', ndi.vintage.elementLabel('class'));
end

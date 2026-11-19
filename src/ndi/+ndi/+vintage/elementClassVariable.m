function t = elementClassVariable()
%ELEMENTCLASSVARIABLE The variable a migrated element's class is asserted under.
%
%   T = ndi.vintage.elementClassVariable() is the term {node, name}
%   EMPTY:0000401 "software class": Decided by Jess Haley, 2026-11-19
%   [variable terms batch 1] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md), the v1 'ndi element class'
%   variable is looked up by this node. DID-matlab's element migrator writes
%   it through did2.convert.registeredTerm, so the stored name is the
%   registry's label. Databases migrated before that decision hold the old
%   name (ndi.vintage.elementLabel('class')) with no node; the readers accept
%   both (ndi.vintage.isElementClassVariable, ndi.vintage.elementClassQuery).
%
%   See also ndi.vintage.isElementClassVariable, ndi.vintage.elementClassQuery,
%   ndi.vintage.elementLabel.

t = struct('node', 'EMPTY:0000401', 'name', 'software class');
end

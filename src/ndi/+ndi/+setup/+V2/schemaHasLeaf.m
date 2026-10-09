function tf = schemaHasLeaf(leaf)
%SCHEMAHASLEAF True when the V2 schema in use can build statement leaf LEAF.
%
%   TF = ndi.setup.V2.schemaHasLeaf('time_calculation') is true when the schema
%   has that class, or -- on a schema built on or after 2026-10-08, where the
%   join leaves are gone and a statement's value kind is a mixin (did-schema
%   V_eta_entity_composition_plan.md sec. 1) -- when it has the direction
%   (`calculation`) taking a value kind and the kind (`time`). did2.build reads
%   the leaf name either way.
%
%   See also ndi.setup.V2.schemaHasField, ndi.setup.V2.mergedEntities.

c = did2.schema.cache.shared();
tf = c.hasClass(leaf);
if tf || ~ismethod(c, 'valueKindRule')
    return;
end
tok = regexp(leaf, '^(.+)_(assertion|observation|manipulation|calculation)$', 'tokens', 'once');
if isempty(tok)
    return;
end
tf = c.hasClass(tok{2}) && ~isempty(c.valueKindRule(tok{2})) && c.hasClass(tok{1});
end

function tf = mergedEntities()
%MERGEDENTITIES True when the V2 schema in use has one `entity` class.
%
%   TF = ndi.setup.V2.mergedEntities() is true for a V_eta schema built on or
%   after 2026-10-08, where subject, strain, product, software, person,
%   organization, funding, web_resource, dataset, study, publication, session and
%   epoch merged into one concrete `entity` with a bound `type` (did-schema
%   V_eta_entity_composition_plan.md sec. 4), and false for one built before.
%   The import's writers ask, so they build valid documents against either.
%
%   See also ndi.setup.V2.entityDocuments.

c = did2.schema.cache.shared();
tf = c.hasClass('entity') && ~c.hasClass('subject');
end

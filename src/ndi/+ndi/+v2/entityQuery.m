function q = entityQuery(id)
%ENTITYQUERY Statements about the entity ID: its `entity_id` (or, written before 2026-10-08, `subject_id`) edge.
%
%   Q = ndi.v2.entityQuery(ID) is ndi.query('', 'depends_on', 'entity_id', ID)
%   OR the same for `subject_id`, the edge's name until 2026-10-08.
%
%   See also ndi.v2.isaQuery, ndi.v2.vetaAliases.

q = ndi.query('', 'depends_on', 'entity_id', id) | ndi.query('', 'depends_on', 'subject_id', id);
end

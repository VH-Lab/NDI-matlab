function tf = sessionIdIsEdge()
%SESSIONIDISEDGE True when the V2 schema in use stores a document's session as an edge.
%
%   TF = ndi.v2.sessionIdIsEdge() is true when DID_SCHEMA_PATH holds a V2
%   schema whose `base` declares no `session_id` field: did-schema
%   V_eta_relation_inheritance_plan.md (2026-10-20, a proposal built ahead of
%   signature), where every document has a required `session_id` edge to the
%   session or dataset entity it is stored with, and that entity's base.id IS
%   the session id. False on did-schema main (base.session_id is a field) and
%   when no V2 schema is set.
%
%   Asked by file, the same way as ndi.setup.V2.schemaHasField, so it works
%   before the schema cache is loaded.
%
%   See also ndi.v2.sessionIdOf, ndi.setup.V2.schemaHasField.

p = getenv('DID_SCHEMA_PATH');
tf = ~isempty(p) && isfile(fullfile(p, 'base.json')) && ...
    ~ndi.setup.V2.schemaHasField('base', 'session_id');
end

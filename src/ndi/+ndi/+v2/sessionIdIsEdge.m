function tf = sessionIdIsEdge()
%SESSIONIDISEDGE True when the V2 schema in use stores a document's session as an edge.
%
%   TF = ndi.v2.sessionIdIsEdge() is true when DID_SCHEMA_PATH holds a V2
%   schema whose `base` declares no `session_id` field: did-schema
%   V_eta_relation_inheritance_plan.md (#88), where every document has a
%   required `session_id` edge to the session or dataset entity it is stored
%   with, and that entity's base.id IS the session id. False on a schema whose
%   `base` keeps the field (the v_eta-pre73 schema the migrators are pinned to)
%   and when no V2 schema is set.
%
%   Only the v1 -> V_eta second pass asks (ndi.migrate.internal.withSessionId):
%   the migrators still write the pre-#73 shape, so the pass follows the schema
%   in use. Documents built with did2.build always carry the edge. Asked by
%   file, so it works before the schema cache is loaded.
%
%   See also ndi.v2.sessionIdOf.

p = getenv('DID_SCHEMA_PATH');
f = fullfile(p, 'base.json');
tf = false;
if isempty(p) || ~isfile(f)
    return;
end
d = jsondecode(fileread(f));
tf = true;
if isfield(d, 'fields')
    fields = d.fields;
    for k = 1:numel(fields)
        if iscell(fields), x = fields{k}; else, x = fields(k); end
        if isfield(x, 'name') && strcmp(x.name, 'session_id')
            tf = false;
            return;
        end
    end
end
end

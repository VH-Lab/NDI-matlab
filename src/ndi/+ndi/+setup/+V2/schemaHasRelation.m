function tf = schemaHasRelation(relationName, schemaPath)
%SCHEMAHASRELATION True when the V2 schema in SCHEMAPATH binds a relation of this name.
%
%   TF = ndi.setup.V2.schemaHasRelation(RELATIONNAME, SCHEMAPATH) (SCHEMAPATH
%   defaults to DID_SCHEMA_PATH) is true when binding_registry_meta.json lists
%   RELATIONNAME among its relation_bindings. A relation added to did-schema
%   after a schema copy was made reads as absent, so a maker can report the fact
%   rather than write a relation that schema does not know (e.g. `developed_by`
%   and the dataset's `hosted_by`, did-schema 9bedceb, 2026-10-15). Asked by
%   file, so it works before the schema cache is loaded.
%
%   See also ndi.setup.V2.schemaHasClass, ndi.setup.V2.schemaHasField.

if nargin < 2
    schemaPath = getenv('DID_SCHEMA_PATH');
end
tf = false;
f = fullfile(schemaPath, 'binding_registry_meta.json');
if isempty(schemaPath) || ~isfile(f)
    return;
end
reg = jsondecode(fileread(f));
if ~isfield(reg, 'relation_bindings')
    return;
end
rows = reg.relation_bindings;
for k = 1:numel(rows)
    if iscell(rows), r = rows{k}; else, r = rows(k); end
    if isfield(r, 'relation') && isfield(r.relation, 'name') ...
            && strcmp(r.relation.name, relationName)
        tf = true;
        return;
    end
end
end

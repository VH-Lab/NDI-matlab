function tf = schemaHasClass(className, schemaPath)
%SCHEMAHASCLASS True when the V2 schema in SCHEMAPATH can hold CLASSNAME.
%
%   TF = ndi.setup.V2.schemaHasClass(CLASSNAME, SCHEMAPATH) (SCHEMAPATH defaults
%   to DID_SCHEMA_PATH) is true when the schema has CLASSNAME.json, or -- on a
%   schema built on or after 2026-10-08 -- when CLASSNAME is one of the entity
%   classes merged into `entity` (study, session, subject, ...;
%   ndi.v2.entityTypesFor) and entity.json is there. Asked by file, so it works
%   before the schema cache is loaded.
%
%   See also ndi.setup.V2.schemaHasField, ndi.setup.V2.schemaHasLeaf.

if nargin < 2
    schemaPath = getenv('DID_SCHEMA_PATH');
end
tf = false;
if isempty(schemaPath)
    return;
end
tf = isfile(fullfile(schemaPath, [char(className) '.json'])) || ...
    (~isempty(ndi.v2.entityTypesFor(className)) && isfile(fullfile(schemaPath, 'entity.json')) ...
    && ~isfile(fullfile(schemaPath, 'subject.json')));
end

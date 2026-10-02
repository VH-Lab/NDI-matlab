function tf = schemaHasField(className, fieldName)
%SCHEMAHASFIELD Whether the V2 schema on DID_SCHEMA_PATH declares a field.
%
%   TF = ndi.setup.V2.schemaHasField(CLASSNAME, FIELDNAME) is true when
%   DID_SCHEMA_PATH/<CLASSNAME>.json declares FIELDNAME among its own fields.
%   A field added to did-schema after a schema copy was made reads as absent,
%   so a maker can leave it out rather than write a document that schema
%   refuses (e.g. subject.name, did-schema #80; subject.type, #84).

arguments
    className (1,:) char
    fieldName (1,:) char
end
tf = false;
p = getenv('DID_SCHEMA_PATH');
f = fullfile(p, [className '.json']);
if isempty(p) || ~isfile(f)
    return;
end
d = jsondecode(fileread(f));
if isfield(d, 'fields') && ~isempty(d.fields)
    tf = any(strcmp({d.fields.name}, fieldName));
end
end

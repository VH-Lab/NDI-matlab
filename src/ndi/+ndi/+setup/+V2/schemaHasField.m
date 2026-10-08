function tf = schemaHasField(className, fieldName)
%SCHEMAHASFIELD Whether the V2 schema on DID_SCHEMA_PATH declares a field.
%
%   TF = ndi.setup.V2.schemaHasField(CLASSNAME, FIELDNAME) is true when
%   DID_SCHEMA_PATH/<CLASSNAME>.json declares FIELDNAME among its own fields.
%   FIELDNAME may be a dotted path to a nested field ('value.type').
%   A field added to did-schema after a schema copy was made reads as absent,
%   so a maker can leave it out rather than write a document that schema
%   refuses (e.g. subject.name, did-schema #80; subject.type, #84).

arguments
    className (1,:) char
    fieldName (1,:) char
end
tf = false;
p = getenv('DID_SCHEMA_PATH');
% a class renamed 2026-10-08 is looked up under whichever name the schema
% in use has (ndi.v2.vetaAliases: 'statement' or 'subject_statement')
names = ndi.v2.vetaAliases(className);
f = '';
for k = 1:numel(names)
    if ~isempty(p) && isfile(fullfile(p, [names{k} '.json']))
        f = fullfile(p, [names{k} '.json']);
        break;
    end
end
if isempty(f)
    return;
end
d = jsondecode(fileread(f));
if ~isfield(d, 'fields')
    return;
end
fields = d.fields;
parts = strsplit(fieldName, '.');
for k = 1:numel(parts)
    hit = [];
    for m = 1:numel(fields)
        if iscell(fields), x = fields{m}; else, x = fields(m); end
        if strcmp(x.name, parts{k})
            hit = x;
            break;
        end
    end
    if isempty(hit)
        return;
    end
    if k < numel(parts)
        if ~isfield(hit, 'fields') || isempty(hit.fields)
            return;
        end
        fields = hit.fields;   % jsondecode gives a cell when the fields differ in shape
    end
end
tf = true;
end

function name = notesField(className)
%NDI.V2.NOTESFIELD The free-text field of an `entity` or `data_body` block.
%
%   NAME = ndi.v2.notesField(CLASSNAME) is 'notes' when the V2 schema in use
%   (DID_SCHEMA_PATH) declares `notes` on CLASSNAME, and 'description'
%   otherwise (the shape before the rename, and the answer when no V2 schema
%   is set).
%
%   did-schema did_v2_go_forward_class_audit.md [one free-text field: notes]
%   and [notes on three classes] (Jess Haley, 2026-10-25): `entity.description`
%   and `data_body.description` are renamed `notes`. A writer that builds a
%   block by hand asks here, as ndi.v2.sessionIdIsEdge is asked, so it writes
%   valid documents against either schema until the rename has landed in
%   every repository; documents built with did2.build are spelled by
%   did2.build.document. Readers read both (ndi.v2.notesOf). Asked by file,
%   so it works before the schema cache is loaded.
%
%   See also ndi.v2.notesOf, ndi.v2.sessionIdIsEdge.

arguments
    className {mustBeText}
end
name = 'description';
p = getenv('DID_SCHEMA_PATH');
if isempty(p)
    return;
end
f = ndi.v2.schemaFile(p, [char(className) '.json']);
if ~isfile(f)
    return;
end
d = jsondecode(fileread(f));
if ~isfield(d, 'fields')
    return;
end
fields = d.fields;
for k = 1:numel(fields)
    if iscell(fields), x = fields{k}; else, x = fields(k); end
    if isfield(x, 'name') && strcmp(x.name, 'notes')
        name = 'notes';
        return;
    end
end
end

function f = fileFormat(node, name, mediaType)
%FILEFORMAT A data body's `format`, as the schema in use declares it.
%
%   F = fileFormat(NODE, NAME, MEDIATYPE) is the file-format term {NODE, NAME}
%   when data_body.format is an ontology_term (did-schema 877bbde, Jess
%   2026-10-14: EDAM format terms, EMPTY where EDAM has none), and the IANA
%   MEDIATYPE string on a schema copy made before that.
arguments
    node {mustBeText}
    name {mustBeText}
    mediaType {mustBeText}
end

[tf, decl] = ndi.setup.V2.schemaHasField('data_body', 'format');
if tf && strcmp(decl.type, 'ontology_term')
    f = struct('node', node, 'name', name);
else
    f = mediaType;
end
end

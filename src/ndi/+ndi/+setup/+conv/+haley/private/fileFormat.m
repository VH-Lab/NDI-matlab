function f = fileFormat(node, name)
%FILEFORMAT A data body's `format`: its file-format term.
%
%   F = fileFormat(NODE, NAME) is the file-format term {NODE, NAME}
%   (data_body.format is an ontology_term: did-schema 877bbde, Jess
%   2026-10-14: EDAM format terms, EMPTY where EDAM has none).
arguments
    node {mustBeText}
    name {mustBeText}
end

f = struct('node', node, 'name', name);
end

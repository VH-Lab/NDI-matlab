function name = edgeName(ndi_document_obj, v1_edge_name)
%EDGENAME Translate one v1 edge name to the spelling this document uses.
%
%   NAME = ndi.vintage.edgeName(NDI_DOCUMENT_OBJ, V1_EDGE_NAME)
%
%   Returns V1_EDGE_NAME unchanged for a v1 document, for a document of a
%   class V_eta did not rename, and for an edge the map has no row for.
%   Only a V_eta document with a mapped edge gets a different answer.
%
%   Split out from ndi.vintage.edge so the numbered-family reader can share
%   it, and so a test can assert the translation without needing a document
%   that has the edge populated.
%
%   See also: ndi.vintage.edge, ndi.vintage.edge_n, ndi.vintage.map.

arguments
    ndi_document_obj
    v1_edge_name (1,:) char
end

name = v1_edge_name;

[entry, vintage] = ndi.vintage.entryFor(ndi_document_obj);
if isempty(entry) || ~strcmp(vintage, 'V_eta')
    return;
end

rows = entry.edges;
for i = 1:size(rows, 1)
    if strcmp(v1_edge_name, rows{i,1})
        name = rows{i,2};
        return;
    end
end
end

function name = edgeName(ndi_document_obj, v1_edge_name)
%EDGENAME Translate one v1 edge name to the spelling this document uses.
%
%   NAME = ndi.vintage.edgeName(NDI_DOCUMENT_OBJ, V1_EDGE_NAME)
%
%   Returns V1_EDGE_NAME unchanged for a v1 document, for a document of a
%   class V_eta did not rename, and for an edge the map has no row for.
%   Only a V_eta document with a mapped edge gets a different answer: the
%   first of the row's candidate names (ndi.vintage.map) that the document
%   carries, or the current name when it carries none.
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
        candidates = ndi.vintage.names(rows{i,2});
        name = candidates{1};
        % The first candidate the document actually carries, under its own
        % name or as the first member of a numbered family (`name_1`).
        % A document carrying none of them gets the CURRENT name, so a
        % caller's not-found message names the edge today's schema uses.
        present = documentEdgeNames(ndi_document_obj);
        for j = 1:numel(candidates)
            if any(strcmp(candidates{j}, present)) ...
                    || any(strcmp([candidates{j} '_1'], present))
                name = candidates{j};
                break;
            end
        end
        return;
    end
end
end

function present = documentEdgeNames(ndi_document_obj)
present = {};
props = ndi_document_obj.document_properties;
if isfield(props, 'depends_on') && isstruct(props.depends_on) ...
        && isfield(props.depends_on, 'name')
    present = {props.depends_on.name};
end
end

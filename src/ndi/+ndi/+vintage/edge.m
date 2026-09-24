function value = edge(ndi_document_obj, v1_edge_name, options)
%EDGE Read a dependency by its v1 name, whatever vintage the document is.
%
%   VALUE = ndi.vintage.edge(NDI_DOCUMENT_OBJ, V1_EDGE_NAME)
%   VALUE = ndi.vintage.edge(..., 'ErrorIfNotFound', 0)
%
%   Callers keep naming edges the way v1 named them -- `daqreader_id`,
%   `filenavigator_id` -- and this translates to the V_eta spelling when the
%   document is a V_eta one. A document of an unrenamed class, or an edge
%   the map says nothing about, is read straight through, so this is a safe
%   drop-in for `doc.dependency_value(name)` anywhere.
%
%   THE TARGET IDS NEED NO TRANSLATION, only the edge NAMES do: every
%   migrator in this family preserves `base.id` on the document it emits
%   (+migrators_j/daqsystem.m, "all three targets keep the SOURCE id"), so
%   the value on the other end still resolves.
%
%   See also: ndi.vintage.edge_n, ndi.vintage.map.

arguments
    ndi_document_obj
    v1_edge_name (1,:) char
    options.ErrorIfNotFound (1,1) logical = 1
end

name = ndi.vintage.edgeName(ndi_document_obj, v1_edge_name);
value = ndi_document_obj.dependency_value(name, ...
    'ErrorIfNotFound', options.ErrorIfNotFound);
end

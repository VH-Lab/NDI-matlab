function values = edge_n(ndi_document_obj, v1_edge_name, options)
%EDGE_N Read a NUMBERED dependency family by its v1 base name, either vintage.
%
%   VALUES = ndi.vintage.edge_n(NDI_DOCUMENT_OBJ, V1_EDGE_NAME)
%   VALUES = ndi.vintage.edge_n(..., 'ErrorIfNotFound', 0)
%
%   The v1/V_eta spellings differ by BASE NAME, and the numbering suffix is
%   the same on both sides -- v1 `daqmetadatareader_id_1..N` becomes V_eta
%   `acquisition_metadata_reader_1..N`. So the map stores base names and
%   `dependency_value_n` does the expansion, exactly as it did before.
%
%   The map's entries for these two families are the base names WITHOUT the
%   `_#` the schema writes (schemas/V_eta/stable/acquisition_system.json
%   declares `acquisition_metadata_reader_#`); `#` is the schema's notation
%   for the family, not part of any stored key.
%
%   See also: ndi.vintage.edge, ndi.vintage.edgeName, ndi.vintage.map.

arguments
    ndi_document_obj
    v1_edge_name (1,:) char
    options.ErrorIfNotFound (1,1) logical = 0
end

name = ndi.vintage.edgeName(ndi_document_obj, v1_edge_name);
values = ndi_document_obj.dependency_value_n(name, ...
    'ErrorIfNotFound', options.ErrorIfNotFound);
end

function ndi_documents = structs_to_ndi_documents(ndi_document_structs)
% STRUCTS_TO_NDI_DOCUMENTS - Convert downloaded ndi document structures to ndi documents
%
%   Utility function for creating a set of ndi.documents from a set of structures

    num_documents = numel(ndi_document_structs);
    ndi_documents = cell(1, num_documents);

    % If document structure is homogeneous, convert to cell array to ensure
    % loop below always operates on a cell array
    if isstruct(ndi_document_structs)
        ndi_document_structs = num2cell(ndi_document_structs);
    end

    for i = 1:numel(ndi_document_structs)
        ndi_document_struct = ndi_document_structs{i};        
        ndi_documents{i} = ndi.document(ndi_document_struct);
    end
end

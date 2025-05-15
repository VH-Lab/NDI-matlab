function ndi_documents = structs_to_ndi_documents(ndi_document_structs)
% STRUCTS_TO_NDI_DOCUMENTS - Convert downloaded ndi document structures to ndi documents

    num_documents = numel(ndi_document_structs);
    ndi_documents = cell(1, num_documents);

    for i = 1:numel(ndi_document_structs)
        ndi_document_struct = ndi_document_structs{i};
        ndi_document_struct = rmfield(ndi_document_struct, 'id');
        
        ndi_documents = ndi.document(ndi_document_struct);
    end
end

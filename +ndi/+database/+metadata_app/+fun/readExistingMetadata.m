function datasetInformation = readExistingMetadata(D, file_path)
    %READEXISTINGMETADATA - retrieves metadata from an existing dataset
    %
    % DATASETINFORMATION = ndi.database.fun.READEXISTINGMETADATA(D)
    %
    % Inputs:
    %   D - the ndi.dataset object
    %
    % Outputs:
    %   DATASETINFORMATION - the metadata structure
    metadata_editor_docs = D.database_search(ndi.query('','isa','metadata_editor'));
    datasetInformation = {};
    if (numel(metadata_editor_docs) > 0)
        datasetInformation = read_metadata_editor(metadata_editor_docs);
    else
        datasetInformation = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(D);
    end

    if ~isempty(datasetInformation)
        save(file_path, "datasetInformation");
    end
end

function datasetInformation = read_metadata_editor(metadata_editor_docs)
    document = metadata_editor_docs{1}.document_properties.metadata_editor.metadata_structure;
    datasetInformation = ndi.database.metadata_ds_core.convertDocumentToDatasetInfo(document);
end

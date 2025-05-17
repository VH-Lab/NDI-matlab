function synchLocalToRemote(ndiDataset, cloudDatasetId, options)

    arguments
        ndiDataset (1,1) ndi.dataset
        cloudDatasetId (1,1) string
        options.DeleteMissingFiles (1,1) logical = false
    end
    
    if options.DeleteMissingFiles
        error('Not implemented')
    end

    % todo: resolve cloud dataset identifier
    % cloudDatasetIdQuery = ndi.query('','isa','cloud_dataset_id');
    % cloudDatasetIdDocument = ndiDataset.database_search(cloudDatasetIdQuery);
    % cloudDatasetId = cloudDatasetIdDocument.identifier;

    % List local documents
    allLocalDocumentsQuery = ndi.query('','isa','base');
    localDocuments = ndiDataset.database_search(allLocalDocumentsQuery);
    localDocumentIds = string( cellfun(@(doc) doc.document_properties.base.id, ...
        localDocuments, 'UniformOutput', false) );

    % List remote documents
    [~, documentSummary] = ndi.cloud.api.documents.list_dataset_documents(cloudDatasetId);
    remoteDocumentIds = string( {documentSummary.documents.ndiId} );

    % Upload missing documents to cloud
    [~, missingDocumentInd] = setdiff(localDocumentIds, remoteDocumentIds, 'stable');
    missingDocuments = localDocuments(missingDocumentInd);
    ndi.cloud.upload.upload_document_collection(cloudDatasetId, missingDocuments)
end

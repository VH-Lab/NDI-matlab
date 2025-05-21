function synchLocalToRemote(ndiDataset, options)

    arguments
        ndiDataset (1,1) ndi.dataset
        options.CloudDatasetId (1,1) string = missing
        options.DeleteMissingFiles (1,1) logical = false
    end
    
    if options.DeleteMissingFiles
        error('Not implemented')
    end

    cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
    if ismissing(cloudDatasetId)
        if ismissing(options.CloudDatasetId)
            error('Could not resolve the remote dataset id. Please provide the cloud dataset identifier as an input.')
        else
            cloudDatasetId = options.CloudDatasetId;
        end
    end

    % List local documents
    allLocalDocumentsQuery = ndi.query('','isa','base');
    localDocuments = ndiDataset.database_search(allLocalDocumentsQuery);
    localDocumentIds = string( cellfun(@(doc) doc.document_properties.base.id, ...
        localDocuments, 'UniformOutput', false) );

    % List remote documents
    remoteDocumentIds = ndi.cloud.internal.get_uploaded_document_ids(cloudDatasetId);

    % Upload missing documents to cloud
    [~, missingDocumentInd] = setdiff(localDocumentIds, remoteDocumentIds, 'stable');
    missingDocuments = localDocuments(missingDocumentInd);
    ndi.cloud.upload.upload_document_collection(cloudDatasetId, missingDocuments)

    % Todo: upload files if selected.
end

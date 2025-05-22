function syncRemoteToLocal(ndiDataset, options)

    arguments
        ndiDataset (1,1) ndi.dataset
        options.CloudDatasetId (1,1) string = missing
        options.SyncMode (1,1) ndi.cloud.sync.enum.SyncMode = "Hybrid"
        options.DeleteMissingFiles (1,1) logical = false
        options.Verbose (1,1) logical = true
    end

    import ndi.cloud.sync.enum.SyncMode

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

    % List remote documents
    [~, documentSummary] = ndi.cloud.api.documents.list_dataset_documents(cloudDatasetId);
    remoteDocumentIds = string( {documentSummary.documents.ndiId} );

    % List local documents
    allLocalDocumentsQuery = ndi.query('','isa','base');
    localDocuments = ndiDataset.database_search(allLocalDocumentsQuery);
    localDocumentIds = string( cellfun(@(doc) doc.document_properties.base.id, ...
        localDocuments, 'UniformOutput', false) );

    % Download missing documents from cloud
    [~, missingDocumentIdx] = setdiff(remoteDocumentIds, localDocumentIds, 'stable');
    
    missingDocumentCloudIds = {documentSummary.documents(missingDocumentIdx).id};

    newNdiDocuments = ndi.cloud.download.download_document_collection(...
        cloudDatasetId, missingDocumentCloudIds);

    if options.SyncMode == SyncMode.Local
        % Download missing files if files should be downloaded.
        missingFileUids = getFileUidsFromDocuments(newNdiDocuments);
        ndi.cloud.download.download_dataset_files(...
            cloudDatasetId, ...
            ndiDataset.path, ...
            missingFileUids, ...
            "Verbose", options.Verbose)
    end

    newNdiDocuments = ndi.cloud.download.internal.update_document_file_info(...
        newNdiDocuments, options.SyncMode, fullfile(ndiDataset.path, 'download', 'files')); %todo: path to downloaded files should not be hardcoded here.
    
    if options.Verbose
        fprintf('Adding %d documents to dataset...\n', numel(newNdiDocuments))
        if options.SyncMode == SyncMode.Local
            fprintf('Will copy %d downloaded files into dataset. May take several minutes if the files are large...\n', numel(missingFileUids))
        end
    end
    ndiDataset.database_add(newNdiDocuments);
    if options.Verbose; disp('Completed dataset update.'); end
end

function fileUids = getFileUidsFromDocuments(ndiDocuments)
    fileUids = {};

    for i = 1:numel(ndiDocuments)
        document = ndiDocuments{i};
        if document.has_files()
            fileInfo = document.document_properties.files.file_info;
            for j = 1:numel(fileInfo)
                fileUids = [fileUids, {fileInfo(j).locations.uid}]; %#ok<AGROW>
            end
        end
    end
end

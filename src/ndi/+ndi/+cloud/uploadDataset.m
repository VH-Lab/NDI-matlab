function [success, cloudDatasetId, message] = uploadDataset(ndiDataset, syncOptions, options)
    % UPLOADDATASET - upload a dataset to NDI cloud
    %
    % [SUCCESS, DATASETID, MESSAGE] = ndi.cloud.UPLOADDATASET(ndiDataset)
    %
    % Upload an ndi.dataset object to NDI Cloud. The DATASETID on
    % NDI Cloud is returned.
    %
    % Example:
    %   ndi.cloud.upload.newDataset(ndiDataset)
    %

    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
        options.uploadAsNew (1,1) logical = false
        options.skipMetadataEditorMetadata (1,1) logical = false
        options.remoteDatasetName (1,:) char = ''
    end

    success = false;
    cloudDatasetId = '';
    message = '';

    [cloudDatasetId, remote_doc] = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

    if ~isempty(cloudDatasetId) & ~options.uploadAsNew,
        message = ['Dataset has already been uploaded, and "uploadAsNew" is false.'];
        return;
    elseif ~isempty(cloudDatasetId) & options.uploadAsNew,
        [delete_success, delete_message] = ndi.cloud.api.admin.deleteDataset(cloudDatasetId);
        if ~delete_success
            message = ['Could not delete existing remote dataset: ' delete_message];
            return;
        end
        ndiDataset.database_rm(remote_doc);
        cloudDatasetId = '';
    end

    % Step 1: Create the dataset record on NDI Cloud and insert the metadata
    if options.skipMetadataEditorMetadata
        if isempty(options.remoteDatasetName)
            message = 'If skipMetadataEditorMetadata is true, remoteDatasetName cannot be empty.';
            return;
        end
        cloud_dataset_info.name = options.remoteDatasetName;
    else
        %   Step 1a: Retrieve metadata from the dataset
        metadata_struct = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(ndiDataset);

        %   Step 1b: Convert metadata structure to NDI Cloud Dataset info
        cloud_dataset_info = ndi.cloud.utility.createCloudMetadataStruct(metadata_struct);
    end

    %   Step 1c: Create new NDI Cloud Dataset
    [success_create, answer] = ndi.cloud.api.datasets.createDataset(cloud_dataset_info);
    if ~success_create
        message = ['Failed to create dataset: ' answer.message];
        return;
    end
    cloudDatasetId = answer.dataset_id;

    % Add document with remote dataset id to dataset before uploading.
    remoteDatasetDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudDatasetId, ndiDataset);
    ndiDataset.database_add(remoteDatasetDoc)

    % Step 2: Upload documents
    if syncOptions.Verbose, disp('Uploading dataset documents...'); end
    dataset_documents = ndiDataset.database_search( ndi.query('','isa','base') );
    ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, dataset_documents, "onlyUploadMissing", true)

    % Step 3: Upload files
    [success_upload, message_upload] = ndi.cloud.sync.internal.uploadFilesForDatasetDocuments( ...
        cloudDatasetId, ndiDataset, dataset_documents, ...
        "Verbose", syncOptions.Verbose, ...
        "FileUploadStrategy", syncOptions.FileUploadStrategy, "onlyMissing", true);
    if ~success_upload
        message = message_upload;
        return;
    end

    success = true;
end

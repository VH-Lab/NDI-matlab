function [success, cloudDatasetId, message] = uploadDataset(ndiDataset, syncOptions, options)
    % UPLOADDATASET - upload a dataset to NDI cloud
    %
    % [SUCCESS, DATASETID, MESSAGE] = ndi.cloud.UPLOADDATASET(ndiDataset, SYNCOPTIONS, ...
    %    NAME/VALUE PAIRS)
    %
    % Upload an ndi.dataset object to NDI Cloud.
    %
    % This function uploads all documents and associated data files for a given
    % NDIDATASET to the NDI cloud.
    %
    % By default, this function will not re-upload a dataset if it already exists
    % on the remote server. See the 'uploadAsNew' option to override this behavior.
    %
    % The function returns a boolean SUCCESS flag, the CLOUDDATASETID of the
    % created remote dataset, and a MESSAGE string that will contain an error
    % message if SUCCESS is false.
    %
    % It can be configured with the following NAME/VALUE pairs:
    % | Name                         | Description                               |
    % |------------------------------|-------------------------------------------|
    % | 'uploadAsNew'                | (logical) If true, any existing remote dataset will be deleted and a new one will be created. Default is false. If a remote dataset exists and this is false, the function will return an error. |
    % | 'skipMetadataEditorMetadata' | (logical) If true, the function will skip generating metadata from the dataset. Default is false. If you use this option, you must also provide 'remoteDatasetName'. |
    % | 'remoteDatasetName'          | (char) The name to be assigned to the dataset on the remote server. This is *required* if 'skipMetadataEditorMetadata' is true. |
    %
    % This function also accepts an ndi.cloud.sync.SyncOptions object for additional
    % configuration.
    %
    % See also: ndi.cloud.sync.SyncOptions, ndi.cloud.downloadDataset
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

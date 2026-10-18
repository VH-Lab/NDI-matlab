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
    % Inputs:
    %   ndiDataset - The ndi.dataset object to be uploaded.
    %   syncOptions - An ndi.cloud.sync.SyncOptions object for additional configuration.
    %
    % By default, this function will not re-upload a dataset if it already exists
    % on the remote server. See the 'uploadAsNew' option to override this behavior.
    %
    % The function returns a boolean SUCCESS flag, the CLOUDDATASETID of the
    % created remote dataset, and a MESSAGE string that will contain an error
    % message if SUCCESS is false.
    %
    % It can be configured with the following NAME/VALUE pairs:
    % | Name                         | Description                                                              |
    % |------------------------------|--------------------------------------------------------------------------|
    % | 'uploadAsNew'                | (logical) If true, a new remote dataset will be created even if one      |
    % |                              | already exists. The local reference to the original remote dataset will  |
    % |                              | be removed, but the original remote dataset will not be deleted.         |
    % |                              | Default is false. If a remote dataset exists and this is false,          |
    % |                              | the function will proceed to sync documents and files to it.             |
    % | 'skipMetadataEditorMetadata' | (logical) If true, the function will skip generating metadata from the   |
    % |                              | dataset. Default is false. If you use this option, you must also provide |
    % |                              | 'remoteDatasetName'.                                                     |
    % | 'remoteDatasetName'          | (char) The name to be assigned to the dataset on the remote server. This |
    % |                              | is *required* if 'skipMetadataEditorMetadata' is true.                   |
    % | 'organizationName'           | (char/string) The NAME of the NDI Cloud organization a NEW remote        |
    % |                              | dataset should be created under. The current user must belong to it and  |
    % |                              | be allowed to upload to it. Names are matched case-sensitively.          |
    % |                              | Mutually exclusive with 'organizationID'. When neither is given and the  |
    % |                              | user can upload to exactly one organization, that one is used; otherwise |
    % |                              | the user is asked to choose (in the MATLAB desktop) or an error lists    |
    % |                              | the organizations. See ndi.cloud.internal.chooseOrganization. Ignored    |
    % |                              | when the dataset already exists on NDI Cloud.                            |
    % | 'organizationID'             | (char/string) The ID of the NDI Cloud organization to use. Mutually     |
    % |                              | exclusive with 'organizationName'.                                       |
    %
    % See also: ndi.cloud.sync.SyncOptions, ndi.cloud.downloadDataset,
    %           ndi.cloud.ui.dialog.selectOrganization
    %

    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
        options.uploadAsNew (1,1) logical = false
        options.skipMetadataEditorMetadata (1,1) logical = false
        options.remoteDatasetName (1,:) char = ''
        options.organizationName (1,:) char = ''
        options.organizationID (1,:) char = ''
    end

    syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

    if ~isempty(options.organizationName) && ~isempty(options.organizationID)
        success = false; cloudDatasetId = '';
        message = 'organizationName and organizationID are mutually exclusive.';
        return;
    end

    success = false;
    cloudDatasetId = '';
    message = '';

    if ~ndiDataset.isIngested()
        message = 'Dataset is not fully ingested. All sessions must be ingested before uploading.';
        return;
    end

    [cloudDatasetId, remote_doc] = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

    if ~isempty(cloudDatasetId) & options.uploadAsNew
        ndiDataset.database_rm(remote_doc);
        cloudDatasetId = '';
    end

    if isempty(cloudDatasetId)
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

        %   Step 1c: Decide which organization the new dataset belongs to
        try
            organizationID = ndi.cloud.internal.chooseOrganization( ...
                'organizationName', options.organizationName, ...
                'organizationID', options.organizationID, ...
                'RequireUpload', true, ...
                'PromptString', "Upload the dataset to which organization?");
        catch chooseErr
            message = chooseErr.message;
            return;
        end

        %   Step 1d: Create new NDI Cloud Dataset
        [success_create, newCloudDatasetId, apiResponse] = ndi.cloud.api.datasets.createDataset( ...
            cloud_dataset_info, 'organizationID', organizationID);
        if ~success_create
            message = ['Failed to create dataset: ' ndi.cloud.internal.formatApiError(apiResponse)];
            return;
        end
        cloudDatasetId = newCloudDatasetId;

        % Add document with remote dataset id to dataset before uploading.
        remoteDatasetDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudDatasetId, ndiDataset);
        ndiDataset.database_add(remoteDatasetDoc)
    end

    % Step 2: Upload documents
    if syncOptions.Verbose, disp('Examining documents for upload...'); end
    dataset_documents = ndiDataset.database_search( ndi.query('','isa','base') );
    ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, dataset_documents, "onlyUploadMissing", true);
    if syncOptions.Verbose, disp('Document upload complete.'); end

    % Step 3: Upload files
    if syncOptions.Verbose
        disp('Looking for files (walks each document''s series members; can be slow on a spinning drive) ...');
    end
    [success_upload, message_upload] = ndi.cloud.sync.internal.uploadFilesForDatasetDocuments( ...
        cloudDatasetId, ndiDataset, dataset_documents, ...
        "Verbose", syncOptions.Verbose, ...
        "FileUploadStrategy", syncOptions.FileUploadStrategy, "onlyMissing", true, ...
        "FileBatchSizeLimit", syncOptions.FileBatchSizeLimit);
    if ~success_upload
        message = message_upload;
        % Print the failure so a caller who did not capture the message
        % output still sees why success came back false. Otherwise the
        % previous lines all say "success" and the return value is 0 with
        % no visible reason.
        if syncOptions.Verbose
            fprintf('ndi.cloud.uploadDataset FAILED: %s\n', message);
        end
        return;
    end

    success = true;
    if syncOptions.Verbose
        fprintf('ndi.cloud.uploadDataset completed successfully. Cloud dataset id: %s\n', cloudDatasetId);
    end
end

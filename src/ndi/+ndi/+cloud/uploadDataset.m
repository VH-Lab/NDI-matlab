function cloudDatasetId = uploadDataset(ndiDataset, syncOptions)
    % UPLOADDATASET - upload a dataset to NDI cloud
    %
    % DATASETID = ndi.cloud.UPLOADDATASET(ndiDataset)
    %
    % Upload an ndi.dataset object to NDI Cloud. The DATASETID on
    % NDI Cloud is returned.
    %
    % Example:
    %   ndi.cloud.upload.new_dataset(ndiDataset)
    %

    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
    end

    % Step 1: Create the dataset record on NDI Cloud and insert the metadata
    
    %   Step 1a: Retrieve metadata from the dataset
    metadata_struct = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(ndiDataset);

    %   Step 1b: Convert metadata structure to NDI Cloud Dataset info 
    cloud_dataset_info = ndi.cloud.utility.create_cloud_metadata_struct(metadata_struct);

    %   Step 1c: Create new NDI Cloud Dataset
    [success, answer] = ndi.cloud.api.datasets.createDataset(cloud_dataset_info);
    if ~success
        error(['Failed to create dataset: ' answer.message]);
    end
    cloudDatasetId = answer.dataset_id;

    % Add document with remote dataset id to dataset before uploading.
    remoteDatasetDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudDatasetId, ndiDataset);
    ndiDataset.database_add(remoteDatasetDoc)

    % Step 2: Upload documents
    if syncOptions.Verbose, disp('Uploading dataset documents...'); end
    dataset_documents = ndiDataset.database_search( ndi.query('','isa','base') );
    ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, dataset_documents)

    % Step 3: Upload files
    ndi.cloud.sync.internal.uploadFilesForDatasetDocuments( ...
        cloudDatasetId, ndiDataset, dataset_documents, ...
        "Verbose", syncOptions.Verbose, ...
        "FileUploadStrategy", syncOptions.FileUploadStrategy)
end

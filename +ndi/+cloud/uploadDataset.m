function cloudDatasetId = uploadDataset(ndiDataset, options)
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
        options.Verbose (1,1) logical = true
    end

    % Step 1: Create the dataset record on NDI Cloud and insert the metadata
    
    %   Step 1a: Retrieve metadata from the dataset
    metadata_struct = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(ndiDataset);

    %   Step 1b: Convert metadata structure to NDI Cloud Dataset info 
    cloud_dataset_info = ndi.cloud.utility.create_cloud_metadata_struct(metadata_struct);

    %   Step 1c: Create new NDI Cloud Dataset
    [~, cloudDatasetId] = ndi.cloud.api.datasets.create_dataset(cloud_dataset_info);

    % Add document with remote dataset id to dataset before uploading.
    remoteDatasetDoc = ndi.cloud.internal.create_remote_dataset_doc(cloudDatasetId, ndiDataset);
    ndiDataset.database_add(remoteDatasetDoc)

    % Step 2: Upload documents
    if options.Verbose, disp('Uploading dataset documents...'); end
    dataset_documents = ndiDataset.database_search( ndi.query('','isa','base') );
    ndi.cloud.upload.upload_document_collection(cloudDatasetId, dataset_documents)

    % Step 3: Upload files
    ndi.cloud.sync.internal.upload_files_for_dataset_documents( ...
        cloudDatasetId, ndiDataset, dataset_documents, "Verbose", options.Verbose)
end

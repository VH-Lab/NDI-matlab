function datasetId = uploadDataset(ndiDataset, options)
    % NEW_DATASET - upload a dataset to NDI cloud
    %
    % DATASETID = NEW_DATASET(ndiDataset)
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

    %   Step 1c: Create ned NDI Cloud Dataset
    [~, cloudDatasetId] = ndi.cloud.api.datasets.create_dataset(cloud_dataset_info);


    % Step 2: Upload documents
    if options.Verbose, disp('Uploading dataset documents...'); end
    dataset_documents = ndiDataset.database_search(ndi.query('','isa','base'));
    ndi.cloud.upload.upload_document_collection(cloudDatasetId, dataset_documents)

    % Step 3: Upload files
    file_manifest = ...
        ndi.database.internal.list_binary_files(...
        ndiDataset, dataset_documents, options.Verbose); % verbose=false
    [file_manifest(:).is_uploaded] = false;

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;
    [~, msg] = ndi.cloud.upload.zip_for_upload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
end

function datasetId = newDataset(D)
    % NEWDATASET - upload a new dataset to NDI cloud
    %
    % DATASETID = ndi.cloud.upload.NEWDATASET(D)
    %
    % Upload an ndi.dataset object to NDI Cloud. The DATASETID on
    % NDI Cloud is returned.
    %
    % Example:
    %   ndi.cloud.upload.newDataset(D)
    %

    arguments
        D (1,1) {mustBeA(D,'ndi.dataset')}
    end

    % Step 1: Create the dataset record on NDI Cloud and insert the metadata
    %   Step 1a: Create metadata from the dataset

    metadata_structure = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(D);

    %   Step 1b: Create the dataset record on NDI cloud
    [status,response,datasetId] = ndi.cloud.utility.createCloudMetadataStruct(metadata_structure);

    % Step 2: upload

    [b,msg] = ndi.cloud.upload.uploadToNDICloud(D,datasetId);

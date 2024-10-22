function datasetId = new_dataset(D)
% NEW_DATASET - upload a new dataset to NDI cloud
%
% DATASETID = NEW_DATASET(D)
%
% Upload an ndi.dataset object to NDI Cloud. The DATASETID on
% NDI Cloud is returned.
%
% Example:
%   ndi.cloud.upload.new_dataset(D)
%

arguments
    D (1,1) {mustBeA(D,'ndi.dataset')}
end

 % Step 1: Create the dataset record on NDI Cloud and insert the metadata
 %   Step 1a: Create metadata from the dataset
 
metadata_structure = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(D);

 %   Step 1b: Create the dataset record on NDI cloud
[status,response,datasetId] = ndi.cloud.upload.create_cloud_metadata_struct(metadata_structure);

 % Step 2: upload

[b,msg] = ndi.cloud.upload.upload_to_NDI_cloud(D,datasetId);



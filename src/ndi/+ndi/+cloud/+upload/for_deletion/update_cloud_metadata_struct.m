function [status, dataset] = update_cloud_metadata_struct(dataset_id, S, size)
    % UPDATE_CLOUD_METADATA_STRUCT - upload metadata to the NDI Cloud
    %
    % [STATUS, DATASET] = ndi.cloud.upload.UPDATE_CLOUD_METADATA_STRUCT(DATASETID, S, SIZE)
    %
    % Inputs:
    %   DATASETID - the dataset ID to update
    %   S - a struct with the metadata to upload
    %   SIZE - a float representing the size of this dataset in kilobytes
    %
    % Outputs:
    %   STATUS - did the upload work? 0 for no, 1 for yes
    %   DATASET - The updated dataset
    %

    % loops over all the metadata fields and posts an updated value to the cloud API

    all_fields = {'name','branchName','contributors','doi','funding','abstract','license','species','numberOfSubjects','correspondingAuthors'};

    clear dataset_update;

    is_valid = ndi.database.metadata_ds_core.check_metadata_cloud_inputs(S);
    if ~is_valid
        error('NDI:CLOUD:UPDATE_CLOUD_METADATA_STRUCT', ...
            'Metadata struct is missing required fields');
    end
    dataset_update = ndi.database.metadata_app.fun.metadata_to_json(S);
    dataset_update.doi = "https://doi.org://10.1000/123456789";
    % round up the bytes to the nearest kilobyte
    dataset_update.totalSize = round(size);
    % dataset_update.brainRegions = brainRegions;
    % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.update_dataset with ndi.cloud.api.datasets.updateDataset
    [dataset] = ndi.cloud.api.datasets.update_dataset(dataset_id,dataset_update);
end

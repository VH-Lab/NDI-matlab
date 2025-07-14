function mustBeValidMetadata(metadata_struct) 

    is_valid = ndi.database.metadata_ds_core.check_metadata_cloud_inputs(metadata_struct);
    if ~is_valid
        error('NDI:CLOUD:CREATE_CLOUD_METADATA_STRUCT', ...
            'S is missing required fields');
    end
end
function cloudDatasetId = getCloudDatasetIdForLocalDataset(ndiDataset)
    cloudDatasetIdQuery = ndi.query('','isa','dataset_remote');
    cloudDatasetIdDocument = ndiDataset.database_search(cloudDatasetIdQuery);
    if ~isempty(cloudDatasetIdDocument)
        cloudDatasetId = cloudDatasetIdDocument{1}.document_properties.dataset_remote.dataset_id;
    else
        error('NDICloud:Sync:MissingCloudDatasetId', ...
            ['Could not resolve the remote cloudDatasetId for the local ', ...
            'dataset: %s. Ensure it is linked.'], ndiDataset.path);
    end
    % Todo: Add suggestion what to do
end

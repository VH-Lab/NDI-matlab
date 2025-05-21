function cloudDatasetId = getCloudDatasetIdForLocalDataset(ndiDataset)
    cloudDatasetIdQuery = ndi.query('','isa','dataset_remote');
    cloudDatasetIdDocument = ndiDataset.database_search(cloudDatasetIdQuery);
    if ~isempty(cloudDatasetIdDocument)
        cloudDatasetId = cloudDatasetIdDocument{1}.document_properties.dataset_remote.dataset_id;
    else
       cloudDatasetId = string(missing);
    end
end

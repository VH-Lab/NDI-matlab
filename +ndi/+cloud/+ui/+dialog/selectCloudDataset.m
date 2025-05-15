function cloudDatasetId = selectCloudDataset(access)
% selectCloudDataset - Open a dialog to select a dataset from cloud

    arguments
        access (1,1) string {mustBeMember(access, ["public", "private"])} = "public"
    end

    if access == "public"
        [~, datasetInfo] = ndi.cloud.api.datasets.get_published();
        datasetInfo = datasetInfo.datasets;
    else % private
        [~, datasetInfo] = ndi.cloud.api.datasets.list_datasets();
    end
        
    datasetNames = cellfun(@(ds) ds.name, datasetInfo, 'UniformOutput', false);

    [idx, success] = listdlg(...
        "PromptString", "Select a dataset:", ...
        "Name", "Dataset Selection", ...
        "SelectionMode", "single", ...
        "ListString", datasetNames, ...
        "ListSize", [500, 300] ...
        );

    if ~success
        error('NDI:CloudDialog:UserCanceled', ...
            'Operation canceled during selection of a cloud dataset.')
    end

    cloudDatasetId = datasetInfo{idx}.id;
end

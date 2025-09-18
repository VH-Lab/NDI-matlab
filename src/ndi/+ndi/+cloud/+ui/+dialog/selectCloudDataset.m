function cloudDatasetId = selectCloudDataset(access)
% SELECTCLOUDDATASET - Open a dialog to select a dataset from cloud
%   
% CLOUDDATASETID = ndi.cloud.ui.dialog.SELECTCLOUDDATASET(ACCESS)
%
% Inputs:
%   ACCESS          - Access level for which to select dataset from. Must
%                     be "public" or "private"
%
% Outputs:
%   CLOUDDATASETID  - The identifier of the selected cloud dataset

    arguments
        access (1,1) string {mustBeMember(access, ["public", "private"])} = "public"
    end

    if access == "public"
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_published with ndi.cloud.api.datasets.getPublished
        [~, datasetInfo] = ndi.cloud.api.datasets.get_published();
        datasetInfo = datasetInfo.datasets;
    else % private
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.list_datasets with ndi.cloud.api.datasets.listDatasets
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

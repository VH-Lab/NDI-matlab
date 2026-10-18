function cloudDatasetId = selectCloudDataset(access)
% SELECTCLOUDDATASET - Open a dialog to select a dataset from cloud
%   
% CLOUDDATASETID = ndi.cloud.ui.dialog.SELECTCLOUDDATASET(ACCESS)
%
% Inputs:
%   ACCESS          - Access level for which to select dataset from. Must
%                     be "public" or "private". "private" lists the datasets
%                     in all of the user's organizations.
%
% Outputs:
%   CLOUDDATASETID  - The identifier of the selected cloud dataset

    arguments
        access (1,1) string {mustBeMember(access, ["public", "private"])} = "public"
    end

    if access == "public"
        [success, datasetInfo] = ndi.cloud.api.datasets.getPublished();
        if ~success, error("Failed to get published datasets"); end
        datasetInfo = datasetInfo.datasets;
    else % private: every organization the user belongs to
        [success, datasetInfo] = ndi.cloud.api.datasets.listDatasets();
        if ~success, error("Failed to list datasets"); end
        datasetInfo = datasetInfo.datasets;
    end
    if isstruct(datasetInfo)
        datasetInfo = num2cell(datasetInfo);
    end
        
    datasetNames = cellfun(@(ds) char(ds.name), datasetInfo, 'UniformOutput', false);
    if access == "private"
        orgNames = cellfun(@(ds) char(ds.organizationName), datasetInfo, 'UniformOutput', false);
        if numel(unique(orgNames)) > 1
            datasetNames = cellfun(@(o, n) sprintf('[%s] %s', o, n), ...
                orgNames, datasetNames, 'UniformOutput', false);
        end
    end

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

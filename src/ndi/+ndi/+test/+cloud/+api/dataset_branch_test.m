function dataset_branch_test()
    %DATASET_BRANCH_TEST - test the functions related to dataset branches
    %
    % DATASET_BRANCH_TEST()
    %
    % Test the following api commands:
    %   datasets/create_dataset_branch
    %   datasets/get_branches

    example_dataset.name = "test branch dataset";
    [success, answer] = ndi.cloud.api.datasets.createDataset(example_dataset);
    if ~success, error("Failed to create dataset"); end
    dataset_id = answer.dataset_id;

    [success, ~] = ndi.cloud.api.datasets.createDatasetBranch(dataset_id, 'new test branch');
    if ~success, error("Failed to create dataset branch"); end

    [success, branches] = ndi.cloud.api.datasets.getBranches(dataset_id);
    if ~success, error("Failed to get branches"); end
    if (numel(branches) ~= 1)
        error('ndi.cloud.api.dataset.getBranches did not return the correct number of branches');
    end

    try
        [~,~] = ndi.cloud.api.datasets.createDatasetBranch(dataset_id, 1);
        error('ndi.cloud.api.dataset.createDatasetBranch did not throw an error after using a non-string branch name');
    catch
        % do nothing, this is the expected behavior
    end

    try
        [~,~] = ndi.cloud.api.datasets.createDatasetBranch(1, 'new test branch');
        error('ndi.cloud.api.dataset.createDatasetBranch did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    try
        [~,~] = ndi.cloud.api.datasets.getBranches(1);
        error('ndi.cloud.api.dataset.getBranches did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    %% test delete dataset branch
    try
        [~,~] = ndi.cloud.api.datasets.deleteDataset(dataset_id);
        error('ndi.cloud.api.dataset.deleteDataset did not throw an error while deleting a dataset with branches');
    catch
        % do nothing, this is the expected behavior
    end
    branched_dataset_id = branches(1).datasetId;
    [success, ~] = ndi.cloud.api.datasets.deleteDataset(branched_dataset_id);
    if ~success, error("Failed to delete branch dataset"); end

    [success, branches] = ndi.cloud.api.datasets.getBranches(dataset_id);
    if ~success, error("Failed to get branches"); end
    if (numel(branches) ~= 0)
        error('ndi.cloud.api.dataset.getBranches did not return the correct number of branches after deleting a branch');
    end
    [success, ~] = ndi.cloud.api.datasets.deleteDataset(dataset_id);
    if ~success, error("Failed to delete dataset"); end
    try
        [~,~] = ndi.cloud.api.datasets.getDataset(dataset_id);
        error('ndi.cloud.api.dataset.getDataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.getDataset(branched_dataset_id);
        error('ndi.cloud.api.dataset.getDataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
end

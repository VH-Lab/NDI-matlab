function dataset_branch_test()
    %DATASET_BRANCH_TEST - test the functions related to dataset branches
    %
    % DATASET_BRANCH_TEST()
    %
    % Test the following api commands:
    %   datasets/post_branch
    %   datasets/get_branches

    example_dataset.name = "test branch dataset";
    [status, response, dataset_id] = ndi.cloud.api.datasets.post_organization(example_dataset);
    [status, response] = ndi.cloud.api.datasets.post_branch(dataset_id, 'new test branch');
    [status, response, branches] = ndi.cloud.api.datasets.get_branches(dataset_id);
    if (numel(branches) ~= 1)
        error('ndi.cloud.api.dataset.get_branches did not return the correct number of branches');
    end

    try
        [status, response] = ndi.cloud.api.datasets.post_branch(dataset_id, 1);
        error('ndi.cloud.api.dataset.post_branch did not throw an error after using a non-string branch name');
    catch
        % do nothing, this is the expected behavior
    end

    try
        [status, response] = ndi.cloud.api.datasets.post_branch(1, 'new test branch');
        error('ndi.cloud.api.dataset.post_branch did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    try
        [status, response, branches] = ndi.cloud.api.datasets.get_branches(1);
        error('ndi.cloud.api.dataset.get_branches did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    %% test delete dataset branch
    try
        [status, dataset, response] = ndi.cloud.api.datasets.delete_dataset(dataset_id);
        error('ndi.cloud.api.dataset.delete_dataset did not throw an error while deleting a dataset with branches');
    catch
        % do nothing, this is the expected behavior
    end
    branched_dataset_id = branches(1).datasetId;
    [status, response] = ndi.cloud.api.datasets.delete_dataset(branched_dataset_id);
    [status, response, branches] = ndi.cloud.api.datasets.get_branches(dataset_id);
    if (numel(branches) ~= 0)
        error('ndi.cloud.api.dataset.get_branches did not return the correct number of branches after deleting a branch');
    end
    [status, response] = ndi.cloud.api.datasets.delete_dataset(dataset_id);
    try
        [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(dataset_id);
        error('ndi.cloud.api.dataset.get_datasetId did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, dataset, response] = ndi.cloud.api.datasets.get_datasetId(branched_dataset_id);
        error('ndi.cloud.api.dataset.get_datasetId did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
end

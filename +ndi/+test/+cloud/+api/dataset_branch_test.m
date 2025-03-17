function dataset_branch_test()
    %DATASET_BRANCH_TEST - test the functions related to dataset branches
    %
    % DATASET_BRANCH_TEST()
    %
    % Test the following api commands:
    %   datasets/create_dataset_branch
    %   datasets/get_branches

    example_dataset.name = "test branch dataset";
    [response, dataset_id] = ndi.cloud.api.datasets.create_dataset(example_dataset);
    response = ndi.cloud.api.datasets.create_dataset_branch(dataset_id, 'new test branch');
    [response, branches] = ndi.cloud.api.datasets.get_branches(dataset_id);
    if (numel(branches) ~= 1)
        error('ndi.cloud.api.dataset.get_branches did not return the correct number of branches');
    end

    try
        response = ndi.cloud.api.datasets.create_dataset_branch(dataset_id, 1);
        error('ndi.cloud.api.dataset.create_dataset_branch did not throw an error after using a non-string branch name');
    catch
        % do nothing, this is the expected behavior
    end

    try
        response = ndi.cloud.api.datasets.create_dataset_branch(1, 'new test branch');
        error('ndi.cloud.api.dataset.create_dataset_branch did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    try
        [response, branches] = ndi.cloud.api.datasets.get_branches(1);
        error('ndi.cloud.api.dataset.get_branches did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end

    %% test delete dataset branch
    try
        [dataset, response] = ndi.cloud.api.datasets.delete_dataset(dataset_id);
        error('ndi.cloud.api.dataset.delete_dataset did not throw an error while deleting a dataset with branches');
    catch
        % do nothing, this is the expected behavior
    end
    branched_dataset_id = branches(1).datasetId;
    response = ndi.cloud.api.datasets.delete_dataset(branched_dataset_id);
    [response, branches] = ndi.cloud.api.datasets.get_branches(dataset_id);
    if (numel(branches) ~= 0)
        error('ndi.cloud.api.dataset.get_branches did not return the correct number of branches after deleting a branch');
    end
    response = ndi.cloud.api.datasets.delete_dataset(dataset_id);
    try
        [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
        error('ndi.cloud.api.dataset.get_dataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [dataset, response] = ndi.cloud.api.datasets.get_dataset(branched_dataset_id);
        error('ndi.cloud.api.dataset.get_dataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
end

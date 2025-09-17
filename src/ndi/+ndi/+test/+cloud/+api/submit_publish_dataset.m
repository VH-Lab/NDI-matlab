function submit_publish_dataset(dataset_id)
    %SUBMIT_PUBLISH_DATASET - test the functions related to submit and publishing a dataset
    %
    % SUBMIT_PUBLISH_DATASET(DATASET_ID)
    %
    % Test the following api commands:
    %
    %    datasets/submit_dataset
    %    datasets/publish_dataset
    %    datasets/unpublish_dataset
    %    datasets/get_published
    %    datasets/get_unpublished

    %% test submit
    % [~,~] = ndi.cloud.api.datasets.submitDataset(dataset_id);

    %% test publish
    [success, ~] = ndi.cloud.api.datasets.publishDataset(dataset_id);
    if ~success, error("Failed to publish"); end
    [success, datasets_info] = ndi.cloud.api.datasets.getPublished(1, 1);
    if ~success, error("Failed to get published"); end
    total_number_published = datasets_info.totalNumber;
    found = 0;
    for i = 1:numel(datasets_info.datasets)
        if strcmp(datasets_info.datasets(1).id, dataset_id)
            found = 1;
            break;
        end
    end
    if ~found
        error('Dataset id does not exist in the published datasets');
    end
    %% test unpublish
    [success, ~] = ndi.cloud.api.datasets.unpublishDataset(dataset_id);
    if ~success, error("Failed to unpublish"); end
    [success, datasets_info] = ndi.cloud.api.datasets.getPublished(1, total_number_published);
    if ~success, error("Failed to get published"); end
    found = 0;
    for i = 1:numel(datasets_info.datasets)
        if strcmp(datasets_info.datasets{1}.id, dataset_id)
            found = 1;
            break;
        end
    end
    if found
        error('Dataset id still exists in the published datasets');
    end

    [success, ~] = ndi.cloud.api.datasets.deleteDataset(dataset_id);
    if ~success, error("Failed to delete"); end

    try
        [~,~] = ndi.cloud.api.datasets.submitDataset(dataset_id);
        error('ndi.cloud.api.datasets.getUnpublished did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.publishDataset(1);
        error('ndi.cloud.api.datasets.publishDataset did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.unpublishDataset(1);
        error('ndi.cloud.api.datasets.unpublishDataset did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.getUnpublished('1', '1');
        error('ndi.cloud.api.datasets.getUnpublished did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.getPublished('1', '1');
        error('ndi.cloud.api.datasets.getPublished did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
end

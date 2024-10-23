function submit_publish_dataset(dataset_id)
    %SUBMIT_PUBLISH_DATASET - test the functions related to submit and publishing a dataset
    %
    % SUBMIT_PUBLISH_DATASET(DATASET_ID)
    %
    % Test the following api commands:
    %
    %    datasets/post_submit
    %    datasets/post_publish
    %    datasets/post_unpublish
    %    datasets/get_published
    %    datasets/get_unpublished

    %% test submit
    % [status, response] = ndi.cloud.api.datasets.post_submit(dataset_id);

    %% test publish
    [status, response] = ndi.cloud.api.datasets.post_publish(dataset_id);
    [status, response, datasets_info] = ndi.cloud.api.datasets.get_published(1, 1);
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
    [status, response] = ndi.cloud.api.datasets.post_unpublish(dataset_id);
    [status, response, datasets_info] = ndi.cloud.api.datasets.get_published(1, total_number_published);
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

    [status, response] = ndi.cloud.api.datasets.delete_datasetId(dataset_id);

    try
        [status, response] = ndi.cloud.api.datasets.post_submit(dataset_id);
        error('ndi.cloud.api.datasets.get_unpublished did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.datasets.post_publish(1);
        error('ndi.cloud.api.datasets.post_publish did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response] = ndi.cloud.api.datasets.post_unpublish(1);
        error('ndi.cloud.api.datasets.post_unpublish did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response, datasets_info] = ndi.cloud.api.datasets.get_unpublished('1', '1');
        error('ndi.cloud.api.datasets.get_unpublished did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [status, response, datasets_info] = ndi.cloud.api.datasets.get_published('1', '1');
        error('ndi.cloud.api.datasets.get_published did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end

end


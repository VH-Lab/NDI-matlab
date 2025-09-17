function file_ids = get_uploaded_file_ids(dataset_id)
    % get_uploaded_file_ids - Get cell array of uploaded file ids.

    [success, datasets] = ndi.cloud.api.datasets.listDatasets();
    if ~success
        error(['Failed to list datasets: ' datasets.message]);
    end
    dataset_names = {};
    for i=1:numel(datasets)
        dataset_names{i} = datasets{i}.id;
    end
    is_match =  strcmp(dataset_names, dataset_id);
    if any(is_match)
        dataset = datasets{is_match};
    else
        error('No dataset found with id "%s"', dataset_id)
    end

    if ~isempty(dataset.files)
        is_uploaded = [dataset.files.uploaded];
        file_ids = {dataset.files(is_uploaded).uid};
    else
        file_ids = {};
    end
end

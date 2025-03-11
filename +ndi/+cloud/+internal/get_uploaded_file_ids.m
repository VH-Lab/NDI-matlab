function file_ids = get_uploaded_file_ids(dataset_id)
    % get_uploaded_file_ids - Get cell array of uploaded file ids.

    [auth_token, organization_id] = ndi.cloud.uilogin();
    try
        % [~, result, ~] = ndi.cloud.datasets.get_dataset(dataset_id, auth_token);
        [~, ~, datasets] = ndi.cloud.datasets.get_organizations(organization_id, auth_token);
        dataset_names = {};
        for i=1:numel(datasets),
            dataset_names{i} = datasets{i}.id;
        end;
        is_match =  strcmp(dataset_names, dataset_id);
        if any(is_match)
            dataset = datasets{is_match};
        else
            error('No dataset found with id "%s"', dataset_id)
        end
    catch ME
        rethrow(ME)
    end

    if ~isempty(dataset.files)
        is_uploaded = [dataset.files.uploaded];
        file_ids = {dataset.files(is_uploaded).uid};
    else
        file_ids = {};
    end
end

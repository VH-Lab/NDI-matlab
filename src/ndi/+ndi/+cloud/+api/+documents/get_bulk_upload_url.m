function uploadUrl = get_bulk_upload_url(dataset_id)
    % get_bulk_upload_url - Get URL for uploading documents in bulk
    %
    % uploadUrl = get_bulk_upload_url(dataset_id) returns a signed url to
    %   upload a zip file containing one or more json files containing document
    %   data (as a root-level array) for the specified dataset
    %
    % Inputs:
    %   dataset_id - string representing a dataset id
    %
    % Outputs:
    %   uploadUrl - string representing a upload url

    arguments
        dataset_id (1,1) string
    end

    api_url = ndi.cloud.api.url('bulk_upload_documents', 'dataset_id', dataset_id);
    opts = ndi.cloud.internal.get_weboptions_with_auth_header();
    result = webwrite(api_url, [], opts);
    uploadUrl = result.url;
end

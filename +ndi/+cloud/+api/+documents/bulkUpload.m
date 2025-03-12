function [result] = bulkUpload(dataset_id)
    % ADD_DOCUMENT - Add a document to a dataset

    arguments
        dataset_id (1,1) string
    end

    API_BASE_URL = "https://dev-api.ndi-cloud.com/v1/";
    auth_tokeauth_token = ndi.cloud.authenticate()();

    endpoint_path = sprintf("datasets/%s/documents/bulk-upload", dataset_id);
    api_url = API_BASE_URL + endpoint_path;

    opts = weboptions('HeaderFields', ["Authorization", sprintf("Bearer %s", auth_token)]);

    result = webwrite(api_url, [], opts);
end


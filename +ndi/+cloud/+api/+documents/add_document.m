function [result] = add_document(dataset_id, json_document)
    % create_dataset - Create a new dataset in an organization

    arguments
        dataset_id (1,1) string
        json_document (1,1) string
    end

    API_BASE_URL = "https://dev-api.ndi-cloud.com/v1/";
    auth_token = ndi.cloud.uilogin();


    endpoint_path = sprintf("datasets/%s/documents", dataset_id);
    api_url = API_BASE_URL + endpoint_path;

    opts = weboptions('HeaderFields', ["Authorization", sprintf("Bearer %s", auth_token)]);

    result = webwrite(api_url, json_document, opts);
end
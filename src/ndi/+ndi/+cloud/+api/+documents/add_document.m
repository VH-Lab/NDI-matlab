function result = add_document(dataset_id, json_document)
    % ADD_DOCUMENT - Add a document to a dataset

    arguments
        dataset_id (1,1) string
        json_document (1,1) string
    end

    auth_token = ndi.cloud.uilogin();
    opts = weboptions('HeaderFields', ["Authorization", sprintf("Bearer %s", auth_token)]);

    uri = ndi.cloud.api.url('add_document','dataset_id',dataset_id);
    api_url = uri.EncodedURI;

    result = webwrite(api_url, json_document, opts);
end

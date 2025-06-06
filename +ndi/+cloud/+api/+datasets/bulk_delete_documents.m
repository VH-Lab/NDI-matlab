function response = bulk_delete_documents(dataset_id,document_ids)
    %BULK_DELETE_DOCUMENTS - Delete a set of documents from the dataset
    %
    % RESPONSE = ndi.cloud.api.datasets.BULK_DELETE_DOCUMENTS(DATASET_ID, DOCUMENT_IDS)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %   DOCUMENT_IDS - a cell array of document ids to delete
    %
    % Outputs:
    %   response - the post request response

    auth_token = ndi.cloud.authenticate();
    json = struct();
    json.documentIds = document_ids;

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('bulk_delete_documents', 'dataset_id', dataset_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

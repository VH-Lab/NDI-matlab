function response = update_dataset(dataset_id, dataset)
    % UPDATE_DATASET - update a dataset to NDI Cloud
    %
    % RESPONSE = ndi.cloud.api.datasets.UPDATE_DATASET(DATASET_ID, DATASET)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %   DATASET - the updated version of the dataset in JSON-formatted text
    %
    % Outputs:
    %   RESPONSE - the updated dataset summary
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(dataset);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('update_dataset', 'dataset_id', dataset_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        response = response.Body.Data;
    else
        response.Body,
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

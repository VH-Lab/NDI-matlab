function response = publish_dataset(dataset_id)
    % PUBLISH_DATASET - publish a dataset
    %
    % RESPONSE = ndi.cloud.api.datasets.PUBLISH_DATASET(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %
    % Outputs:
    %   RESPONSE - the dataset was published
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody('');

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('publish_dataset', 'dataset_id', dataset_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

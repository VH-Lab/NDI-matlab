function response = submit_dataset(dataset_id)
    % SUBMIT_DATASET - submit a dataset for review
    %
    % RESPONSE = ndi.cloud.api.datasets.SUBMIT_DATASET(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - an id of the dataset
    %
    % Outputs:
    %   RESPONSE - the dataset was submitted
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody('');

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('submit_dataset', 'dataset_id', dataset_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

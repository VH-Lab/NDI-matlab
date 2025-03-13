function [response, dataset_id] = create_dataset(dataset)
    % CREATE_DATASET - Create a new dataset
    %
    % [RESPONSE] = ndi.cloud.api.datasets.CREATE_DATASET(DATASET)
    %
    % Inputs:
    %   DATASET - a JSON object representing the dataset
    %
    % Outputs:
    %   STATUS - did post request work? 1 for no, 0 for yes
    %   RESPONSE - the new dataset summary
    %   DATASET_ID - the id of the newly created dataset

    [auth_token, organization_id] = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(dataset);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('create_dataset', 'organization_id', organization_id);

    response = req.send(url);
    
    if (response.StatusCode == 201)
        % Request succeeded
        dataset_id = response.Body.Data.id;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

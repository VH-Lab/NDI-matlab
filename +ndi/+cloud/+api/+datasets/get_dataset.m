function [status,dataset, response] = get_dataset(dataset_id)
    % GET_DATASET - Get a dataset given it's dataset id
    %
    % [DATASET, RESPONSE] = ndi.cloud.api.datasets.GET_DATASET(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   DATASET - the dataset required by the user
    %   RESPONSE - the response from the server

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_dataset', 'dataset_id', dataset_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        dataset = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

function [N, response] = document_count(dataset_id)
    % DOCUMENT_COUNT - Use the API to count documents
    %
    % [N, RESPONSE] = ndi.cloud.api.datasets.DOCUMENT_COUNT(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   N - the document count
    %   RESPONSE - the response from the server

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('document_count', 'dataset_id', dataset_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);

    if (response.StatusCode == 200)
        % Request succeeded
        N = response.Body.Data.count;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

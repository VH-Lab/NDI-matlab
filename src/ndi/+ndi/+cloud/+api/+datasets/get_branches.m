function [response, branches] = get_branches(dataset_id)
    % GET_BRANCHES - get the branches of a dataset
    %
    % [RESPONSE,BRANCHES] = ndi.cloud.api.datasets.GET_BRANCHES(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   RESPONSE - the get request summary
    %   BRANCHES - the branches required by the user
    %

    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_branches', 'dataset_id', dataset_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);

    if (response.StatusCode == 200)
        % Request succeeded
        branches = response.Body.Data.branches;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

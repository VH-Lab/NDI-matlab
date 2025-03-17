function response = create_dataset_branch(dataset_id, branch_name)
    % CREATE_DATASET_BRANCH - branch a given dataset
    %
    % RESPONSE = ndi.cloud.api.datasets.CREATE_DATASET_BRANCH(DATASET_ID, BRANCH_NAME)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %   BRANCH_NAME - a string representing the branch name
    %
    % Outputs:
    %   RESPONSE - the updated dataset summary
    %

    auth_token = ndi.cloud.authenticate();

    json = struct('branchName', branch_name);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('create_dataset_branch', 'dataset_id', dataset_id);

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

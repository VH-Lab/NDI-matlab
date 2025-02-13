function [status, response] = post_branch(dataset_id, branch_name)
    % POST_BRANCH - branch a given dataset
    %
    % [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_BRANCH(DATASET_ID, BRANCH_NAME)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %   BRANCH_NAME - a string representing the branch name
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the updated dataset summary
    %

    [auth_token, ~] = ndi.cloud.uilogin();

    json = struct('branchName', branch_name);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = matlab.net.URI(ndi.cloud.api.url('post_branch', 'dataset_id', dataset_id));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

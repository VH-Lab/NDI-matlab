function [status, response] = delete_dataset(dataset_id)
    % DELETE_DATASET - Delete a dataset. Datasets cannot be deleted if they
    % have been branched off of
    %
    % [STATUS, RESPONSE] = ndi.cloud.api.datasets.DELETE_DATASET(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   STATUS - did delete request work? 1 for no, 0 for yes
    %   RESPONSE - the delete confirmation
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.DELETE;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers);

    url = matlab.net.URI(ndi.cloud.api.url('delete_dataset', 'dataset_id', dataset_id));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 204)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

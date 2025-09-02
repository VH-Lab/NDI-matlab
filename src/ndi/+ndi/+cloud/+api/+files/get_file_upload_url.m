function [response, uploadUrl] = get_file_upload_url(dataset_id, uid)
    % GET_FILE_UPLOAD_URL - get an upload URL for an artifact file that will be published
    % to the NDI Cloud
    % Same functionality as ndi.cloud.api.files.GET_FILE_UPLOAD_URL
    %
    % [RESPONSE,URL] = ndi.cloud.api.datasets.GET_FILE_UPLOAD_URL(DATASET_ID, UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %   UID - a string representing a unique identifier that can be used to
    %   reference the file in documents
    %
    % Outputs:
    %   RESPONSE - the get request summary
    %   URL - the upload URL to PUT the file to
    %

    auth_token = ndi.cloud.authenticate();
    [dsetinfo] = ndi.cloud.api.datasets.get_dataset(dataset_id);

    url = ndi.cloud.api.url('get_file_upload_url', 'dataset_id', dataset_id, 'organization_id', dsetinfo.organizationId, 'file_uid', uid);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200) || (response.StatusCode == 201)
        % Request succeeded
        uploadUrl = response.Body.Data.url;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

function [response, uploadUrl] = get_raw_file_upload_url(dataset_id, uid)
    % GET_RAW_FILE_UPLOAD_URL - Get an upload URL for a raw data file that will be
    % published to AWS Open Data after review
    % Same functionality as ndi.cloud.api.files.GET_RAW_FILE_UPLOAD_URL
    %
    % [RESPONSE,URL] = ndi.cloud.api.datasets.GET_RAW_FILE_UPLOAD_URL(DATASET_ID, UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %   UID - a string representing a unique identifier that can be used to
    %   reference the file in documents
    %
    % Outputs:
    %   RESPONSE - the get request summary
    %   URL - the upload URL to PUT the file to

    auth_token = ndi.cloud.authenticate();
    % Construct the curl command with the organization ID and authentication token
    url = ndi.cloud.api.url('get_raw_file_upload_url', 'dataset_id', dataset_id, 'file_uid', uid);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        uploadUrl = response.Body.Data.url;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

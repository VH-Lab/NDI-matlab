function [status, response, url] = get_raw_file_upload_url(dataset_id, uid)
    % GET_RAW_FILE_UPLOAD_URL - get an upload URL for a raw data file that will be
    % published to AWS Open Data after review
    % Same functionality as ndi.cloud.api.files.GET_RAW_FILE_UPLOAD_URL
    %
    % [STATUS,RESPONSE,URL] = ndi.cloud.api.datasets.GET_RAW_FILE_UPLOAD_URL(DATASET_ID, UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %   UID - a string representing a unique identifier that can be used to
    %   reference the file in documents
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the get request summary
    %   URL - the upload URL to PUT the file to

    auth_token = ndi.cloud.authenticate();
    % Construct the curl command with the organization ID and authentication token
    url = matlab.net.URI(ndi.cloud.api.url('get_raw_file_upload_url', 'dataset_id', dataset_id, 'uid', uid));

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        url = response.Body.Data;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

function [status, response, url] = get_file_collection_upload_url(dataset_id)
    %GET_FILE_COLLECTION_UPLOAD_URL - get an upload URL for all file that will be published to the NDI Cloud
    %
    % [STATUS,RESPONSE,URL] = ndi.cloud.api.datasets.GET_FILE_COLLECTION_UPLOAD_URL(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the id of the dataset
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   RESPONSE - the get request summary
    %   URL - the upload URL to PUT the file to
    %
    
    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_file_collection_upload_url', 'dataset_id', dataset_id);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        url = response.Body.Data.url;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

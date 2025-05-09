function [file_detail, downloadUrl, response] = get_file_details(dataset_id,uid)
    % GET_FILE_DETAILS - Get the details, including the download url, for a individual file
    %
    % [FILE_DETAIL, DOWNLOADURL, RESPONSE] = ndi.cloud.api.datasets.GET_FILE_DETAILS(DATASET_ID,UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   UID - a string representing the file uid
    %
    % Outputs:
    %   FILE_DETAIL - the details of the file
    %   DOWNLOADURL - the download url for the file
    %   RESPONSE - the response from the server
    
    auth_token = ndi.cloud.authenticate();

    url = ndi.cloud.api.url('get_file_details', 'dataset_id', dataset_id, 'file_uid', uid);

    method = matlab.net.http.RequestMethod.GET;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        file_detail = response.Body.Data;
        downloadUrl = file_detail.downloadUrl;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
end

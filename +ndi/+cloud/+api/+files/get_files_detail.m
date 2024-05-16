function [status,file_detail,downloadUrl, response] = get_files_detail(dataset_id,uid)
    % GET_FILE_DETAILS - Get the details, including the download url, for a individual file
    %
    % [STATUS,FILE_DETAIL, DOWNLOADURL, RESPONSE] = ndi.cloud.api.files.GET_FILE_DETAILS(DATASET_ID,UID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %   UID - a string representing the file uid
    %
    % Outputs:
    %   STATUS - did get request work? 1 for no, 0 for yes
    %   FILE_DETAIL - the details of the file
    %   DOWNLOADURL - the download url for the file
    %   RESPONSE - the response from the server
    [auth_token, ~] = ndi.cloud.uilogin();
    
    url = matlab.net.URI(ndi.cloud.api.url('get_dataset_details', 'dataset_id', dataset_id, 'uid', uid));
    
    method = matlab.net.http.RequestMethod.GET;
    
    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];
    
    request = matlab.net.http.RequestMessage(method, headers);
    response = send(request, url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
        file_detail = response.Body.Data;
        downloadUrl = response.Body.Data.downloadUrl;
    else
        error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
    end
    end
    
    

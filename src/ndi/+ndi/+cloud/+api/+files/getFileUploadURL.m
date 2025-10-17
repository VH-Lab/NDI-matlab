function [b, answer, apiResponse, apiURL] = getFileUploadURL(cloudDatasetID, cloudFileUID)
%GETFILEUPLOADURL Get a pre-signed URL for uploading a single file.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileUploadURL(CLOUDDATASETID, CLOUDFILEUID)
%
%   Retrieves a URL that can be used to PUT the contents of a single file
%   for a dataset.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset.
%       cloudFileUID        - The unique identifier that will be used for the file.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The pre-signed upload URL (string) on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, upload_url] = ndi.cloud.api.files.getFileUploadURL('d-12345', 'f-newfile');
%
%   See also: ndi.cloud.api.implementation.files.GetFileUploadURL

    arguments
        cloudDatasetID (1,1) string
        cloudFileUID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.GetFileUploadURL(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudFileUID', cloudFileUID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


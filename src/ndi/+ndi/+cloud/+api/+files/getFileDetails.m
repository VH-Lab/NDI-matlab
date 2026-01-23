function [b, answer, apiResponse, apiURL] = getFileDetails(cloudDatasetID, cloudFileUID)
%GETFILEDETAILS Get details and a download URL for a specific file.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileDetails(CLOUDDATASETID, CLOUDFILEUID)
%
%   Retrieves metadata for a single file within a dataset, including a
%   pre-signed download URL.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset containing the file.
%       cloudFileUID        - The unique identifier (UID) of the file.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with file details (including 'downloadUrl') on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, file_info] = ndi.cloud.api.files.getFileDetails('d-12345', 'f-abcde');
%       if success
%           ndi.cloud.api.files.getFile(file_info.downloadUrl, 'myfile.dat');
%       end
%
%   See also: ndi.cloud.api.implementation.files.GetFileDetails,
%             ndi.cloud.api.files.getFile

    arguments
        cloudDatasetID (1,1) string
        cloudFileUID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.GetFileDetails(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudFileUID', cloudFileUID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


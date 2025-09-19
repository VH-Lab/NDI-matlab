function [b, answer, apiResponse, apiURL] = getFileCollectionUploadURL(cloudDatasetID)
%GETFILECOLLECTIONUPLOADURL Get a pre-signed URL for uploading a file collection (zip).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileCollectionUploadURL(CLOUDDATASETID)
%
%   Retrieves a URL that can be used to PUT a zip archive containing multiple files
%   for a dataset.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The pre-signed upload URL (string) on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, upload_url] = ndi.cloud.api.files.getFileCollectionUploadURL('d-12345');
%
%   See also: ndi.cloud.api.implementation.files.GetFileCollectionUploadURL

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.GetFileCollectionUploadURL('cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


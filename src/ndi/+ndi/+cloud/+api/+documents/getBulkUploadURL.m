function [b, answer, apiResponse, apiURL] = getBulkUploadURL(cloudDatasetID)
%GETBULKUPLOADURL User-facing wrapper to get a bulk document upload URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getBulkUploadURL(CLOUDDATASETID)
%
%   Retrieves a pre-signed URL that can be used to upload a zip archive
%   containing multiple documents to a dataset.
%
%   Inputs:
%       cloudDatasetID     - The ID of the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The pre-signed upload URL on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, url] = ndi.cloud.api.documents.getBulkUploadURL('d-12345');
%
%   See also: ndi.cloud.api.implementation.documents.GetBulkUploadURL

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.GetBulkUploadURL(...
        'cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


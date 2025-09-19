function [b, answer, apiResponse, apiURL] = countDocuments(cloudDatasetID)
%COUNTDOCUMENTS User-facing wrapper to count documents in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.countDocuments(CLOUDDATASETID)
%
%   Retrieves the total number of documents in a specified dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset to query.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The document count on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, count] = ndi.cloud.api.documents.countDocuments('d-12345');
%
%   See also: ndi.cloud.api.implementation.documents.CountDocuments

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.CountDocuments(...
        'cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


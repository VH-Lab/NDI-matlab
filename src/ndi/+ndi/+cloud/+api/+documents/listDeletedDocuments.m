function [b, answer, apiResponse, apiURL] = listDeletedDocuments(cloudDatasetID, options)
%LISTDELETEDDOCUMENTS Retrieves a list of soft-deleted documents in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.listDeletedDocuments(CLOUDDATASETID, OPTIONS)
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset.
%       options.page     - (Optional) Page number (default: 1).
%       options.pageSize - (Optional) Number of results per page (default: 100).
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success (JSON object with documents array).
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.documents.ListDeletedDocuments

    arguments
        cloudDatasetID (1,1) string
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 100
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.ListDeletedDocuments(...
        'cloudDatasetID', cloudDatasetID, 'page', options.page, 'pageSize', options.pageSize);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end

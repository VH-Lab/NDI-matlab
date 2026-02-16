function [b, answer, apiResponse, apiURL] = bulkDeleteDocuments(cloudDatasetID, cloudDocumentIDs, options)
%BULKDELETEDOCUMENTS User-facing wrapper to delete multiple documents.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.bulkDeleteDocuments(CLOUD_DATASET_ID, CLOUD_DOCUMENT_IDS, 'when', '7d')
%
%   Deletes multiple documents from a dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset containing the documents.
%       cloudDocumentIDs - A string array of cloud API document IDs to delete.
%       options.when     - (Optional) Duration string (e.g., '7d', 'now'). Default: '7d'.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The body of the API response on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.documents.BulkDeleteDocuments

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentIDs (1,:) string
        options.when (1,1) string = "7d"
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.BulkDeleteDocuments(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentIDs', cloudDocumentIDs, ...
        'when', options.when);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

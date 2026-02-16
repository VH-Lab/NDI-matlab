function [b, answer, apiResponse, apiURL] = deleteDocument(cloudDatasetID, cloudDocumentID, options)
%DELETEDOCUMENT User-facing wrapper to delete a single document.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.deleteDocument(CLOUDDATASETID, CLOUDDOCUMENTID, 'when', '7d')
%
%   Deletes a single document from a specified dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset containing the document.
%       cloudDocumentID  - The cloud API ID of the document to delete.
%       options.when     - (Optional) Duration string (e.g., '7d', 'now'). Default: '7d'.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, resp] = ndi.cloud.api.documents.deleteDocument('d-12345', 'doc-abcde', 'when', 'now');
%
%   See also: ndi.cloud.api.implementation.documents.DeleteDocument

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
        options.when (1,1) string = "7d"
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.DeleteDocument(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'when', options.when);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

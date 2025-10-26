function [b, answer, apiResponse, apiURL] = bulkDeleteDocuments(cloudDatasetID, cloudDocumentIDs)
%BULKDELETEDOCUMENTS User-facing wrapper to delete multiple documents from a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.bulkDeleteDocuments(CLOUDDATASETID, CLOUDDOCUMENTIDS)
%
%   Deletes a specified list of documents from a dataset on the NDI Cloud in
%   a single API call.
%
%   Inputs:
%       cloudDatasetID   - The ID of the dataset from which documents will be deleted.
%       cloudDocumentIDs - A string array of the cloud API document IDs to delete.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       ids_to_delete = ["doc_id_1", "doc_id_2"];
%       [success, result] = ndi.cloud.api.documents.bulkDeleteDocuments('d-12345', ids_to_delete);
%
%   See also: ndi.cloud.api.implementation.documents.BulkDeleteDocuments

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentIDs (1,:) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.BulkDeleteDocuments(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentIDs', cloudDocumentIDs);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


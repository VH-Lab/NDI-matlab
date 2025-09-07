function [b, answer, apiResponse, apiURL] = updateDocument(cloudDatasetID, cloudDocumentID, documentInfoStruct)
%UPDATEDOCUMENT User-facing wrapper to update a document in a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.updateDocument(CLOUDDATASETID, CLOUDDOCUMENTID, DOCSTRUCT)
%
%   Updates an existing document on the NDI Cloud with new data.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset containing the document.
%       cloudDocumentID     - The cloud API ID of the document to update.
%       documentInfoStruct  - A struct containing the new data for the document.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The updated document summary on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, updated_doc] = ndi.cloud.api.documents.updateDocument(...
%           'd-12345', 'doc-abcde', struct('newField', 'newValue'));
%
%   See also: ndi.cloud.api.implementation.documents.UpdateDocument

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
        documentInfoStruct (1,1) struct
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.UpdateDocument(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'documentInfoStruct', documentInfoStruct);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


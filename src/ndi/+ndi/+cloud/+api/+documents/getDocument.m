function [b, answer, apiResponse, apiURL] = getDocument(cloudDatasetID, cloudDocumentID)
%GETDOCUMENT User-facing wrapper to get a single document from a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.getDocument(CLOUDDATASETID, CLOUDDOCUMENTID)
%
%   Retrieves the full content of a specific document from the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset.
%       cloudDocumentID - The cloud API ID of the document to retrieve.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The document structure on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, doc_data] = ndi.cloud.api.documents.getDocument('d-12345', 'doc-abcde');
%
%   See also: ndi.cloud.api.implementation.documents.GetDocument

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.GetDocument(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


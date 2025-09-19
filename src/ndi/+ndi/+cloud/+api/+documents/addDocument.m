function [b, answer, apiResponse, apiURL] = addDocument(cloudDatasetID, jsonDocument)
%ADDDOCUMENT User-facing wrapper to add a document to a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.addDocument(CLOUDDATASETID, JSONDOCUMENT)
%
%   Adds a new document to a specified dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID    - The ID of the dataset to which the document will be added.
%       jsonDocument      - A JSON-encoded string representing the new document.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       doc_string = '{"my_field":"my_value"}';
%       [success, result] = ndi.cloud.api.documents.addDocument('d-12345', doc_string);
%
%   See also: ndi.cloud.api.implementation.documents.AddDocument

    arguments
        cloudDatasetID (1,1) string
        jsonDocument (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.AddDocument(...
        'cloudDatasetID', cloudDatasetID, ...
        'jsonDocument', jsonDocument);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


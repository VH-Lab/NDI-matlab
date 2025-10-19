function [b, answer, apiResponse, apiURL] = addDocumentAsFile(cloudDatasetID, filePath)
%ADDDOCUMENTASFILE User-facing wrapper to add a large document from a file.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.addDocumentAsFile(CLOUDDATASETID, FILEPATH)
%
%   Adds a new document to a specified dataset on the NDI Cloud by uploading
%   a file containing the document's JSON data. This is more efficient for
%   large documents.
%
%   Inputs:
%       cloudDatasetID    - The ID of the dataset to which the document will be added.
%       filePath          - The full path to the file containing the JSON-encoded document.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % Assume 'large_doc.json' contains the document data
%       [success, result] = ndi.cloud.api.documents.addDocumentAsFile('d-12345', 'large_doc.json');
%
%   See also: ndi.cloud.api.implementation.documents.AddDocumentAsFile

    arguments
        cloudDatasetID (1,1) string
        filePath (1,1) string {mustBeFile}
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.documents.AddDocumentAsFile(...
        'cloudDatasetID', cloudDatasetID, ...
        'filePath', filePath);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


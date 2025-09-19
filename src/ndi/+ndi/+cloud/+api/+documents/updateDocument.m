function [b, answer, apiResponse, apiURL] = updateDocument(cloudDatasetID, cloudDocumentID, jsonDocument)
%UPDATEDOCUMENT Updates an existing document on the NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.updateDocument(CLOUDDATASETID, CLOUDDOCUMENTID, JSONDOCUMENT)
%
%   Updates a document specified by CLOUDDOCUMENTID within the dataset
%   CLOUDDATASETID, using the new data provided in JSONDOCUMENT.
%
%   Inputs:
%       CLOUDDATASETID (string) - The ID of the dataset on the cloud.
%       CLOUDDOCUMENTID (string) - The cloud API ID of the document to update.
%       JSONDOCUMENT (string) - A string containing the full JSON data for the
%           updated document.
%
%   Outputs:
%       B (logical) - True if the API call was successful, false otherwise.
%       ANSWER - The body of the server's response.
%       APIRESPONSE - The full HTTP response object.
%       APIURL - The URL that was called.
%
    api_call = ndi.cloud.api.implementation.documents.UpdateDocument(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'jsonDocument', jsonDocument);
    
    [b, answer, apiResponse, apiURL] = api_call.execute();
end


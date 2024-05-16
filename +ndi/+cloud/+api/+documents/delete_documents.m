function [status, response] = delete_documents(dataset_id, document_id)
% DELETE_DOCUMENTS - delete a document from the dataset
%
% [STATUS,RESPONSE] = ndi.cloud.api.documents.DELETE_DOCUMENTS(DATASET_ID, DOCUMENT_ID)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%
% Outputs:
%   STATUS - did delete request work? 1 for no, 0 for yes
%   RESPONSE - a message saying if the document was deleted or not 
%

[auth_token, ~] = ndi.cloud.uilogin();

method = matlab.net.http.RequestMethod.DELETE;

acceptField = matlab.net.http.HeaderField('accept','application/json');
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField authorizationField];

req = matlab.net.http.RequestMessage(method, headers);

url = matlab.net.URI(ndi.cloud.api.url('delete_documents', 'dataset_id', dataset_id, 'document_id', document_id));

response = req.send(url);
status = 1;
if (response.StatusCode == 200)
    status = 0;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end

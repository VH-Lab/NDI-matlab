function [status, response, document] = get_documents(dataset_id, document_id)
% GET_DOCUMENTS - get a document
%
% [STATUS,RESPONSE,DOCUMENT] = ndi.cloud.api.documents.GET_DOCUMENTS(DATASET_ID, DOCUMENT_ID)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%   DOCUMENT - A document object required by the user
%

[auth_token, ~] = ndi.cloud.uilogin();

url = matlab.net.URI(ndi.cloud.api.url('get_documents', 'dataset_id', dataset_id, 'document_id', document_id));

method = matlab.net.http.RequestMethod.GET;

acceptField = matlab.net.http.HeaderField('accept','application/json');
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField authorizationField];

request = matlab.net.http.RequestMessage(method, headers);
response = send(request, url);
status = 1;
if (response.StatusCode == 200)
    status = 0;
    document = response.Body.Data;
else
    error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
end
end

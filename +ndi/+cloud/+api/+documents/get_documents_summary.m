function [status, response, summary] = get_documents_summary(dataset_id)
% GET_DOCUMENTS_SUMMARY - get a document summaries for a dataset
%
% [STATUS,RESPONSE,SUMMARY] = ndi.cloud.api.documents.GET_DOCUMENTS_SUMMARY(DATASET_ID)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get response
%   SUMMARY - The list of documents in the dataset
%

[auth_token, ~] = ndi.cloud.uilogin();

url = matlab.net.URI(ndi.cloud.api.url('get_documents_summary', 'dataset_id', dataset_id));

method = matlab.net.http.RequestMethod.GET;

acceptField = matlab.net.http.HeaderField('accept','application/json');
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField authorizationField];

request = matlab.net.http.RequestMessage(method, headers);
response = send(request, url);
status = 1;
if (response.StatusCode == 200)
    status = 0;
    summary = response.Body.Data;
else
    error('Failed to run command. %s', response.StatusLine.ReasonPhrase);
end
end

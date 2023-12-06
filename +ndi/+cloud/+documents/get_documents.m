function [status, response, document] = get_documents(dataset_id, document_id, auth_token)
% GET_DOCUMENTS - get a document
%
% [STATUS,RESPONSE,DOCUMENT] = ndi.cloud.documents.get_documents(DATASET_ID, DOCUMENT_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%   DOCUMENT - A document object required by the user
%

% Construct the curl command with the organization ID and authentication token

url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents/%s', dataset_id, document_id);
cmd = sprintf("curl -X 'GET' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' ", url, auth_token);

% Run the curl command and capture the output
[status, output] = system(cmd);

% Check the status code and handle any errors
if status ~= 0
    error('Failed to run curl command: %s', output);
end

% Process the JSON response
response = jsondecode(output);
if isfield(response, 'error')
    error(response.error);
end
document = response;
end

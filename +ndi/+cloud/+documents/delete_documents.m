function [status, response] = delete_documents(dataset_id, document_id, auth_token)
% DELETE_DOCUMENTS - delete a document from the dataset
%
% [STATUS,RESPONSE] = ndi.cloud.documents.delete_documents(DATASET_ID, DOCUMENT_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did delete request work? 1 for no, 0 for yes
%   RESPONSE - a message saying if the document was deleted or not 
%

% Prepare the JSON data to be sent in the POST request
document_str = jsonencode(document);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents/%s', dataset_id, document_id);
cmd = sprintf("curl -X 'DELETE' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' ", url, auth_token, document_str);

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
end
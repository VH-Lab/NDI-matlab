function [status, response] = post_documents(dataset_id, document, auth_token)
% POST_DOCUMENTS - add a document to the dataset
%
% [STATUS,RESPONSE] = ndi.cloud.documents.post_documents_update(DATASET_ID, DOCUMENT, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT - a JSON object representing the new document
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the new document summary
%

% Prepare the JSON data to be sent in the POST request
document_str = jsonencode(document);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents', dataset_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-H 'Content-Type: application/json' " +...
    " -d '%s' ", url, auth_token, document_str);

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

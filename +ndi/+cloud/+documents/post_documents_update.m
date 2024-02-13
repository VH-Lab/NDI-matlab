function [status, response] = post_documents_update(dataset_id, document_id, document, auth_token)
% POST_DOCUMENTS_UPDATE - update a document
%
% [STATUS,RESPONSE] = ndi.cloud.documents.post_documents_update(DATASET_ID, DOCUMENT_ID, DOCUMENT, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   DOCUMENT_ID -  a string representing the document id
%   DOCUMENT - a JSON object representing the updated version of the
%   document
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the updated document summary
%

% Prepare the JSON data to be sent in the POST request
document_str = jsonencode(document);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/documents/%s', dataset_id, document_id);
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

% Process the JSON response; if the command failed, it might be a plain text error message
try,
	response = jsondecode(output);
catch,
	error(['Command failed with message: ' output ]);
end;

if isfield(response, 'error')
    error(response.error);
end
end

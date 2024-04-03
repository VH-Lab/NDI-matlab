function [status, response, summary] = get_documents_summary(dataset_id, auth_token)
% GET_DOCUMENTS_SUMMARY - get a document summaries for a dataset
%
% [STATUS,RESPONSE,SUMMARY] = ndi.cloud.api.documents.GET_DOCUMENTS_SUMMARY(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get response
%   SUMMARY - The list of documents in the dataset
%

url = ndi.cloud.api.url('get_documents_summary', 'dataset_id', dataset_id);
cmd = sprintf("curl -X 'GET' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' ", url, auth_token);

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
summary = response;
end

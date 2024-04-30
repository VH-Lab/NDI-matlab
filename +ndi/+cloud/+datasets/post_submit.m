function [status, response] = post_submit(dataset_id, auth_token)
% POST_SUBMIT - submit a dataset for review
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.post_submit(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - an id of the dataset
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did the post request work? 1 for no, 0 for yes
%   RESPONSE - the dataset was submitted
%
    
% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/submit', dataset_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-d ' '", url, auth_token);

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

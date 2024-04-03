function [status, response] = post_branch(dataset_id, branch_name, auth_token)
% POST_BRANCH - branch a given dataset
%
% [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_BRANCH(DATASET_ID, BRANCH_NAME, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the id of the dataset
%   BRANCH_NAME - a string representing the branch name
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%

% Prepare the JSON data to be sent in the POST request
json = struct('branchName', branch_name);
json_str = jsonencode(json);

url = ndi.cloud.api.url('post_branch', 'dataset_id', dataset_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-H 'Content-Type: application/json' " +...
    " -d '%s' ", url, auth_token, json_str);

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

function [status, response, branches] = get_branches(dataset_id, auth_token)
% GET_BRANCHES - get the branches of a dataset
%
% [STATUS,RESPONSE,BRANCHES] = ndi.cloud.datasets.get_branches(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get request summary
%   BRANCHES - the branches required by the user
%

% Prepare the JSON data to be sent in the POST request
json = struct('branchName', branch_name);
json_str = jsonencode(json);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/branches', dataset_id);
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
branches = response.branches;
end
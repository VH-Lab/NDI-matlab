function [status, response] = post_publish(dataset_id, auth_token)
% POST_PUBLISH - publish a dataset
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.post_publish(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - an id of the dataset
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did the post request work? 1 for no, 0 for yes
%   RESPONSE - the dataset was published
%
    
% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/publish', dataset_id);
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

% Process the JSON response
response = jsondecode(output);
if isfield(response, 'error')
    error(response.error);
end
end
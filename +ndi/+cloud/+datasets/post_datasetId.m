function [status, response] = post_datasetId(dataset_id, dataset, auth_token)
% POST_DATASETID - update a dataset to NDI Cloud
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.post_datasets_datasetId(DATASET_ID, DATASET, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - an id of the dataset
%   DATASET - the updated version of the dataset in JSON-formatted text
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did the post request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%
    
% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s', dataset_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-H 'Content-Type: application/json' " + ...
    "-d '%s'", url, auth_token, dataset);

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

function [status, response, url] = get_files_raw(dataset_id, uid, auth_token)
% GET_FILES_RAW - get an upload URL for a raw data file that will be
% published to AWS Open Data after review
%
% [STATUS,RESPONSE,URL] = ndi.cloud.datasets.get_files_raw(DATASET_ID, UID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the id of the dataset
%   UID - a string representing a unique identifier that can be used to
%   reference the file in documents
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get request summary
%   URL - the upload URL to PUT the file to
%
    
% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/files/raw/%s', dataset_id, uid);
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
url = response.url;
end
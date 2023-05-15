function [status, response, upload_url] = get_files(dataset_id, uid, auth_token)
% GET_FILES - get an upload URL for an artifact file that will be
% published to NDI Cloud
%
% [STATUS,RESPONSE,UPLOAD_URL] = ndi.cloud.files.get_files(DATASET_ID, UID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   UID -  a string representing the unique identifier that can be used to
%   reference the file in document
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the upload summary
%   UPLOAD_URL - the upload URL to put the file to
%

% Construct the curl command with the organization ID and authentication token

url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/%s/files/%s', dataset_id, uid);
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
upload_url = response.url;
end

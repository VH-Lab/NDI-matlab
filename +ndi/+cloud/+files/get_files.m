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

url = ndi.cloud.api.url('get_files', 'dataset_id', dataset_id , 'uid', uid);
cmd = sprintf("curl -X 'GET' '%s' " + ...
    "-H 'Authorization: Bearer %s' ", url, auth_token);
disp(cmd);
% Run the curl command and capture the output
[status, output] = system(cmd);
disp(output);
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
upload_url = response.url;
end

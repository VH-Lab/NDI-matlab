function [status, response] = delete_datasetId(dataset_id, auth_token)
% DELETE_DATASETID - Delete a dataset. Datasets cannot be deleted if they
% have been branched off of
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.delete_datasetId(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did delete request work? 1 for no, 0 for yes
%   RESPONSE - the delete confirmation
%
    
% Construct the curl command with the organization ID and authentication token
url = ndi.cloud.api.url('delete_datasetId', 'dataset_id', dataset_id);
cmd = sprintf("curl -X 'DELETE' '%s' " + ...
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
end

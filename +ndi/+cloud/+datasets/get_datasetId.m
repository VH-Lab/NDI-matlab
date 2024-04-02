function [status,dataset, response] = get_datasetId(dataset_id, auth_token)
% GET_DATASETID - get a dataset
%
% [STATUS,DATASET, RESPONSE] = ndi.cloud.datasets.get_datasetId(DATASET_ID, AUTH_TOKEN)
%
% Inputs:
%   DATASET_ID - a string representing the dataset id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   DATASET - the dataset required by the user
%   RESPONSE - the response from the server
    
% Construct the curl command with the organization ID and authentication token
url = ndi.cloud.api.url('get_datasetId', 'dataset_id', dataset_id);
cmd = sprintf("curl -X 'GET' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' ", url, auth_token);

% Run the curl command and capture the output
[status, output] = system(cmd);
response = jsondecode(output);
dataset = '';
% Check the status code and handle any errors
if status
    error('Failed to run curl command: %s', output);
else
        % Process the JSON response; if the command failed, it might be a plain text error message
    try,
	    dataset = jsondecode(output);
    catch,
	    error(['Command failed with message: ' output ]);
    end;
    if isfield(dataset, 'error')
        error(dataset.error);
    end
end
end

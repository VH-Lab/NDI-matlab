function [status, response, dataset_id] = post_organization(organization_id, dataset, auth_token)
% POST_ORGANIZATION - Create a new dataset
%
% [STATUS,RESPONSE] = ndi.cloud.api.datasets.POST_ORGANIZATION(ORGANIZATION_ID, DATASET, AUTH_TOKEN)
%
% Inputs:
%   ORGANIZATION_ID - a string representing the id of the organization
%   DATASET - a JSON object representing the dataset
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the new dataset summary
%   DATASET_ID - the id of the newly created dataset

% Prepare the JSON data to be sent in the POST request
dataset_str = jsonencode(dataset);

url = ndi.cloud.api.url('post_organization', 'organization_id', organization_id);
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " + ...
    "-H 'Content-Type: application/json' " + ...
    "-d '%s'", url, auth_token, dataset_str);

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
dataset_id = response.id;
end

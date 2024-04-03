function [status, response, datasets] = get_organizations(organization_id, auth_token)
% GET_ORGANIZATIONS - get a high level summary of all datasets in the
% organization
%
% [STATUS,RESPONSE, DATASETS] = ndi.cloud.api.datasets.GET_ORGANIZATIONS(ORGANIZATION_ID, AUTH_TOKEN)
%
% Inputs:
%   ORGANIZATION_ID - a string representing the id of the organization
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the get request summary
%   DATASETS - A high level summary of all datasets in the organization
%
    
% Construct the curl command with the organization ID and authentication token
url = ndi.cloud.api.url('get_organizations', 'organization_id', organization_id);
cmd = sprintf("curl -X 'GET' '%s' " + ...
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
if isfield(response, 'errors')
    datasets = response.errors;
else
    datasets = response.datasets;
end
end

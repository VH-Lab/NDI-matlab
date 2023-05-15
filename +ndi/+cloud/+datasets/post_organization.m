function [status, response] = post_organization(organization_id, dataset, auth_token)
% POST_ORGANIZATIONS - Create a new dataset
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.post_organizations(ORGANIZATION_ID, DATASET, AUTH_TOKEN)
%
% Inputs:
%   ORGANIZATION_ID - a string representing the id of the organization
%   DATASET - a JSON object representing the dataset
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%

% Prepare the JSON data to be sent in the POST request
dataset_str = jsonencode(dataset);

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/organizations/%s/datasets', organization_id);
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

% Process the JSON response
response = jsondecode(output);
if isfield(response, 'error')
    error(response.error);
end
end

function [status, response] = get_unpublished(page, page_size, auth_token)
% GET_UNPUBLISHED - get all submitted but unpublished datasets
%
% [STATUS,RESPONSE] = ndi.cloud.datasets.get_unpublished(PAGE, PAGE_SIZE, AUTH_TOKEN)
%
% Inputs:
%   PAGE - an integer representing the page of result to get
%   DATASET - an integer representing the number of results per page
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - the updated dataset summary
%

% Construct the curl command with the organization ID and authentication token
page = int2str(page);
page_size = int2str(page_size);
url = sprintf('https://dev-api.ndi-cloud.com/v1/datasets/unpublished?page=%n&pageSize=%n', page, page_size);
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
end

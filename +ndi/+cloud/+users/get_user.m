function [status, response, name, email, organizations] = get_user(user_id, auth_token)
% GET_USER - get a user
%
% [STATUS,RESPONSE, NAME, EMAIL, ORGANIZATIONS] = ndi.cloud.user.get_user(USER_ID, AUTH_TOKEN)
%
% Inputs:
%   USER_ID - a string representing the user's id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did get request work? 1 for no, 0 for yes
%   RESPONSE - a message indicates if the user is found
%   NAME - a string representing the user's name
%   EMAIL - a string representing the user's e-mail
%   ORGANIZATIONS - a json object representing the organization information

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/users/%s', user_id);
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
email = response.email;
name = response.name;
organizations = response.organizations;
end
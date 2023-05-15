function [status, response] = post_user(email, name, password)
% POST_USER - create a new user
%
% [STATUS,RESPONSE] = ndi.cloud.user.post_users(EMAIL, NAME, PASSWORD)
%
% Inputs:
%   EMAIL - a string representing the user's e-mail
%   NAME -  a string representing the username
%   PASSWORD - a string representing the user's password
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - a message indicates if the user is created or not
%

% Prepare the JSON data to be sent in the POST request
json = struct('email', email, 'name', name, 'password', password);
json_str = jsonencode(json);

% Construct the curl command with the organization ID and authentication token
url = 'https://dev-api.ndi-cloud.com/v1/users';
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Content-Type: application/json' " +...
    " -d '%s' ", url, json_str);

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

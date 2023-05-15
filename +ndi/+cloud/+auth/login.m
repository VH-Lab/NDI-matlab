function [auth_token, organization_id] = login(email, password)
% LOGIN - logs in a user
%
% [AUTH_TOKEN,ORGANIZATION_ID] = ndi.cloud.auth.LOGIN(EMAIL, PASSWORD)
%
% Inputs:
%   EMAIL - a string representing the user's e-mail
%   PASSWORD - a string representing the user's password
%
% Outputs:
%   STATUS - did the user logs in successfully? 1 for no, 0 for yes
%   RESPONSE - the response summary
%

% Prepare the JSON data to be sent in the POST request
json = struct('email', email, 'password', password);
json_str = jsonencode(json);

% Construct the curl command
url = 'https://rsmz66zk54.execute-api.us-east-1.amazonaws.com/dev/v1/auth/login';
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Content-Type: application/json' " + ...
    " -d '%s'", url, json_str);

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

% Extract the authentication token from the response
auth_token = response.token;
organization_id = response.user.organizations.id;
end

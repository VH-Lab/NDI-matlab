function [status, response] = post_user_update(user_id, auth_token)
% POST_USER_UPDATE - update a user
%
% [STATUS,RESPONSE] = ndi.cloud.user.post_users_update(USER_ID)
%
% Inputs:
%   USER_ID - a string representing the user's id
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did post request work? 1 for no, 0 for yes
%   RESPONSE - a message indicates if the user is updated or not
%

% Construct the curl command with the organization ID and authentication token
url = sprintf('https://dev-api.ndi-cloud.com/v1/users/%s', user_id);

cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " + ...
    " -d '' ", url, auth_token);

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

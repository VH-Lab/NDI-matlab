function [status, response] = logout(auth_token)
% LOGOUT - logs a user out and invalidates their token
%
% [STATUS,RESPONSE] = ndi.cloud.auth.LOGOUT(AUTH_TOKEN)
%
% Inputs:
%   AUTH_TOKEN - a string representing the authentification token
%
% Outputs:
%   STATUS - did user log out? 1 for no, 0 for yes
%   RESPONSE - the response summary
%

% Construct the curl command
url = ndi.cloud.api.url('logout');
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Authorization: Bearer %s' " +...
    "-d ''", url, auth_token);

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

disp('Logout successful!');
end
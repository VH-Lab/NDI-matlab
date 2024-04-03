function [status, auth_token, organization_id] = login(email, password)
% LOGIN - logs in a user
%
% [AUTH_TOKEN,ORGANIZATION_ID] = ndi.cloud.api.auth.LOGIN(EMAIL, PASSWORD)
%
% Inputs:
%   EMAIL - a string representing the user's e-mail
%   PASSWORD - a string representing the user's password
%
% Outputs:
%   STATUS - did the user logs in successfully? 1 for no, 0 for yes
%   AUTH_TOKEN - bearer token
%   ORGANIZATION_ID - the organization id that the user belongs to
%

% Prepare the JSON data to be sent in the POST request
json = struct('email', email, 'password', password);
json_str = jsonencode(json);

% Construct the curl command
url = ndi.cloud.api.url('login');
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Content-Type: application/json' " + ...
    " -d '%s'", url, json_str);

% Run the curl command and capture the output
[status, output] = system(cmd);

% Check the status code
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
    status = 1;
    auth_token = response.errors;
    organization_id = response.errors;
else
    auth_token = response.token;
    organization_id = response.user.organizations.id;
end
end

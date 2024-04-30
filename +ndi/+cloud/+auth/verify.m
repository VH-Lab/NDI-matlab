function [status,response] = verify(email, confirmation_code)
% VERIFY - verifies a user via the confirmation code sent in e-mail
% [STATUS,RESPONSE] = ndi.cloud.auth.verify(EMAIL, CONFIRMATION_CODE)
%
% Inputs:
%   EMAIL - a string representing the email address used to verify
%   CONFIRMATION_CODE - the code send to the email
%
% Outputs:
%   STATUS - is the confirmation code correct? 1 for no, 0 for yes
%   RESPONSE - the response summary
%
 % Prepare the JSON data to be sent in the POST request
json = struct('email', email, 'confirmationCode', confirmation_code);
jsonStr = jsonencode(json);
url = 'https://dev-api.ndi-cloud.com/v1/auth/verify';

% Construct the curl command
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Content-Type: application/json' " + ...
    "-d '%s'", url, jsonStr);


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

end

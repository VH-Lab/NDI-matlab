function [status,response] = password_forgot(email)
% PASSWORD - sends a password reset e-mail
%
% [STATUS,RESPONSE] = ndi.cloud.api.auth.password_forgot(EMAIL)
%
% Inputs:
%   EMAIL - a string representing the email address used to send the
%   e-mail
%
% Outputs:
%   STATUS - did the e-mail sent? 1 for no, 0 for yes
%   RESPONSE - the response summary
%
 % Prepare the JSON data to be sent in the POST request
json = struct('email', email);
jsonStr = jsonencode(json);
url = ndi.cloud.api.url('password_forgot');

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



function [status,response] = confirmation_resend(email)
% CONFIRMATION_RESEND - Resends the verification code via email
%
% [STATUS,RESPONSE] = ndi.cloud.auth.confirmation_resend(EMAIL)
%
% Inputs:
%   EMAIL - a string representing the email address used to send the
%   verification
%
% Outputs:
%   STATUS - did the confirmation sent? 1 for no, 0 for yes
%   RESPONSE - the response summary
%

% Prepare the JSON data to be sent in the POST request
json = struct('email', email);
json_str = jsonencode(json);

% Construct the curl command
url = 'https://dev-api.ndi-cloud.com/v1/auth/confirmation/resend';
cmd = sprintf("curl -X 'POST' '%s' " + ...
    "-H 'accept: application/json' " + ...
    "-H 'Content-Type: application/json' " + ...
    "-d '%s'", url, json_str);


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
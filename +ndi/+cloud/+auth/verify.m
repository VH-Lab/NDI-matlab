function [status,response] = verify(email, confirmationCode)
% VERIFY - verifies a user via the confirmation code sent in e-mail
% [STATUS,RESPONSE] = ndi.cloud.auth.verify(EMAIL, CONFIRMATIONCODE)
%
% Inputs:
%   EMAIL - a string representing the email address used to verify
%   CONFIRMATIONCODE - the code send to the email
%
% Outputs:
%   STATUS - is the confirmation code correct? 1 for no, 0 for yes
%   RESPONSE - the response summary
%
 % Prepare the JSON data to be sent in the POST request
json = struct('email', email, 'confirmationCode', confirmationCode);
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

% Process the JSON response
response = jsondecode(output);
if isfield(response, 'error')
    error(response.error);
end

end

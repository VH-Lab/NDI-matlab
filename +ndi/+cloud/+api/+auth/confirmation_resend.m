function [status,response] = confirmation_resend(email)
% CONFIRMATION_RESEND - Resends the verification code via email
%
% [STATUS,RESPONSE] = ndi.cloud.api.auth.confirmation_resend(EMAIL)
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

method = matlab.net.http.RequestMethod.POST;

body = matlab.net.http.MessageBody(json);

contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
header = [acceptField contentTypeField];

req = matlab.net.http.RequestMessage(method, header, body);

url = matlab.net.URI(url = ndi.cloud.api.url('confirmation_resend'));

response = req.send(url);
if (response.StatusCode == 200 || response.StatusCode == 201)
    status = 1;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end

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
json = struct('email', email);

method = matlab.net.http.RequestMethod.POST;

body = matlab.net.http.MessageBody(json);

acceptField = matlab.net.http.HeaderField('accept','application/json');
contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField contentTypeField authorizationField];

req = matlab.net.http.RequestMessage(method, headers, body);

url = matlab.net.URI(ndi.cloud.api.url('password_forgot'));

response = req.send(url);
status = 1;
if (response.StatusCode == 200 || response.StatusCode == 201)
    status = 0;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end



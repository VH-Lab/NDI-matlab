function [status,response] = password(oldPassword, newPassword)
% PASSWORD - update a users password
%
% [STATUS,RESPONSE] = ndi.cloud.api.auth.PASSWORD(OLDPASSWORD, NEWPASSWORD)
%
% Inputs:
%   OLDPASSWORD - a string representing the old password
%   NEWPASSWORD - a string representing the new password
%
% Outputs:
%   STATUS - did the new password correctly set? 1 for no, 0 for yes
%   RESPONSE - the response summary
%

[auth_token, ~] = ndi.cloud.uilogin();
json = struct('oldPassword', oldPassword, 'newPassword', newPassword);

method = matlab.net.http.RequestMethod.POST;

body = matlab.net.http.MessageBody(json);

acceptField = matlab.net.http.HeaderField('accept','application/json');
contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
headers = [acceptField contentTypeField authorizationField];

req = matlab.net.http.RequestMessage(method, headers, body);

url = matlab.net.URI(ndi.cloud.api.url('password'));

response = req.send(url);
status = 1;
if (response.StatusCode == 200 || response.StatusCode == 201)
    status = 0;
else
    error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
end
end



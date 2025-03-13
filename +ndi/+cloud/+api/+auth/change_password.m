function [response] = change_password(oldPassword, newPassword)
    % CHANGE_PASSWORD - Change a user's password
    %
    % [RESPONSE] = ndi.cloud.api.auth.CHANGE_PASSWORD(OLDPASSWORD, NEWPASSWORD)
    %
    % Inputs:
    %   OLDPASSWORD - a string representing the old password
    %   NEWPASSWORD - a string representing the new password
    %
    % Outputs:
    %   RESPONSE - the response summary
    %

    auth_token = ndi.cloud.authenticate();
    json = struct('oldPassword', oldPassword, 'newPassword', newPassword);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('change_password');

    response = req.send(url);
    
    if (response.StatusCode == 200 || response.StatusCode == 201)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end

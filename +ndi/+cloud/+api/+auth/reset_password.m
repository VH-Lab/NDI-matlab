function [status, response] = reset_password(email)
    % RESET_PASSWORD - sends a password reset e-mail
    %
    % [STATUS, RESPONSE] = ndi.cloud.api.auth.reset_password(EMAIL)
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

    url = ndi.cloud.api.url('reset_password');

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200 || response.StatusCode == 201)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
